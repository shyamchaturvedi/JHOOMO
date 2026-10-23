import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { authAdmin, db } from '../shared/admin';
import { fail } from '../shared/errors';
import { generatePasscode, hashPasscode, newSalt } from '../shared/crypto';
import { mergeCustomClaims } from '../shared/claims';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';
import { writeAuditLog } from '../shared/audit';
import { notifyUser } from '../shared/notify';
import { clientIp } from '../shared/auth';
import { requestIdOf } from '../shared/callable';
import { randomBytes } from 'node:crypto';

const staffCreateSchema = z.object({
  eventId: z.string().min(1).max(64),
  name: z.string().trim().min(2).max(80),
  phone: z.string().trim().regex(/^\+91[6-9]\d{9}$/, 'Enter a valid 10-digit Indian mobile number'),
  gate: z.string().trim().min(1).max(40),
  role: z.enum(['scanner', 'gate_lead']).default('scanner'),
  validFrom: z.number().int().positive(),
  validTo: z.number().int().positive(),
});

export const createStaffPasscode = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = staffCreateSchema.parse(req.data);

  const eventSnap = await db().collection('events').doc(input.eventId).get();
  if (!eventSnap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = eventSnap.data()!;
  if (event.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');

  const gates = (event.gates ?? []) as Array<{ id: string; name: string }>;
  if (!gates.some((g) => g.id === input.gate)) {
    fail('INVALID_INPUT', 'That gate is not defined for this event.');
  }
  if (input.validTo <= input.validFrom) fail('INVALID_INPUT', 'The validity window is invalid.');

  const existingStaff = await db()
    .collection('events')
    .doc(input.eventId)
    .collection('staff')
    .get();
  if (existingStaff.size >= 20) fail('LIMIT_EXCEEDED', 'This event already has the maximum staff members.');

  const staffId = `st_${randomBytes(5).toString('hex')}`;
  const passcode = generatePasscode();
  const salt = newSalt();

  await db()
    .collection('events')
    .doc(input.eventId)
    .collection('staff')
    .doc(staffId)
    .set({
      schemaVersion: 1,
      name: input.name,
      phone: input.phone,
      gate: input.gate,
      role: input.role,
      status: 'active',
      validFrom: Timestamp.fromMillis(input.validFrom),
      validTo: Timestamp.fromMillis(input.validTo),
      scanCount: 0,
      createdBy: ctx.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

  await db()
    .collection('staffSecrets')
    .doc(`${input.eventId}_${staffId}`)
    .set({
      schemaVersion: 1,
      passcodeHash: hashPasscode(passcode, salt),
      salt,
      failedAttempts: 0,
      createdAt: FieldValue.serverTimestamp(),
    });

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'staff.created',
    targetType: 'event_staff',
    targetId: `${input.eventId}_${staffId}`,
    after: { gate: input.gate, role: input.role },
    requestId: requestIdOf(req),
  });

  return { ok: true, staffId, passcode, gate: input.gate, role: input.role };
});

export const revokeStaff = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ eventId: z.string().min(1).max(64), staffId: z.string().min(1).max(64) }).parse(req.data);

  const staffRef = db().collection('events').doc(input.eventId).collection('staff').doc(input.staffId);
  const snap = await staffRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Staff member not found.');
  if (snap.data()?.createdBy !== ctx.uid && snap.data()?.organizerId !== ctx.uid) {
    fail('FORBIDDEN', 'This staff member belongs to another organiser.');
  }

  await staffRef.set(
    { status: 'revoked', revokedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  const sessions = await db()
    .collection('gateSessions')
    .where('eventId', '==', input.eventId)
    .where('staffId', '==', input.staffId)
    .where('status', '==', 'active')
    .get();
  for (const session of sessions.docs) {
    await session.ref.set({ status: 'revoked', endedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'staff.revoked',
    targetType: 'event_staff',
    targetId: `${input.eventId}_${input.staffId}`,
    requestId: requestIdOf(req),
  });

  return { ok: true, sessionsRevoked: sessions.size };
});

export const listStaff = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ eventId: z.string().min(1).max(64) }).parse(req.data);

  const eventSnap = await db().collection('events').doc(input.eventId).get();
  if (!eventSnap.exists) fail('NOT_FOUND', 'Event not found.');
  if (eventSnap.data()?.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');

  const snap = await db().collection('events').doc(input.eventId).collection('staff').get();
  return {
    staff: snap.docs.map((d) => {
      const data = d.data();
      return {
        staffId: d.id,
        name: data.name,
        phone: data.phone,
        gate: data.gate,
        role: data.role,
        status: data.status,
        validFrom: data.validFrom,
        validTo: data.validTo,
        scanCount: data.scanCount ?? 0,
        lastLoginAt: data.lastLoginAt ?? null,
      };
    }),
  };
});

