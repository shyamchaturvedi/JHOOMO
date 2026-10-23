"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hasConsent = exports.submitReport = exports.blockUser = exports.listConnections = exports.respondConnection = exports.sendConnectionRequest = exports.listRadarMembers = exports.setRadarOptIn = void 0;
exports.ensureDmChat = ensureDmChat;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const consent_1 = require("../shared/consent");
Object.defineProperty(exports, "hasConsent", { enumerable: true, get: function () { return consent_1.hasConsent; } });
const notify_1 = require("../shared/notify");
const ratelimit_1 = require("../shared/ratelimit");
const age_1 = require("../shared/age");
const config_1 = require("../shared/config");
const time_1 = require("../shared/time");
const mask_1 = require("../shared/mask");
const RADAR_TTL_DAYS = 7;
async function loadProfile(uid) {
    const snap = await (0, admin_1.db)().collection('users').doc(uid).get();
    return (snap.data() ?? {});
}
exports.setRadarOptIn = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        eventId: zod_1.z.string().min(1).max(64),
        optedIn: zod_1.z.boolean(),
        consentGranted: zod_1.z.boolean(),
    })
        .parse(req.data);
    const attendee = await (0, admin_1.db)()
        .collection('eventAttendees')
        .doc(`${input.eventId}_${ctx.uid}`)
        .get();
    if (!attendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You need a ticket to join the radar for this event.');
    const event = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!event.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    if (event.data()?.radarEnabled !== true)
        (0, errors_1.fail)('FORBIDDEN', 'Radar is disabled for this event.');
    const userRef = (0, admin_1.db)().collection('users').doc(ctx.uid);
    const user = await userRef.get();
    const userData = user.data() ?? {};
    const consents = (0, consent_1.mergeConsents)(userData.consents, [{ type: 'radar', granted: input.consentGranted }], firestore_1.Timestamp.now());
    await userRef.set({ consents, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    const memberRef = (0, admin_1.db)().collection('events').doc(input.eventId).collection('radarMembers').doc(ctx.uid);
    const existingMember = await memberRef.get();
    if (!input.optedIn || !input.consentGranted) {
        await memberRef.delete().catch(() => undefined);
        await (0, admin_1.db)()
            .collection('eventAttendees')
            .doc(`${input.eventId}_${ctx.uid}`)
            .set({ radarOptIn: false }, { merge: true });
        if (existingMember.exists) {
            await (0, admin_1.db)()
                .collection('eventStats')
                .doc(input.eventId)
                .set({ radarCount: firestore_1.FieldValue.increment(-1), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        }
        return { ok: true, optedIn: false };
    }
    const profile = await loadProfile(ctx.uid);
    const endAt = event.data()?.schedule?.endAt?.toDate() ?? new Date();
    const expiresAt = firestore_1.Timestamp.fromDate((0, time_1.addDays)(endAt, RADAR_TTL_DAYS));
    await memberRef.set({
        schemaVersion: 1,
        uid: ctx.uid,
        displayName: (0, mask_1.maskDisplayName)(profile.displayName),
        avatarUrl: profile.avatarUrl ?? null,
        ageBand: profile.dob ? (0, age_1.ageBand)(profile.dob.toDate()) : '25-34',
        interests: (profile.interests ?? []).slice(0, 12),
        bio: profile.bio ?? null,
        faceVerified: profile.faceVerified === true,
        optedInAt: firestore_1.FieldValue.serverTimestamp(),
        lastActiveAt: firestore_1.FieldValue.serverTimestamp(),
        expiresAt,
    });
    await (0, admin_1.db)()
        .collection('eventAttendees')
        .doc(`${input.eventId}_${ctx.uid}`)
        .set({ radarOptIn: true }, { merge: true });
    if (!existingMember.exists) {
        await (0, admin_1.db)()
            .collection('eventStats')
            .doc(input.eventId)
            .set({ radarCount: firestore_1.FieldValue.increment(1), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    return { ok: true, optedIn: true, expiresAt: expiresAt.toDate().toISOString() };
});
exports.listRadarMembers = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        eventId: zod_1.z.string().min(1).max(64),
        limit: zod_1.z.number().int().min(1).max(50).default(20),
        cursor: zod_1.z.string().max(512).optional(),
    })
        .parse(req.data);
    const attendee = await (0, admin_1.db)().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
    if (!attendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You need a ticket to view the radar for this event.');
    const me = await loadProfile(ctx.uid);
    const blocks = await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('blocks').get();
    const blocked = new Set(blocks.docs.map((d) => d.id));
    let query = (0, admin_1.db)()
        .collection('events')
        .doc(input.eventId)
        .collection('radarMembers')
        .orderBy('lastActiveAt', 'desc')
        .limit(input.limit + 1);
    if (input.cursor) {
        const cursorSnap = await memberRef(input.eventId, input.cursor).get();
        if (cursorSnap.exists)
            query = query.startAfter(cursorSnap);
    }
    const snap = await query.get();
    const docs = snap.docs.slice(0, input.limit);
    const members = docs
        .map((d) => {
        const data = d.data();
        return {
            uid: d.id,
            displayName: (0, mask_1.maskDisplayName)(data.displayName),
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
        nextCursor: snap.docs.length > input.limit ? docs[docs.length - 1].id : null,
        incognito: me.privacy?.incognito === true,
    };
});
function memberRef(eventId, uid) {
    return (0, admin_1.db)().collection('events').doc(eventId).collection('radarMembers').doc(uid);
}
const connectionRequestSchema = zod_1.z.object({
    toUid: zod_1.z.string().min(1).max(64),
    eventId: zod_1.z.string().min(1).max(64),
    message: zod_1.z.string().trim().max(300).optional(),
});
exports.sendConnectionRequest = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = connectionRequestSchema.parse(req.data);
    const limits = await (0, config_1.getLimitsConfig)();
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('connection_request', ctx.uid), limits.hellosPerDay, 24 * 60 * 60 * 1000);
    if (input.toUid === ctx.uid)
        (0, errors_1.fail)('INVALID_INPUT', 'You cannot send a request to yourself.');
    const blocked = await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('blocks').doc(input.toUid).get();
    if (blocked.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You cannot contact this person.');
    const blockedBy = await (0, admin_1.db)().collection('users').doc(input.toUid).collection('blocks').doc(ctx.uid).get();
    if (blockedBy.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You cannot contact this person.');
    const targetAttendee = await (0, admin_1.db)()
        .collection('eventAttendees')
        .doc(`${input.eventId}_${input.toUid}`)
        .get();
    if (!targetAttendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'This person is not attending this event.');
    const targetProfile = await loadProfile(input.toUid);
    if (targetProfile.privacy?.mutualInterestOnly === true) {
        (0, errors_1.fail)('FORBIDDEN', 'This person only accepts requests from mutual matches.');
    }
    const myProfile = await loadProfile(ctx.uid);
    const docId = `${ctx.uid}_${input.toUid}`;
    const ref = (0, admin_1.db)().collection('connections').doc(docId);
    const existing = await ref.get();
    if (existing.exists) {
        const status = String(existing.data()?.status ?? '');
        if (status === 'pending')
            return { ok: true, status: 'pending', connectionId: docId };
        if (status === 'accepted')
            return { ok: true, status: 'accepted', chatId: existing.data()?.chatId };
    }
    const reverseId = `${input.toUid}_${ctx.uid}`;
    const reverse = await (0, admin_1.db)().collection('connections').doc(reverseId).get();
    if (reverse.exists && reverse.data()?.status === 'pending') {
        await reverse.ref.set({ status: 'accepted', respondedAt: firestore_1.FieldValue.serverTimestamp(), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        const chatId = await ensureDmChat(ctx.uid, input.toUid, input.eventId, myProfile, targetProfile);
        await reverse.ref.set({ chatId }, { merge: true });
        await ref.set({
            fromUid: ctx.uid,
            toUid: input.toUid,
            eventId: input.eventId,
            fromProfile: { name: myProfile.displayName ?? 'Milo User', avatarUrl: myProfile.avatarUrl ?? null },
            toProfile: { name: targetProfile.displayName ?? 'Milo User', avatarUrl: targetProfile.avatarUrl ?? null },
            status: 'accepted',
            chatId,
            respondedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            expiresAt: firestore_1.Timestamp.fromDate((0, time_1.addDays)(new Date(), RADAR_TTL_DAYS)),
        }, { merge: true });
        await (0, notify_1.notifyUser)(input.toUid, 'connection_accepted', 'Connection accepted', 'Someone you connected with is now available to chat.', { deepLink: `/chat/${chatId}`, channel: 'social' }).catch(() => undefined);
        return { ok: true, status: 'accepted', chatId };
    }
    await ref.set({
        schemaVersion: 1,
        fromUid: ctx.uid,
        toUid: input.toUid,
        eventId: input.eventId,
        message: input.message ?? null,
        fromProfile: { name: (0, mask_1.maskDisplayName)(myProfile.displayName), avatarUrl: myProfile.avatarUrl ?? null },
        toProfile: { name: (0, mask_1.maskDisplayName)(targetProfile.displayName), avatarUrl: targetProfile.avatarUrl ?? null },
        status: 'pending',
        respondedAt: null,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        expiresAt: firestore_1.Timestamp.fromDate((0, time_1.addDays)(new Date(), RADAR_TTL_DAYS)),
    });
    await (0, notify_1.notifyUser)(input.toUid, 'connection_request', 'New connection request', 'Someone at your event wants to connect.', { deepLink: '/requests', channel: 'social' }).catch(() => undefined);
    return { ok: true, status: 'pending', connectionId: docId };
});
exports.respondConnection = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        connectionId: zod_1.z.string().min(1).max(140),
        accept: zod_1.z.boolean(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('connections').doc(input.connectionId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Request not found.');
    const connection = snap.data();
    if (connection.toUid !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This request belongs to someone else.');
    if (connection.status !== 'pending')
        (0, errors_1.fail)('CONFLICT', 'This request has already been handled.');
    if (!input.accept) {
        await ref.set({ status: 'declined', respondedAt: firestore_1.FieldValue.serverTimestamp(), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        await (0, notify_1.notifyUser)(String(connection.fromUid), 'connection_declined', 'Request declined', 'Your connection request was declined.', { deepLink: '/requests', channel: 'social' }).catch(() => undefined);
        return { ok: true, status: 'declined' };
    }
    const myProfile = await loadProfile(ctx.uid);
    const theirProfile = await loadProfile(String(connection.fromUid));
    const chatId = await ensureDmChat(ctx.uid, String(connection.fromUid), String(connection.eventId), myProfile, theirProfile);
    await ref.set({
        status: 'accepted',
        chatId,
        respondedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const reverseRef = (0, admin_1.db)().collection('connections').doc(`${connection.fromUid}_${ctx.uid}`);
    await reverseRef.set({
        schemaVersion: 1,
        fromUid: connection.fromUid,
        toUid: ctx.uid,
        eventId: connection.eventId,
        fromProfile: { name: theirProfile.displayName ?? 'Milo User', avatarUrl: theirProfile.avatarUrl ?? null },
        toProfile: { name: myProfile.displayName ?? 'Milo User', avatarUrl: myProfile.avatarUrl ?? null },
        status: 'accepted',
        chatId,
        respondedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        expiresAt: firestore_1.Timestamp.fromDate((0, time_1.addDays)(new Date(), RADAR_TTL_DAYS)),
    }, { merge: true });
    await (0, notify_1.notifyUser)(String(connection.fromUid), 'connection_accepted', 'Connection accepted', 'Your connection request was accepted. Start chatting.', { deepLink: `/chat/${chatId}`, channel: 'social' }).catch(() => undefined);
    return { ok: true, status: 'accepted', chatId };
});
async function ensureDmChat(uidA, uidB, eventId, profileA, profileB) {
    const chatId = [uidA, uidB].sort().join('_');
    const ref = (0, admin_1.db)().collection('chats').doc(chatId);
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
            lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
            lastReadAt: {},
            muted: {},
            status: 'active',
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
        await Promise.all([uidA, uidB].map((uid) => ref.collection('members').doc(uid).set({
            uid,
            name: uid === uidA ? profileA.displayName ?? 'Milo User' : profileB.displayName ?? 'Milo User',
            avatarUrl: (uid === uidA ? profileA.avatarUrl : profileB.avatarUrl) ?? null,
            role: 'member',
            joinedAt: firestore_1.FieldValue.serverTimestamp(),
        })));
    }
    return chatId;
}
exports.listConnections = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({ status: zod_1.z.enum(['pending', 'accepted', 'declined', 'expired']).optional() })
        .parse(req.data ?? {});
    const queries = input.status
        ? [
            (0, admin_1.db)().collection('connections').where('toUid', '==', ctx.uid).where('status', '==', input.status),
            (0, admin_1.db)().collection('connections').where('fromUid', '==', ctx.uid).where('status', '==', input.status),
        ]
        : [
            (0, admin_1.db)().collection('connections').where('toUid', '==', ctx.uid),
            (0, admin_1.db)().collection('connections').where('fromUid', '==', ctx.uid),
        ];
    const results = await Promise.all(queries.map((q) => q.limit(50).get()));
    const merged = new Map();
    for (const snap of results) {
        for (const doc of snap.docs)
            merged.set(doc.id, { id: doc.id, ...doc.data() });
    }
    return {
        connections: [...merged.values()].sort((a, b) => Number(b.respondedAt ?? 0) - Number(a.respondedAt ?? 0)),
    };
});
exports.blockUser = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ uid: zod_1.z.string().min(1).max(64), reason: zod_1.z.string().trim().max(200).optional() }).parse(req.data);
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .collection('blocks')
        .doc(input.uid)
        .set({ uid: input.uid, reason: input.reason ?? null, createdAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
exports.submitReport = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        targetType: zod_1.z.enum(['user', 'message', 'event', 'chat', 'beacon']),
        targetId: zod_1.z.string().min(1).max(128),
        eventId: zod_1.z.string().min(1).max(64).optional(),
        reason: zod_1.z.string().trim().min(3).max(200),
        note: zod_1.z.string().trim().max(1000).optional(),
        evidence: zod_1.z
            .array(zod_1.z.object({
            senderId: zod_1.z.string().min(1).max(64),
            text: zod_1.z.string().max(1000),
            at: zod_1.z.number().int().positive(),
        }))
            .max(10)
            .optional(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('reports').doc();
    await ref.set({
        schemaVersion: 1,
        reporterId: ctx.uid,
        targetType: input.targetType,
        targetId: input.targetId,
        eventId: input.eventId ?? null,
        reason: input.reason,
        note: input.note ?? null,
        evidence: (input.evidence ?? []).map((e) => ({ ...e, at: firestore_1.Timestamp.fromMillis(e.at) })),
        status: 'open',
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true, reportId: ref.id };
});
//# sourceMappingURL=radar.js.map