import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireStaff } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { verifyQrToken } from '../shared/crypto';
import { parseQrPayload } from '../shared/gatekeys';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';
import { sha256Hex } from '../shared/crypto';
import { istDateKey, istDayStartUtc } from '../shared/time';
import { logger } from 'firebase-functions';

const GATE_STATS_SHARDS = 10;

interface GateSession {
  id: string;
  staffUid: string;
  staffId: string;
  eventId: string;
  gate: string;
  deviceId: string;
  status: string;
}

async function requireActiveSession(
  staff: ReturnType<typeof requireStaff>,
  sessionId: string,
  deviceId: string,
): Promise<GateSession> {
  if (!sessionId) fail('FORBIDDEN', 'Start a gate session before scanning.');
  const snap = await db().collection('gateSessions').doc(sessionId).get();
  if (!snap.exists) fail('FORBIDDEN', 'Gate session not found.');
  const session = snap.data()!;
  if (session.staffUid !== staff.uid) fail('FORBIDDEN', 'This gate session belongs to another device.');
  if (session.status !== 'active') fail('FORBIDDEN', 'This gate session has ended.');
  if (session.deviceId !== deviceId) fail('FORBIDDEN', 'This gate session is bound to another device.');
  if (session.eventId !== staff.eventId) fail('FORBIDDEN', 'This gate session belongs to another event.');
  return {
    id: sessionId,
    staffUid: String(session.staffUid),
    staffId: String(session.staffId),
    eventId: String(session.eventId),
    gate: String(session.gate),
    deviceId: String(session.deviceId),
    status: String(session.status),
  };
}

function dayIndexFor(eventStartAt: Timestamp, at: Date): number {
  const start = istDayStartUtc(eventStartAt.toDate()).getTime();
  const current = istDayStartUtc(at).getTime();
  return Math.floor((current - start) / 86_400_000);
}

const checkInSchema = z.object({
  payload: z.string().trim().min(10).max(600),
  deviceId: z.string().trim().min(8).max(120),
  sessionId: z.string().trim().min(1).max(64),
});

export const gateCheckIn = miloOnCall({}, async (req) => {
  const staff = requireStaff(req);
  const input = checkInSchema.parse(req.data);

  const session = await requireActiveSession(staff, input.sessionId, input.deviceId);

  const parsed = parseQrPayload(input.payload);
  if (!parsed || parsed.kind === 'unknown') fail('TICKET_INVALID', 'That QR code could not be read.');

  const ticketId = parsed.ticketId;
  const ts = parsed.ts ?? 0;
  const nowSec = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSec - ts) > 60) {
    fail('QR_EXPIRED', 'This QR code has expired. Ask the guest to refresh their ticket.');
  }

  const ticketSnap = await db().collection('tickets').doc(ticketId).get();
  if (!ticketSnap.exists) fail('TICKET_INVALID', 'This ticket does not exist.');
  const ticket = ticketSnap.data()!;

  if (ticket.eventId !== staff.eventId) fail('TICKET_WRONG_EVENT', 'This ticket is for another event.');

  const secretSnap = await db().collection('ticketSecrets').doc(ticketId).get();
  const secret = secretSnap.data()?.secret as string | undefined;
  if (!secret) fail('TICKET_INVALID', 'This ticket could not be verified.');
  if (!verifyQrToken(secret, ticketId, String(ticket.userId), ts, parsed.signature)) {
    fail('TICKET_INVALID', 'Signature verification failed.');
  }

  return runCheckIn({
    eventId: staff.eventId,
    ticketId,
    gate: session.gate,
    staffId: session.staffId,
    sessionId: session.id,
    mode: 'online',
  });
});

interface CheckInInput {
  eventId: string;
  ticketId: string;
  gate: string;
  staffId: string;
  sessionId: string;
  mode: 'online' | 'offline';
  offlineAt?: Timestamp;
}

