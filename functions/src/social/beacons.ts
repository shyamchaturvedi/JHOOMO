import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { getLimitsConfig } from '../shared/config';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';
import { notifyUser } from '../shared/notify';
import { maskDisplayName } from '../shared/mask';
import { ensureDmChat } from './radar';

const VIBE_TAGS = ['music', 'food', 'art', 'sports', 'nightlife', 'startup', 'travel', 'wellness'];

export const createBeacon = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      eventId: z.string().min(1).max(64),
      title: z.string().trim().min(3).max(60),
      spot: z.string().trim().min(2).max(120),
      meetAt: z.number().int().positive(),
      maxPeople: z.number().int().min(2).max(20),
      vibeTags: z.array(z.string().trim().min(1).max(20)).max(5).default([]),
      joinMode: z.enum(['open', 'request']).default('open'),
    })
    .parse(req.data);

  const attendee = await db().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
  if (!attendee.exists) fail('FORBIDDEN', 'You need a ticket to create a beacon for this event.');
  if (attendee.data()?.radarOptIn !== true) {
    fail('FORBIDDEN', 'Turn on Radar for this event to create a beacon.');
  }

  const eventSnap = await db().collection('events').doc(input.eventId).get();
  if (!eventSnap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = eventSnap.data()!;
  const endAt = (event.schedule?.endAt as Timestamp | undefined)?.toDate();
  const startAt = (event.schedule?.startAt as Timestamp | undefined)?.toDate();
  if (endAt && new Date(input.meetAt).getTime() > endAt.getTime()) {
    fail('INVALID_INPUT', 'Meet-up time must be before the event ends.');
  }
  if (startAt && new Date(input.meetAt).getTime() < startAt.getTime() - 6 * 60 * 60 * 1000) {
    fail('INVALID_INPUT', 'Meet-up time must be within 6 hours of the event start.');
  }

  const limits = await getLimitsConfig();
  const active = await db()
    .collection('beacons')
    .where('creatorId', '==', ctx.uid)
    .where('status', '==', 'active')
    .get();
  if (active.size >= limits.beaconsPerUser) {
    fail('LIMIT_EXCEEDED', `You can have up to ${limits.beaconsPerUser} active beacons at a time.`);
  }

  const me = await db().collection('users').doc(ctx.uid).get();
  const meData = me.data() ?? {};

  const beaconRef = db().collection('beacons').doc();
  const chatId = `beacon_${beaconRef.id}`;

  await beaconRef.set({
    schemaVersion: 1,
    creatorId: ctx.uid,
    creatorProfile: {
      name: maskDisplayName(meData.displayName),
      avatarUrl: meData.avatarUrl ?? null,
    },
    eventId: input.eventId,
    cityId: event.cityId ?? null,
    title: input.title,
    spot: input.spot,
    meetAt: Timestamp.fromMillis(input.meetAt),
    maxPeople: input.maxPeople,
    vibeTags: input.vibeTags.filter((t) => VIBE_TAGS.includes(t.toLowerCase())),
    joinMode: input.joinMode,
    memberCount: 1,
    chatId,
    status: 'active',
    expiresAt: endAt ? Timestamp.fromDate(endAt) : Timestamp.fromMillis(input.meetAt + 6 * 60 * 60 * 1000),
    createdAt: FieldValue.serverTimestamp(),
  });

  await beaconRef.collection('members').doc(ctx.uid).set({
    uid: ctx.uid,
    name: String(meData.displayName ?? 'Milo User'),
    avatarUrl: meData.avatarUrl ?? null,
    status: 'joined',
    at: FieldValue.serverTimestamp(),
  });

  const chatRef = db().collection('chats').doc(chatId);
  await chatRef.set({
    schemaVersion: 1,
    type: 'beacon',
    eventId: input.eventId,
    beaconId: beaconRef.id,
    title: input.title,
    memberCount: 1,
    participants: [ctx.uid],
    lastMessageAt: FieldValue.serverTimestamp(),
    lastReadAt: {},
    muted: {},
    status: 'active',
    createdAt: FieldValue.serverTimestamp(),
  });
  await chatRef.collection('members').doc(ctx.uid).set({
    uid: ctx.uid,
    name: String(meData.displayName ?? 'Milo User'),
    avatarUrl: meData.avatarUrl ?? null,
    role: 'organizer',
    joinedAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, beaconId: beaconRef.id, chatId };
});

