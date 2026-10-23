"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureDmChat = exports.listBeacons = exports.joinBeacon = exports.createBeacon = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const config_1 = require("../shared/config");
const ratelimit_1 = require("../shared/ratelimit");
const notify_1 = require("../shared/notify");
const mask_1 = require("../shared/mask");
const radar_1 = require("./radar");
Object.defineProperty(exports, "ensureDmChat", { enumerable: true, get: function () { return radar_1.ensureDmChat; } });
const VIBE_TAGS = ['music', 'food', 'art', 'sports', 'nightlife', 'startup', 'travel', 'wellness'];
exports.createBeacon = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        eventId: zod_1.z.string().min(1).max(64),
        title: zod_1.z.string().trim().min(3).max(60),
        spot: zod_1.z.string().trim().min(2).max(120),
        meetAt: zod_1.z.number().int().positive(),
        maxPeople: zod_1.z.number().int().min(2).max(20),
        vibeTags: zod_1.z.array(zod_1.z.string().trim().min(1).max(20)).max(5).default([]),
        joinMode: zod_1.z.enum(['open', 'request']).default('open'),
    })
        .parse(req.data);
    const attendee = await (0, admin_1.db)().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
    if (!attendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You need a ticket to create a beacon for this event.');
    if (attendee.data()?.radarOptIn !== true) {
        (0, errors_1.fail)('FORBIDDEN', 'Turn on Radar for this event to create a beacon.');
    }
    const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const event = eventSnap.data();
    const endAt = event.schedule?.endAt?.toDate();
    const startAt = event.schedule?.startAt?.toDate();
    if (endAt && new Date(input.meetAt).getTime() > endAt.getTime()) {
        (0, errors_1.fail)('INVALID_INPUT', 'Meet-up time must be before the event ends.');
    }
    if (startAt && new Date(input.meetAt).getTime() < startAt.getTime() - 6 * 60 * 60 * 1000) {
        (0, errors_1.fail)('INVALID_INPUT', 'Meet-up time must be within 6 hours of the event start.');
    }
    const limits = await (0, config_1.getLimitsConfig)();
    const active = await (0, admin_1.db)()
        .collection('beacons')
        .where('creatorId', '==', ctx.uid)
        .where('status', '==', 'active')
        .get();
    if (active.size >= limits.beaconsPerUser) {
        (0, errors_1.fail)('LIMIT_EXCEEDED', `You can have up to ${limits.beaconsPerUser} active beacons at a time.`);
    }
    const me = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const meData = me.data() ?? {};
    const beaconRef = (0, admin_1.db)().collection('beacons').doc();
    const chatId = `beacon_${beaconRef.id}`;
    await beaconRef.set({
        schemaVersion: 1,
        creatorId: ctx.uid,
        creatorProfile: {
            name: (0, mask_1.maskDisplayName)(meData.displayName),
            avatarUrl: meData.avatarUrl ?? null,
        },
        eventId: input.eventId,
        cityId: event.cityId ?? null,
        title: input.title,
        spot: input.spot,
        meetAt: firestore_1.Timestamp.fromMillis(input.meetAt),
        maxPeople: input.maxPeople,
        vibeTags: input.vibeTags.filter((t) => VIBE_TAGS.includes(t.toLowerCase())),
        joinMode: input.joinMode,
        memberCount: 1,
        chatId,
        status: 'active',
        expiresAt: endAt ? firestore_1.Timestamp.fromDate(endAt) : firestore_1.Timestamp.fromMillis(input.meetAt + 6 * 60 * 60 * 1000),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await beaconRef.collection('members').doc(ctx.uid).set({
        uid: ctx.uid,
        name: String(meData.displayName ?? 'Milo User'),
        avatarUrl: meData.avatarUrl ?? null,
        status: 'joined',
        at: firestore_1.FieldValue.serverTimestamp(),
    });
    const chatRef = (0, admin_1.db)().collection('chats').doc(chatId);
    await chatRef.set({
        schemaVersion: 1,
        type: 'beacon',
        eventId: input.eventId,
        beaconId: beaconRef.id,
        title: input.title,
        memberCount: 1,
        participants: [ctx.uid],
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        lastReadAt: {},
        muted: {},
        status: 'active',
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await chatRef.collection('members').doc(ctx.uid).set({
        uid: ctx.uid,
        name: String(meData.displayName ?? 'Milo User'),
        avatarUrl: meData.avatarUrl ?? null,
        role: 'organizer',
        joinedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true, beaconId: beaconRef.id, chatId };
});
exports.joinBeacon = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ beaconId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('beacon_join', ctx.uid), 30, 60 * 60 * 1000);
    const beaconRef = (0, admin_1.db)().collection('beacons').doc(input.beaconId);
    const snap = await beaconRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Beacon not found.');
    const beacon = snap.data();
    if (beacon.status !== 'active')
        (0, errors_1.fail)('CONFLICT', 'This beacon is no longer active.');
    const attendee = await (0, admin_1.db)().collection('eventAttendees').doc(`${beacon.eventId}_${ctx.uid}`).get();
    if (!attendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You need a ticket to join this beacon.');
    const memberRef = beaconRef.collection('members').doc(ctx.uid);
    const existing = await memberRef.get();
    if (existing.exists) {
        return { ok: true, status: existing.data()?.status ?? 'joined', chatId: beacon.chatId };
    }
    if (Number(beacon.memberCount ?? 0) >= Number(beacon.maxPeople ?? 0)) {
        (0, errors_1.fail)('LIMIT_EXCEEDED', 'This beacon is full.');
    }
    const me = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const meData = me.data() ?? {};
    const name = String(meData.displayName ?? 'Milo User');
    if (beacon.joinMode === 'request') {
        await memberRef.set({
            uid: ctx.uid,
            name,
            avatarUrl: meData.avatarUrl ?? null,
            status: 'requested',
            at: firestore_1.FieldValue.serverTimestamp(),
        });
        await (0, notify_1.notifyUser)(String(beacon.creatorId), 'beacon_join_request', 'Beacon join request', `${name} asked to join "${beacon.title}".`, { deepLink: `/beacon/${input.beaconId}`, channel: 'social' }).catch(() => undefined);
        return { ok: true, status: 'requested', chatId: beacon.chatId };
    }
    await memberRef.set({
        uid: ctx.uid,
        name,
        avatarUrl: meData.avatarUrl ?? null,
        status: 'joined',
        at: firestore_1.FieldValue.serverTimestamp(),
    });
    await beaconRef.update({ memberCount: firestore_1.FieldValue.increment(1) });
    await (0, admin_1.db)()
        .collection('chats')
        .doc(String(beacon.chatId))
        .collection('members')
        .doc(ctx.uid)
        .set({
        uid: ctx.uid,
        name,
        avatarUrl: meData.avatarUrl ?? null,
        role: 'member',
        joinedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, admin_1.db)()
        .collection('chats')
        .doc(String(beacon.chatId))
        .set({ memberCount: firestore_1.FieldValue.increment(1), participants: firestore_1.FieldValue.arrayUnion(ctx.uid) }, { merge: true });
    return { ok: true, status: 'joined', chatId: beacon.chatId };
});
exports.listBeacons = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ eventId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const attendee = await (0, admin_1.db)().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
    if (!attendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You need a ticket to view beacons for this event.');
    const beacons = await (0, admin_1.db)()
        .collection('beacons')
        .where('eventId', '==', input.eventId)
        .where('status', '==', 'active')
        .limit(50)
        .get();
    const myBlocks = await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('blocks').get();
    const blocked = new Set(myBlocks.docs.map((d) => d.id));
    return {
        beacons: beacons.docs
            .map((d) => {
            const data = d.data();
            return {
                id: d.id,
                creatorId: data.creatorId,
                creatorName: (0, mask_1.maskDisplayName)(data.creatorProfile?.name),
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
//# sourceMappingURL=beacons.js.map