"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPushToUser = sendPushToUser;
exports.sendPushToUsers = sendPushToUsers;
exports.sendPushToTopic = sendPushToTopic;
exports.createNotification = createNotification;
exports.notifyUser = notifyUser;
const firestore_1 = require("firebase-admin/firestore");
const admin_1 = require("./admin");
const ANDROID_PRIORITY = {
    bookings: 'high',
    reminders: 'normal',
    social: 'normal',
    safety: 'high',
    marketing: 'normal',
};
async function deviceTokens(uid) {
    const snap = await (0, admin_1.db)().collection('users').doc(uid).collection('devices').get();
    return snap.docs.map((d) => String(d.data().fcmToken ?? '')).filter((t) => t.length > 0);
}
async function sendPushToUser(uid, payload) {
    const tokens = await deviceTokens(uid);
    if (tokens.length === 0)
        return;
    const channel = payload.channel ?? 'social';
    try {
        await (0, admin_1.messaging)().sendEachForMulticast({
            tokens,
            notification: { title: payload.title, body: payload.body },
            data: payload.data ?? {},
            android: {
                priority: payload.priority ?? ANDROID_PRIORITY[channel],
                notification: { channelId: channel, tag: payload.data?.deepLink ?? undefined },
            },
            apns: { headers: { 'apns-priority': channel === 'safety' ? '10' : '5' } },
        });
    }
    catch (err) {
        console.warn('push failed', uid, err instanceof Error ? err.message : err);
    }
}
async function sendPushToUsers(uids, payload) {
    await Promise.all(uids.map((uid) => sendPushToUser(uid, payload)));
}
async function sendPushToTopic(topic, payload) {
    try {
        await (0, admin_1.messaging)().send({
            topic,
            notification: { title: payload.title, body: payload.body },
            data: payload.data ?? {},
            android: { priority: payload.priority ?? ANDROID_PRIORITY[payload.channel ?? 'social'] },
        });
    }
    catch (err) {
        console.warn('topic push failed', topic, err instanceof Error ? err.message : err);
    }
}
async function createNotification(uid, type, title, body, opts = {}) {
    const ref = (0, admin_1.db)().collection('users').doc(uid).collection('notifications').doc();
    const ttlDays = opts.ttlDays ?? 90;
    await ref.set({
        type,
        title,
        body,
        deepLink: opts.deepLink ?? null,
        data: opts.data ?? {},
        readAt: null,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        expiresAt: firestore_1.Timestamp.fromMillis(Date.now() + ttlDays * 24 * 60 * 60 * 1000),
    });
    return ref.id;
}
async function notifyUser(uid, type, title, body, opts = {}) {
    await createNotification(uid, type, title, body, opts);
    await sendPushToUser(uid, {
        title,
        body,
        data: { type, deepLink: opts.deepLink ?? '', ...(opts.data ?? {}) },
        channel: opts.channel ?? 'social',
    });
}
//# sourceMappingURL=notify.js.map