export const joinBeacon = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ beaconId: z.string().min(1).max(64) }).parse(req.data);

  await consumeRateLimit(rateLimitKey('beacon_join', ctx.uid), 30, 60 * 60 * 1000);

  const beaconRef = db().collection('beacons').doc(input.beaconId);
  const snap = await beaconRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Beacon not found.');
  const beacon = snap.data()!;
  if (beacon.status !== 'active') fail('CONFLICT', 'This beacon is no longer active.');

  const attendee = await db().collection('eventAttendees').doc(`${beacon.eventId}_${ctx.uid}`).get();
  if (!attendee.exists) fail('FORBIDDEN', 'You need a ticket to join this beacon.');

  const memberRef = beaconRef.collection('members').doc(ctx.uid);
  const existing = await memberRef.get();
  if (existing.exists) {
    return { ok: true, status: existing.data()?.status ?? 'joined', chatId: beacon.chatId };
  }

  if (Number(beacon.memberCount ?? 0) >= Number(beacon.maxPeople ?? 0)) {
    fail('LIMIT_EXCEEDED', 'This beacon is full.');
  }

  const me = await db().collection('users').doc(ctx.uid).get();
  const meData = me.data() ?? {};
  const name = String(meData.displayName ?? 'Milo User');

  if (beacon.joinMode === 'request') {
    await memberRef.set({
      uid: ctx.uid,
      name,
      avatarUrl: meData.avatarUrl ?? null,
      status: 'requested',
      at: FieldValue.serverTimestamp(),
    });
    await notifyUser(
      String(beacon.creatorId),
      'beacon_join_request',
      'Beacon join request',
      `${name} asked to join "${beacon.title}".`,
      { deepLink: `/beacon/${input.beaconId}`, channel: 'social' },
    ).catch(() => undefined);
    return { ok: true, status: 'requested', chatId: beacon.chatId };
  }

  await memberRef.set({
    uid: ctx.uid,
    name,
    avatarUrl: meData.avatarUrl ?? null,
    status: 'joined',
    at: FieldValue.serverTimestamp(),
  });
  await beaconRef.update({ memberCount: FieldValue.increment(1) });
  await db()
    .collection('chats')
    .doc(String(beacon.chatId))
    .collection('members')
    .doc(ctx.uid)
    .set({
      uid: ctx.uid,
      name,
      avatarUrl: meData.avatarUrl ?? null,
      role: 'member',
      joinedAt: FieldValue.serverTimestamp(),
    });
  await db()
    .collection('chats')
    .doc(String(beacon.chatId))
    .set(
      { memberCount: FieldValue.increment(1), participants: FieldValue.arrayUnion(ctx.uid) },
      { merge: true },
    );

  return { ok: true, status: 'joined', chatId: beacon.chatId };
});

export const listBeacons = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ eventId: z.string().min(1).max(64) }).parse(req.data);

  const attendee = await db().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
  if (!attendee.exists) fail('FORBIDDEN', 'You need a ticket to view beacons for this event.');

  const beacons = await db()
    .collection('beacons')
    .where('eventId', '==', input.eventId)
    .where('status', '==', 'active')
    .limit(50)
    .get();

  const myBlocks = await db().collection('users').doc(ctx.uid).collection('blocks').get();
  const blocked = new Set(myBlocks.docs.map((d) => d.id));

  return {
    beacons: beacons.docs
      .map((d) => {
        const data = d.data();
        return {
          id: d.id,
          creatorId: data.creatorId,
          creatorName: maskDisplayName(data.creatorProfile?.name),
          title: data.title,
          spot: data.spot,
          meetAt: data.meetAt,
          maxPeople: data.maxPeople,
          memberCount: data.memberCount ?? 0,
          vibeTags: data.vibeTags ?? [],
          joinMode: data.joinMode,
          chatId: data.chatId,
        };
      })
      .filter((b) => !blocked.has(b.creatorId)),
  };
});

export { ensureDmChat };
