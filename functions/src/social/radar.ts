import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { ConsentRecord, hasConsent, mergeConsents } from '../shared/consent';
import { notifyUser } from '../shared/notify';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';
import { ageBand } from '../shared/age';
import { getLimitsConfig } from '../shared/config';
import { addDays } from '../shared/time';
import { maskDisplayName } from '../shared/mask';

const RADAR_TTL_DAYS = 7;

interface RadarProfile {
  displayName: string;
  avatarUrl?: string | null;
  dob?: Timestamp | null;
  interests?: string[];
  bio?: string | null;
  faceVerified?: boolean;
  privacy?: { incognito?: boolean; ghost?: boolean; radarVisible?: boolean; mutualInterestOnly?: boolean };
}

async function loadProfile(uid: string): Promise<RadarProfile> {
  const snap = await db().collection('users').doc(uid).get();
  return (snap.data() ?? {}) as RadarProfile;
}

export const setRadarOptIn = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      eventId: z.string().min(1).max(64),
      optedIn: z.boolean(),
      consentGranted: z.boolean(),
    })
    .parse(req.data);

  const attendee = await db()
    .collection('eventAttendees')
    .doc(`${input.eventId}_${ctx.uid}`)
    .get();
  if (!attendee.exists) fail('FORBIDDEN', 'You need a ticket to join the radar for this event.');

  const event = await db().collection('events').doc(input.eventId).get();
  if (!event.exists) fail('NOT_FOUND', 'Event not found.');
  if (event.data()?.radarEnabled !== true) fail('FORBIDDEN', 'Radar is disabled for this event.');

  const userRef = db().collection('users').doc(ctx.uid);
  const user = await userRef.get();
  const userData = user.data() ?? {};

  const consents = mergeConsents(
    userData.consents as ConsentRecord[] | undefined,
    [{ type: 'radar', granted: input.consentGranted }],
    Timestamp.now(),
  );
  await userRef.set(
    { consents, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  const memberRef = db().collection('events').doc(input.eventId).collection('radarMembers').doc(ctx.uid);
  const existingMember = await memberRef.get();

  if (!input.optedIn || !input.consentGranted) {
    await memberRef.delete().catch(() => undefined);
    await db()
      .collection('eventAttendees')
      .doc(`${input.eventId}_${ctx.uid}`)
      .set({ radarOptIn: false }, { merge: true });
    if (existingMember.exists) {
      await db()
        .collection('eventStats')
        .doc(input.eventId)
        .set({ radarCount: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    return { ok: true, optedIn: false };
  }

  const profile = await loadProfile(ctx.uid);
  const endAt = (event.data()?.schedule?.endAt as Timestamp | undefined)?.toDate() ?? new Date();
  const expiresAt = Timestamp.fromDate(addDays(endAt, RADAR_TTL_DAYS));

  await memberRef.set({
    schemaVersion: 1,
    uid: ctx.uid,
    displayName: maskDisplayName(profile.displayName),
    avatarUrl: profile.avatarUrl ?? null,
    ageBand: profile.dob ? ageBand(profile.dob.toDate()) : '25-34',
    interests: (profile.interests ?? []).slice(0, 12),
    bio: profile.bio ?? null,
    faceVerified: profile.faceVerified === true,
    optedInAt: FieldValue.serverTimestamp(),
    lastActiveAt: FieldValue.serverTimestamp(),
    expiresAt,
  });

  await db()
    .collection('eventAttendees')
    .doc(`${input.eventId}_${ctx.uid}`)
    .set({ radarOptIn: true }, { merge: true });

  if (!existingMember.exists) {
    await db()
      .collection('eventStats')
      .doc(input.eventId)
      .set({ radarCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  return { ok: true, optedIn: true, expiresAt: expiresAt.toDate().toISOString() };
});

export const listRadarMembers = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      eventId: z.string().min(1).max(64),
      limit: z.number().int().min(1).max(50).default(20),
      cursor: z.string().max(512).optional(),
    })
    .parse(req.data);

  const attendee = await db().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
  if (!attendee.exists) fail('FORBIDDEN', 'You need a ticket to view the radar for this event.');

  const me = await loadProfile(ctx.uid);
  const blocks = await db().collection('users').doc(ctx.uid).collection('blocks').get();
  const blocked = new Set(blocks.docs.map((d) => d.id));

  let query = db()
    .collection('events')
    .doc(input.eventId)
    .collection('radarMembers')
    .orderBy('lastActiveAt', 'desc')
    .limit(input.limit + 1);
  if (input.cursor) {
    const cursorSnap = await memberRef(input.eventId, input.cursor).get();
    if (cursorSnap.exists) query = query.startAfter(cursorSnap);
  }

  const snap = await query.get();
  const docs = snap.docs.slice(0, input.limit);

  const members = docs
    .map((d) => {
      const data = d.data();
      return {
        uid: d.id,
        displayName: maskDisplayName(data.displayName),
        avatarUrl: data.avatarUrl ?? null,
        ageBand: data.ageBand,
        interests: data.interests ?? [],
        bio: data.bio ?? null,
        faceVerified: data.faceVerified === true,
        lastActiveAt: data.lastActiveAt ?? null,
      };
    })
    .filter((m) => !blocked.has(m.uid) && m.uid !== ctx.uid);

  return {
    members,
    nextCursor: snap.docs.length > input.limit ? docs[docs.length - 1]!.id : null,
    incognito: me.privacy?.incognito === true,
  };
});

function memberRef(eventId: string, uid: string) {
  return db().collection('events').doc(eventId).collection('radarMembers').doc(uid);
}

const connectionRequestSchema = z.object({
  toUid: z.string().min(1).max(64),
  eventId: z.string().min(1).max(64),
  message: z.string().trim().max(300).optional(),
});

export const sendConnectionRequest = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = connectionRequestSchema.parse(req.data);

  const limits = await getLimitsConfig();
  await consumeRateLimit(rateLimitKey('connection_request', ctx.uid), limits.hellosPerDay, 24 * 60 * 60 * 1000);

  if (input.toUid === ctx.uid) fail('INVALID_INPUT', 'You cannot send a request to yourself.');

  const blocked = await db().collection('users').doc(ctx.uid).collection('blocks').doc(input.toUid).get();
  if (blocked.exists) fail('FORBIDDEN', 'You cannot contact this person.');
  const blockedBy = await db().collection('users').doc(input.toUid).collection('blocks').doc(ctx.uid).get();
  if (blockedBy.exists) fail('FORBIDDEN', 'You cannot contact this person.');

  const targetAttendee = await db()
    .collection('eventAttendees')
    .doc(`${input.eventId}_${input.toUid}`)
    .get();
  if (!targetAttendee.exists) fail('FORBIDDEN', 'This person is not attending this event.');

  const targetProfile = await loadProfile(input.toUid);
  if (targetProfile.privacy?.mutualInterestOnly === true) {
    fail('FORBIDDEN', 'This person only accepts requests from mutual matches.');
  }

  const myProfile = await loadProfile(ctx.uid);
  const docId = `${ctx.uid}_${input.toUid}`;
  const ref = db().collection('connections').doc(docId);

  const existing = await ref.get();
  if (existing.exists) {
    const status = String(existing.data()?.status ?? '');
    if (status === 'pending') return { ok: true, status: 'pending', connectionId: docId };
    if (status === 'accepted') return { ok: true, status: 'accepted', chatId: existing.data()?.chatId };
  }

  const reverseId = `${input.toUid}_${ctx.uid}`;
  const reverse = await db().collection('connections').doc(reverseId).get();
  if (reverse.exists && reverse.data()?.status === 'pending') {
    await reverse.ref.set(
      { status: 'accepted', respondedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    const chatId = await ensureDmChat(ctx.uid, input.toUid, input.eventId, myProfile, targetProfile);
    await reverse.ref.set({ chatId }, { merge: true });
    await ref.set(
      {
        fromUid: ctx.uid,
        toUid: input.toUid,
        eventId: input.eventId,
        fromProfile: { name: myProfile.displayName ?? 'Milo User', avatarUrl: myProfile.avatarUrl ?? null },
        toProfile: { name: targetProfile.displayName ?? 'Milo User', avatarUrl: targetProfile.avatarUrl ?? null },
        status: 'accepted',
        chatId,
        respondedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromDate(addDays(new Date(), RADAR_TTL_DAYS)),
      },
      { merge: true },
    );
    await notifyUser(
      input.toUid,
      'connection_accepted',
      'Connection accepted',
      'Someone you connected with is now available to chat.',
      { deepLink: `/chat/${chatId}`, channel: 'social' },
    ).catch(() => undefined);
    return { ok: true, status: 'accepted', chatId };
  }

  await ref.set(
    {
      schemaVersion: 1,
      fromUid: ctx.uid,
      toUid: input.toUid,
      eventId: input.eventId,
      message: input.message ?? null,
      fromProfile: { name: maskDisplayName(myProfile.displayName), avatarUrl: myProfile.avatarUrl ?? null },
      toProfile: { name: maskDisplayName(targetProfile.displayName), avatarUrl: targetProfile.avatarUrl ?? null },
      status: 'pending',
      respondedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(addDays(new Date(), RADAR_TTL_DAYS)),
    },
  );

  await notifyUser(
    input.toUid,
    'connection_request',
    'New connection request',
    'Someone at your event wants to connect.',
    { deepLink: '/requests', channel: 'social' },
  ).catch(() => undefined);

  return { ok: true, status: 'pending', connectionId: docId };
});

export const respondConnection = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      connectionId: z.string().min(1).max(140),
      accept: z.boolean(),
    })
    .parse(req.data);

  const ref = db().collection('connections').doc(input.connectionId);
  const snap = await ref.get();
  if (!snap.exists) fail('NOT_FOUND', 'Request not found.');
  const connection = snap.data()!;
  if (connection.toUid !== ctx.uid) fail('FORBIDDEN', 'This request belongs to someone else.');
  if (connection.status !== 'pending') fail('CONFLICT', 'This request has already been handled.');

  if (!input.accept) {
    await ref.set(
      { status: 'declined', respondedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    await notifyUser(
      String(connection.fromUid),
      'connection_declined',
      'Request declined',
      'Your connection request was declined.',
      { deepLink: '/requests', channel: 'social' },
    ).catch(() => undefined);
    return { ok: true, status: 'declined' };
  }

  const myProfile = await loadProfile(ctx.uid);
  const theirProfile = await loadProfile(String(connection.fromUid));
  const chatId = await ensureDmChat(ctx.uid, String(connection.fromUid), String(connection.eventId), myProfile, theirProfile);

  await ref.set(
    {
      status: 'accepted',
      chatId,
      respondedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  const reverseRef = db().collection('connections').doc(`${connection.fromUid}_${ctx.uid}`);
  await reverseRef.set(
    {
      schemaVersion: 1,
      fromUid: connection.fromUid,
      toUid: ctx.uid,
      eventId: connection.eventId,
      fromProfile: { name: theirProfile.displayName ?? 'Milo User', avatarUrl: theirProfile.avatarUrl ?? null },
      toProfile: { name: myProfile.displayName ?? 'Milo User', avatarUrl: myProfile.avatarUrl ?? null },
      status: 'accepted',
      chatId,
      respondedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(addDays(new Date(), RADAR_TTL_DAYS)),
    },
    { merge: true },
  );

  await notifyUser(
    String(connection.fromUid),
    'connection_accepted',
    'Connection accepted',
    'Your connection request was accepted. Start chatting.',
    { deepLink: `/chat/${chatId}`, channel: 'social' },
  ).catch(() => undefined);

  return { ok: true, status: 'accepted', chatId };
});

export async function ensureDmChat(
  uidA: string,
  uidB: string,
  eventId: string,
  profileA: RadarProfile,
  profileB: RadarProfile,
): Promise<string> {
  const chatId = [uidA, uidB].sort().join('_');
  const ref = db().collection('chats').doc(chatId);
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      schemaVersion: 1,
      type: 'dm',
      participants: [uidA, uidB].sort(),
      eventId,
      participantsInfo: {
        [uidA]: { name: profileA.displayName ?? 'Milo User', avatarUrl: profileA.avatarUrl ?? null },
        [uidB]: { name: profileB.displayName ?? 'Milo User', avatarUrl: profileB.avatarUrl ?? null },
      },
      lastMessageAt: FieldValue.serverTimestamp(),
      lastReadAt: {},
      muted: {},
      status: 'active',
      createdAt: FieldValue.serverTimestamp(),
    });
    await Promise.all(
      [uidA, uidB].map((uid) =>
        ref.collection('members').doc(uid).set({
          uid,
          name: uid === uidA ? profileA.displayName ?? 'Milo User' : profileB.displayName ?? 'Milo User',
          avatarUrl: (uid === uidA ? profileA.avatarUrl : profileB.avatarUrl) ?? null,
          role: 'member',
          joinedAt: FieldValue.serverTimestamp(),
        }),
      ),
    );
  }
  return chatId;
}