const staffLoginSchema = z.object({
  eventId: z.string().min(1).max(64),
  staffId: z.string().min(1).max(64),
  passcode: z.string().regex(/^\d{6}$/, 'Passcode must be 6 digits'),
  deviceId: z.string().trim().min(8).max(120),
  appVersion: z.string().trim().max(40).optional(),
});

export const staffLogin = miloOnCall(
  { enforceAppCheck: true },
  async (req) => {
    const input = staffLoginSchema.parse(req.data);

    const ip = clientIp(req);
    await consumeRateLimit(rateLimitKey('staff_login_ip', ip), 30, 60 * 1000);
    await consumeRateLimit(rateLimitKey('staff_login', input.eventId, input.staffId), 10, 60 * 1000);

    const staffRef = db().collection('events').doc(input.eventId).collection('staff').doc(input.staffId);
    const staffSnap = await staffRef.get();
    if (!staffSnap.exists) fail('INVALID_STAFF_CREDENTIALS', 'Invalid passcode.');
    const staff = staffSnap.data()!;

    if (staff.status !== 'active') fail('INVALID_STAFF_CREDENTIALS', 'This staff pass has been revoked.');

    const now = Date.now();
    const validFrom = (staff.validFrom as Timestamp | undefined)?.toMillis() ?? 0;
    const validTo = (staff.validTo as Timestamp | undefined)?.toMillis() ?? Number.MAX_SAFE_INTEGER;
    if (now < validFrom || now > validTo) {
      fail('INVALID_STAFF_CREDENTIALS', 'This staff pass is not valid for this event window.');
    }

    const secretRef = db().collection('staffSecrets').doc(`${input.eventId}_${input.staffId}`);
    const secretSnap = await secretRef.get();
    const secret = secretSnap.data();
    if (!secret) fail('INVALID_STAFF_CREDENTIALS', 'Invalid passcode.');

    const lockedUntil = (secret.lockedUntil as Timestamp | undefined)?.toMillis() ?? 0;
    if (lockedUntil > now) {
      fail('RATE_LIMITED', 'Too many failed attempts. Try again in a few minutes.', {
        retryAfterSeconds: Math.ceil((lockedUntil - now) / 1000),
      });
    }

    const expected = hashPasscode(input.passcode, String(secret.salt));
    if (expected !== secret.passcodeHash) {
      const attempts = Number(secret.failedAttempts ?? 0) + 1;
      const patch: Record<string, unknown> = { failedAttempts: attempts };
      if (attempts >= 5) patch.lockedUntil = Timestamp.fromMillis(now + 5 * 60 * 1000);
      await secretRef.set(patch, { merge: true });
      fail('INVALID_STAFF_CREDENTIALS', 'Invalid passcode.');
    }

    await secretRef.set({ failedAttempts: 0, lockedUntil: null, lastUsedAt: FieldValue.serverTimestamp() }, { merge: true });

    const staffUid = `staff_${input.eventId}_${input.staffId}`;
    try {
      await authAdmin().createUser({ uid: staffUid, displayName: `Gate staff ${staff.name}` });
    } catch (err) {
      const code = err as { code?: string };
      if (!String(code?.code ?? '').includes('already-exists')) throw err;
    }

    const claims = {
      role: 'gate_staff' as const,
      eventId: input.eventId,
      gate: String(staff.gate),
      staffId: input.staffId,
    };
    await mergeCustomClaims(staffUid, claims);

    const sessionRef = db().collection('gateSessions').doc();
    const sessionId = sessionRef.id;
    await sessionRef.set({
      schemaVersion: 1,
      staffUid,
      staffId: input.staffId,
      eventId: input.eventId,
      gate: String(staff.gate),
      deviceId: input.deviceId,
      status: 'active',
      startedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      appVersion: input.appVersion ?? null,
    });

    await staffRef.set({ lastLoginAt: FieldValue.serverTimestamp() }, { merge: true });

    const customToken = await authAdmin().createCustomToken(staffUid, claims);

    return {
      ok: true,
      customToken,
      sessionId,
      staffUid,
      gate: String(staff.gate),
      role: String(staff.role),
      displayName: String(staff.name),
    };
  },
);

export const endGateSession = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ sessionId: z.string().min(1).max(64) }).parse(req.data);

  const sessionRef = db().collection('gateSessions').doc(input.sessionId);
  const snap = await sessionRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Session not found.');
  if (snap.data()?.staffUid !== ctx.uid) fail('FORBIDDEN', 'This session belongs to another device.');

  await sessionRef.set({ status: 'ended', endedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true };
});

export const notifyStaffRevoked = async (staffUid: string): Promise<void> => {
  await notifyUser(staffUid, 'staff_revoked', 'Gate access revoked', 'Your gate session has been ended.', {
    deepLink: '/staff/login',
    channel: 'bookings',
  }).catch(() => undefined);
};