async function runCheckIn(input: CheckInInput): Promise<Record<string, unknown>> {
  const ticketRef = db().collection('tickets').doc(input.ticketId);
  const checkinRef = db().collection('events').doc(input.eventId).collection('checkins').doc(input.ticketId);

  const tierId = (await ticketRef.get()).data()?.tierId as string | undefined;

  try {
    const result = await db().runTransaction(async (tx) => {
      const ticketSnap = await tx.get(ticketRef);
      if (!ticketSnap.exists) fail('TICKET_INVALID', 'This ticket does not exist.');
      const ticket = ticketSnap.data()!;

      const status = String(ticket.status);
      if (status === 'void' || status === 'refunded') {
        fail('TICKET_REFUNDED_OR_VOID', 'This ticket was refunded or voided.');
      }

      if (tierId) {
        const tierSnap = await tx.get(
          db().collection('events').doc(input.eventId).collection('ticketTiers').doc(tierId),
        );
        const validDays = tierSnap.data()?.validDays as number[] | null | undefined;
        if (validDays && validDays.length > 0) {
          const eventStartAt = ticket.eventStartAt as Timestamp | undefined;
          if (!eventStartAt) fail('TICKET_INVALID', 'This ticket could not be verified.');
          const index = dayIndexFor(eventStartAt, new Date());
          if (!validDays.includes(index)) {
            fail('NOT_VALID_TODAY', 'This ticket is not valid for today.');
          }
        }
      }

      await tx.create(checkinRef, {
        schemaVersion: 1,
        ticketId: input.ticketId,
        bookingId: ticket.bookingId,
        tierId,
        gate: input.gate,
        staffId: input.staffId,
        sessionId: input.sessionId,
        at: FieldValue.serverTimestamp(),
        mode: input.mode,
        offlineAt: input.offlineAt ?? null,
        attendeeFirstName: firstNameOf(ticket.userId),
        seq: ticket.seq ?? 0,
      });

      tx.update(ticketRef, {
        status: 'checked_in',
        checkedInAt: FieldValue.serverTimestamp(),
        checkedInGate: input.gate,
      });

      const shard = Math.floor(Math.random() * GATE_STATS_SHARDS);
      const statsRef = db().collection('gateStats').doc(input.eventId).collection('shards').doc(String(shard));
      const statsSnap = await tx.get(statsRef);
      const byGate = (statsSnap.data()?.byGate ?? {}) as Record<string, number>;
      tx.set(
        statsRef,
        {
          total: Number(statsSnap.data()?.total ?? 0) + 1,
          byGate: { ...byGate, [input.gate]: Number(byGate[input.gate] ?? 0) + 1 },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const tierName = tierId
        ? (
            await db().collection('events').doc(input.eventId).collection('ticketTiers').doc(tierId).get()
          ).data()?.name ?? ''
        : String(ticket.tierName ?? '');

      return {
        result: 'APPROVED',
        firstName: firstNameOf(ticket.userId),
        tierName,
        admits: Number(ticket.admits ?? 1),
        seq: Number(ticket.seq ?? 0),
        gate: input.gate,
        at: new Date().toISOString(),
        mode: input.mode,
      };
    });

    await db()
      .collection('events')
      .doc(input.eventId)
      .collection('staff')
      .doc(input.staffId)
      .set({ scanCount: FieldValue.increment(1) }, { merge: true });

    return result;
  } catch (err) {
    if (isAlreadyExists(err)) {
      const existing = await checkinRef.get();
      const data = existing.data() ?? {};
      return {
        result: 'ALREADY_CHECKED_IN',
        firstName: data.attendeeFirstName ?? '',
        at: (data.at as Timestamp | undefined)?.toDate().toISOString() ?? null,
        gate: data.gate ?? '',
        scannedBy: data.staffId ?? '',
      };
    }
    throw err;
  }
}

function isAlreadyExists(err: unknown): boolean {
  const code = (err as { code?: string | number })?.code;
  if (code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS') return true;
  const message = err instanceof Error ? err.message : String(err);
  return message.includes('ALREADY_EXISTS') || message.includes('already exists');
}

let nameCache = new Map<string, { name: string; at: number }>();

async function firstNameOf(userId: string): Promise<string> {
  const cached = nameCache.get(userId);
  if (cached && Date.now() - cached.at < 60_000) return cached.name;
  const snap = await db().collection('users').doc(userId).get();
  const displayName = String(snap.data()?.displayName ?? '').trim();
  const name = displayName.split(/\s+/)[0] || 'Guest';
  nameCache.set(userId, { name, at: Date.now() });
  return name;
}

const manualLookupSchema = z.object({
  bookingRef: z.string().trim().toUpperCase().regex(/^MILO-\d{6}$/, 'Enter a booking reference like MILO-123456'),
  phoneLast4: z.string().regex(/^\d{4}$/, 'Enter the last 4 digits of the guest phone number'),
  sessionId: z.string().trim().min(1).max(64),
  deviceId: z.string().trim().min(8).max(120),
});

export const manualLookup = miloOnCall({}, async (req) => {
  const staff = requireStaff(req);
  const input = manualLookupSchema.parse(req.data);

  await consumeRateLimit(rateLimitKey('manual_lookup', staff.uid), 5, 60 * 1000);
  await requireActiveSession(staff, input.sessionId, input.deviceId);

  const refSnap = await db().collection('bookingRefs').doc(input.bookingRef).get();
  const bookingId = refSnap.data()?.bookingId as string | undefined;
  if (!bookingId) fail('NOT_FOUND', 'No booking matches that reference.');

  const bookingSnap = await db().collection('bookings').doc(bookingId).get();
  if (!bookingSnap.exists) fail('NOT_FOUND', 'No booking matches that reference.');
  const booking = bookingSnap.data()!;
  if (booking.eventId !== staff.eventId) fail('TICKET_WRONG_EVENT', 'This ticket is for another event.');

  const userSnap = await db().collection('users').doc(String(booking.userId)).get();
  const user = userSnap.data() ?? {};
  const phone = String(user.phone ?? '');
  if (!phone.endsWith(input.phoneLast4)) fail('NOT_FOUND', 'The phone number does not match this booking.');

  const tickets = await db().collection('tickets').where('bookingId', '==', bookingId).get();
  const ticket = tickets.docs.find((t) => t.data().status === 'valid') ?? tickets.docs[0];
  if (!ticket) fail('NOT_FOUND', 'No ticket found for this booking.');

  const tierId = ticket.data().tierId as string | undefined;
  const tierName = tierId
    ? (
        await db().collection('events').doc(staff.eventId).collection('ticketTiers').doc(tierId).get()
      ).data()?.name ?? ''
    : String(ticket.data().tierName ?? '');

  return {
    result: 'FOUND',
    ticketId: ticket.id,
    firstName: firstNameOf(String(booking.userId)),
    tierName,
    admits: Number(ticket.data().admits ?? 1),
    seq: Number(ticket.data().seq ?? 0),
    status: String(ticket.data().status),
  };
});

export const admitManualLookup = miloOnCall({}, async (req) => {
  const staff = requireStaff(req);
  const input = z
    .object({
      ticketId: z.string().min(1).max(64),
      sessionId: z.string().trim().min(1).max(64),
      deviceId: z.string().trim().min(8).max(120),
    })
    .parse(req.data);

  const session = await requireActiveSession(staff, input.sessionId, input.deviceId);
  const ticketSnap = await db().collection('tickets').doc(input.ticketId).get();
  if (!ticketSnap.exists) fail('TICKET_INVALID', 'This ticket does not exist.');
  if (ticketSnap.data()?.eventId !== staff.eventId) fail('TICKET_WRONG_EVENT', 'This ticket is for another event.');

  return runCheckIn({
    eventId: staff.eventId,
    ticketId: input.ticketId,
    gate: session.gate,
    staffId: session.staffId,
    sessionId: session.id,
    mode: 'online',
  });
});

export const getGateManifest = miloOnCall({}, async (req) => {
  const staff = requireStaff(req);
  const input = z.object({ eventId: z.string().min(1).max(64).optional() }).parse(req.data ?? {});
  const eventId = input.eventId ?? staff.eventId;
  if (eventId !== staff.eventId) fail('FORBIDDEN', 'You can only download the manifest for your event.');

  const [tickets, tierSnaps, secretSnap] = await Promise.all([
    db().collection('tickets').where('eventId', '==', eventId).get(),
    db().collection('events').doc(eventId).collection('ticketTiers').get(),
    db().collection('eventSecrets').doc(eventId).get(),
  ]);

  const publicKey = secretSnap.data()?.gatePublicKey as string | undefined;
  if (!publicKey) fail('INTERNAL', 'Offline signing is not provisioned for this event.');

  const tierMap = new Map<string, { name: string; validDays: number[] | null }>();
  for (const tier of tierSnaps.docs) {
    tierMap.set(tier.id, {
      name: String(tier.data().name ?? ''),
      validDays: (tier.data().validDays as number[] | null) ?? null,
    });
  }

  const entries = tickets.docs.map((t) => {
    const data = t.data();
    const tier = tierMap.get(String(data.tierId ?? ''));
    return {
      ticketIdHash: sha256Hex(t.id),
      tierId: String(data.tierId ?? ''),
      tierName: tier?.name ?? String(data.tierName ?? ''),
      admits: Number(data.admits ?? 1),
      seq: Number(data.seq ?? 0),
      holderFirstName: String(data.holderName ?? '').split(/\s+/)[0] ?? '',
      validDays: tier?.validDays ?? null,
      status: String(data.status),
    };
  });

  return {
    eventId,
    eventPublicKey: publicKey,
    algorithm: 'ed25519',
    generatedAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString(),
    count: entries.length,
    entries,
  };
});

const syncSchema = z.object({
  sessionId: z.string().trim().min(1).max(64),
  deviceId: z.string().trim().min(8).max(120),
  checkins: z
    .array(
      z.object({
        ticketId: z.string().min(1).max(64),
        at: z.number().int().positive(),
        gate: z.string().trim().min(1).max(40),
        mode: z.enum(['online', 'offline']).default('offline'),
      }),
    )
    .max(500),
});

export const syncOfflineCheckins = miloOnCall({}, async (req) => {
  const staff = requireStaff(req);
  const input = syncSchema.parse(req.data);

  const session = await requireActiveSession(staff, input.sessionId, input.deviceId);

  const ordered = [...input.checkins].sort((a, b) => a.at - b.at);
  const results: Array<Record<string, unknown>> = [];

  for (const entry of ordered) {
    try {
      const outcome = await runCheckIn({
        eventId: staff.eventId,
        ticketId: entry.ticketId,
        gate: entry.gate,
        staffId: session.staffId,
        sessionId: session.id,
        mode: 'offline',
        offlineAt: Timestamp.fromMillis(entry.at),
      });
      results.push({ ticketId: entry.ticketId, ...outcome });
    } catch (err) {
      const code = (err as { code?: string })?.code;
      results.push({
        ticketId: entry.ticketId,
        result: 'FAILED',
        error: code ?? (err instanceof Error ? err.message : 'unknown'),
      });
    }
  }

  const conflicts = results.filter((r) => r.result === 'ALREADY_CHECKED_IN');
  if (conflicts.length > 0) {
    logger.warn('gate.sync.duplicate_conflicts', {
      eventId: staff.eventId,
      gate: session.gate,
      count: conflicts.length,
    });
  }

  return {
    synced: results.length,
    approved: results.filter((r) => r.result === 'APPROVED').length,
    duplicates: conflicts.length,
    results,
  };
});

export { istDateKey };