export const listConnections = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({ status: z.enum(['pending', 'accepted', 'declined', 'expired']).optional() })
    .parse(req.data ?? {});

  const queries = input.status
    ? [
        db().collection('connections').where('toUid', '==', ctx.uid).where('status', '==', input.status),
        db().collection('connections').where('fromUid', '==', ctx.uid).where('status', '==', input.status),
      ]
    : [
        db().collection('connections').where('toUid', '==', ctx.uid),
        db().collection('connections').where('fromUid', '==', ctx.uid),
      ];

  const results = await Promise.all(queries.map((q) => q.limit(50).get()));
  const merged = new Map<string, Record<string, unknown>>();
  for (const snap of results) {
    for (const doc of snap.docs) merged.set(doc.id, { id: doc.id, ...doc.data() });
  }

  return {
    connections: [...merged.values()].sort(
      (a, b) => Number(b.respondedAt ?? 0) - Number(a.respondedAt ?? 0),
    ),
  };
});

export const blockUser = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ uid: z.string().min(1).max(64), reason: z.string().trim().max(200).optional() }).parse(req.data);

  await db()
    .collection('users')
    .doc(ctx.uid)
    .collection('blocks')
    .doc(input.uid)
    .set(
      { uid: input.uid, reason: input.reason ?? null, createdAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

  return { ok: true };
});

export const submitReport = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      targetType: z.enum(['user', 'message', 'event', 'chat', 'beacon']),
      targetId: z.string().min(1).max(128),
      eventId: z.string().min(1).max(64).optional(),
      reason: z.string().trim().min(3).max(200),
      note: z.string().trim().max(1000).optional(),
      evidence: z
        .array(
          z.object({
            senderId: z.string().min(1).max(64),
            text: z.string().max(1000),
            at: z.number().int().positive(),
          }),
        )
        .max(10)
        .optional(),
    })
    .parse(req.data);

  const ref = db().collection('reports').doc();
  await ref.set({
    schemaVersion: 1,
    reporterId: ctx.uid,
    targetType: input.targetType,
    targetId: input.targetId,
    eventId: input.eventId ?? null,
    reason: input.reason,
    note: input.note ?? null,
    evidence: (input.evidence ?? []).map((e) => ({ ...e, at: Timestamp.fromMillis(e.at) })),
    status: 'open',
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, reportId: ref.id };
});

export { hasConsent };
