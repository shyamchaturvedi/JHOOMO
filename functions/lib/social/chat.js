"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.moderateChat = exports.joinEventGroupChat = exports.deleteMessage = exports.markChatRead = exports.sendMessage = exports.getChatMessages = exports.listChats = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const profanity_1 = require("../shared/profanity");
const ratelimit_1 = require("../shared/ratelimit");
const notify_1 = require("../shared/notify");
const audit_1 = require("../shared/audit");
const callable_2 = require("../shared/callable");
const GROUP_ROOM_SIZE = 500;
const MESSAGE_MAX_LENGTH = 1000;
const GROUP_MESSAGE_MAX_LENGTH = 500;
async function loadChat(chatIdValue) {
    const ref = (0, admin_1.db)().collection('chats').doc(chatIdValue);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Chat not found.');
    return { ref, data: snap.data() };
}
async function assertMember(chatIdValue, uid) {
    const { data } = await loadChat(chatIdValue);
    const member = await (0, admin_1.db)().collection('chats').doc(chatIdValue).collection('members').doc(uid).get();
    if (!member.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You are not a member of this chat.');
    return { ...data, role: member.data()?.role ?? 'member', memberName: member.data()?.name ?? '' };
}
exports.listChats = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        type: zod_1.z.enum(['dm', 'event_group', 'beacon']).optional(),
        limit: zod_1.z.number().int().min(1).max(50).default(30),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('chats').where('participants', 'array-contains', ctx.uid);
    if (input.type)
        query = query.where('type', '==', input.type);
    const snap = await query.orderBy('lastMessageAt', 'desc').limit(input.limit).get();
    const chats = snap.docs.map((doc) => {
        const data = doc.data();
        const lastRead = data.lastReadAt?.[ctx.uid];
        const lastMessageAt = data.lastMessageAt;
        const unread = lastMessageAt && (!lastRead || lastMessageAt.toMillis() > lastRead.toMillis());
        const peer = data.type === 'dm'
            ? (data.participants ?? []).find((p) => p !== ctx.uid)
            : null;
        return {
            id: doc.id,
            type: data.type,
            title: data.type === 'dm'
                ? data.participantsInfo?.[peer ?? '']?.name ?? 'Direct message'
                : data.title ?? 'Group',
            avatarUrl: data.type === 'dm' ? data.participantsInfo?.[peer ?? '']?.avatarUrl ?? null : null,
            peerUid: peer,
            eventId: data.eventId ?? null,
            memberCount: data.memberCount ?? 0,
            status: data.status ?? 'active',
            muted: data.muted?.[ctx.uid] === true,
            lastMessageAt: lastMessageAt ?? null,
            lastMessageType: data.lastMessageType ?? null,
            unread: Boolean(unread),
        };
    });
    return { chats };
});
exports.getChatMessages = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        chatId: zod_1.z.string().min(1).max(140),
        limit: zod_1.z.number().int().min(1).max(50).default(30),
        before: zod_1.z.string().max(128).optional(),
    })
        .parse(req.data);
    await assertMember(input.chatId, ctx.uid);
    let query = (0, admin_1.db)()
        .collection('chats')
        .doc(input.chatId)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(input.limit + 1);
    if (input.before) {
        const snap = await (0, admin_1.db)().collection('chats').doc(input.chatId).collection('messages').doc(input.before).get();
        if (snap.exists)
            query = query.endBefore(snap);
    }
    const snap = await query.get();
    const docs = snap.docs.slice(0, input.limit);
    return {
        messages: docs.reverse().map((d) => {
            const data = d.data();
            return {
                id: d.id,
                senderId: data.senderId,
                type: data.type,
                text: data.text ?? null,
                ciphertext: data.ciphertext ?? null,
                nonce: data.nonce ?? null,
                keyVersion: data.keyVersion ?? null,
                clientMsgId: data.clientMsgId ?? null,
                createdAt: data.createdAt ?? null,
                deleted: data.deleted === true,
                flagged: data.flagged === true,
            };
        }),
        hasMore: snap.docs.length > input.limit,
    };
});
exports.sendMessage = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        chatId: zod_1.z.string().min(1).max(140),
        type: zod_1.z.enum(['text', 'image']).default('text'),
        text: zod_1.z.string().trim().max(MESSAGE_MAX_LENGTH).optional(),
        ciphertext: zod_1.z.string().max(8000).optional(),
        nonce: zod_1.z.string().max(64).optional(),
        keyVersion: zod_1.z.number().int().min(1).max(100).optional(),
        clientMsgId: zod_1.z.string().min(1).max(64),
    })
        .parse(req.data);
    const chat = await assertMember(input.chatId, ctx.uid);
    if (chat.status === 'locked')
        (0, errors_1.fail)('FORBIDDEN', 'This chat is read-only.');
    if (chat.status === 'archived')
        (0, errors_1.fail)('FORBIDDEN', 'This chat has been archived.');
    const isDm = chat.type === 'dm';
    if (isDm && !input.ciphertext)
        (0, errors_1.fail)('INVALID_INPUT', 'Encrypted payload is required.');
    if (!isDm && !input.text)
        (0, errors_1.fail)('INVALID_INPUT', 'Message text is required.');
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('chat_msg', ctx.uid, input.chatId), 30, 60 * 1000);
    if (!isDm) {
        await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('chat_msg_2s', input.chatId, ctx.uid), 1, 2000);
    }
    const messagesRef = (0, admin_1.db)().collection('chats').doc(input.chatId).collection('messages');
    const dupe = await messagesRef.where('clientMsgId', '==', input.clientMsgId).limit(1).get();
    if (!dupe.empty)
        return { ok: true, messageId: dupe.docs[0].id, duplicate: true };
    const isModerator = chat.role === 'moderator' || chat.role === 'organizer';
    let text = input.text ?? '';
    let flagged = false;
    if (!isDm) {
        if (text.length > GROUP_MESSAGE_MAX_LENGTH) {
            (0, errors_1.fail)('INVALID_INPUT', `Group messages are limited to ${GROUP_MESSAGE_MAX_LENGTH} characters.`);
        }
        const check = (0, profanity_1.checkText)(text);
        if (check.hasLink && !isModerator) {
            (0, errors_1.fail)('FORBIDDEN', 'Links are not allowed in group chat.');
        }
        if (!check.clean) {
            text = check.masked ?? text;
            flagged = true;
        }
    }
    const ref = messagesRef.doc();
    await ref.set({
        schemaVersion: 1,
        senderId: ctx.uid,
        type: input.type,
        ...(isDm
            ? {
                ciphertext: input.ciphertext,
                nonce: input.nonce ?? null,
                keyVersion: input.keyVersion ?? 1,
            }
            : { text, senderName: chat.memberName ?? '' }),
        clientMsgId: input.clientMsgId,
        flagged,
        deleted: false,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, admin_1.db)()
        .collection('chats')
        .doc(input.chatId)
        .set({
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        lastSenderId: ctx.uid,
        lastMessageType: input.type,
    }, { merge: true });
    const members = await (0, admin_1.db)().collection('chats').doc(input.chatId).collection('members').get();
    for (const member of members.docs) {
        if (member.id === ctx.uid)
            continue;
        const muted = member.data()?.mutedUntil;
        if (muted && muted.toMillis() > Date.now())
            continue;
        await (0, notify_1.notifyUser)(member.id, 'chat_message', isDm ? 'New message' : 'New group message', isDm ? 'You have a new message.' : 'New activity in your event group.', { deepLink: `/chat/${input.chatId}`, channel: 'social' }).catch(() => undefined);
    }
    return { ok: true, messageId: ref.id, flagged };
});
exports.markChatRead = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ chatId: zod_1.z.string().min(1).max(140) }).parse(req.data);
    await assertMember(input.chatId, ctx.uid);
    await (0, admin_1.db)()
        .collection('chats')
        .doc(input.chatId)
        .set({ [`lastReadAt.${ctx.uid}`]: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
exports.deleteMessage = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        chatId: zod_1.z.string().min(1).max(140),
        messageId: zod_1.z.string().min(1).max(64),
        forEveryone: zod_1.z.boolean().default(false),
    })
        .parse(req.data);
    await assertMember(input.chatId, ctx.uid);
    const ref = (0, admin_1.db)().collection('chats').doc(input.chatId).collection('messages').doc(input.messageId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Message not found.');
    const message = snap.data();
    if (!input.forEveryone)
        return { ok: true, deletedLocally: true };
    const isAuthor = message.senderId === ctx.uid;
    const chat = await assertMember(input.chatId, ctx.uid);
    const isModerator = chat.role === 'moderator' || chat.role === 'organizer';
    if (!isAuthor && !isModerator)
        (0, errors_1.fail)('FORBIDDEN', 'You cannot delete this message.');
    if (isAuthor && !isModerator) {
        const createdAt = message.createdAt?.toMillis() ?? 0;
        if (Date.now() - createdAt > 10 * 60 * 1000) {
            (0, errors_1.fail)('FORBIDDEN', 'You can only delete your own message for everyone within 10 minutes.');
        }
    }
    await ref.set({ deleted: true, ciphertext: null, nonce: null, text: null, deletedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
exports.joinEventGroupChat = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ eventId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const attendee = await (0, admin_1.db)().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
    if (!attendee.exists)
        (0, errors_1.fail)('FORBIDDEN', 'You need a valid ticket to join the event group chat.');
    if (attendee.data()?.radarOptIn !== true) {
        (0, errors_1.fail)('FORBIDDEN', 'Turn on Radar for this event to join the group chat.');
    }
    const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    if (eventSnap.data()?.groupChatEnabled !== true)
        (0, errors_1.fail)('FORBIDDEN', 'Group chat is disabled for this event.');
    const me = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const name = String(me.data()?.displayName ?? 'Milo User');
    const rooms = await (0, admin_1.db)()
        .collection('chats')
        .where('type', '==', 'event_group')
        .where('eventId', '==', input.eventId)
        .limit(50)
        .get();
    let target;
    for (const room of rooms.docs) {
        if (Number(room.data().memberCount ?? 0) < GROUP_ROOM_SIZE) {
            target = room;
            break;
        }
    }
    const roomId = target?.id ?? `event_${input.eventId}_${rooms.size}`;
    const roomRef = (0, admin_1.db)().collection('chats').doc(roomId);
    const memberRef = roomRef.collection('members').doc(ctx.uid);
    const existing = await memberRef.get();
    if (existing.exists)
        return { ok: true, chatId: roomId, joined: true };
    await roomRef.set({
        schemaVersion: 1,
        type: 'event_group',
        eventId: input.eventId,
        title: String(eventSnap.data()?.title ?? 'Event group'),
        roomIndex: Number(roomId.split('_').pop() ?? 0),
        memberCount: firestore_1.FieldValue.increment(1),
        participants: firestore_1.FieldValue.arrayUnion(ctx.uid),
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        lastReadAt: {},
        muted: {},
        status: 'active',
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await memberRef.set({
        uid: ctx.uid,
        name,
        avatarUrl: me.data()?.avatarUrl ?? null,
        role: 'member',
        joinedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true, chatId: roomId, joined: true };
});
exports.moderateChat = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        chatId: zod_1.z.string().min(1).max(140),
        action: zod_1.z.enum(['delete_message', 'mute_member', 'remove_member', 'lock', 'unlock']),
        messageId: zod_1.z.string().max(64).optional(),
        targetUid: zod_1.z.string().max(64).optional(),
        minutes: zod_1.z.number().int().min(1).max(10_080).default(60),
        reason: zod_1.z.string().trim().max(300).optional(),
    })
        .parse(req.data);
    const roomRef = (0, admin_1.db)().collection('chats').doc(input.chatId);
    const room = await roomRef.get();
    if (!room.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Chat not found.');
    switch (input.action) {
        case 'delete_message': {
            if (!input.messageId)
                (0, errors_1.fail)('INVALID_INPUT', 'messageId is required.');
            await roomRef
                .collection('messages')
                .doc(input.messageId)
                .set({ deleted: true, text: null, ciphertext: null, flagged: true }, { merge: true });
            break;
        }
        case 'mute_member': {
            if (!input.targetUid)
                (0, errors_1.fail)('INVALID_INPUT', 'targetUid is required.');
            await roomRef
                .collection('members')
                .doc(input.targetUid)
                .set({ mutedUntil: firestore_1.Timestamp.fromMillis(Date.now() + input.minutes * 60_000) }, { merge: true });
            break;
        }
        case 'remove_member': {
            if (!input.targetUid)
                (0, errors_1.fail)('INVALID_INPUT', 'targetUid is required.');
            await roomRef.collection('members').doc(input.targetUid).delete();
            await roomRef.set({ memberCount: firestore_1.FieldValue.increment(-1) }, { merge: true });
            break;
        }
        case 'lock':
        case 'unlock':
            await roomRef.set({ status: input.action === 'lock' ? 'locked' : 'active' }, { merge: true });
            break;
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: `chat.${input.action}`,
        targetType: 'chat',
        targetId: input.chatId,
        after: { action: input.action, targetUid: input.targetUid ?? null },
        reason: input.reason,
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true };
});
//# sourceMappingURL=chat.js.map