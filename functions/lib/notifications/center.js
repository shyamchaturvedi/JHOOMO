"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listHelpArticles = exports.updateNotificationPrefs = exports.unregisterDevice = exports.registerDevice = exports.deleteNotification = exports.markAllNotificationsRead = exports.markNotificationRead = exports.listNotifications = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
exports.listNotifications = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        limit: zod_1.z.number().int().min(1).max(100).default(30),
        cursor: zod_1.z.string().max(128).optional(),
        unreadOnly: zod_1.z.boolean().default(false),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .collection('notifications')
        .orderBy('createdAt', 'desc')
        .limit(input.limit + 1);
    if (input.cursor) {
        const snap = await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('notifications').doc(input.cursor).get();
        if (snap.exists)
            query = query.startAfter(snap);
    }
    const snap = await query.get();
    const unreadDocs = snap.docs.filter((d) => d.data().readAt == null);
    const docs = input.unreadOnly ? unreadDocs.slice(0, input.limit) : snap.docs.slice(0, input.limit);
    return {
        notifications: docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                type: data.type,
                title: data.title,
                body: data.body,
                deepLink: data.deepLink ?? null,
                readAt: data.readAt ?? null,
                createdAt: data.createdAt ?? null,
            };
        }),
        nextCursor: snap.docs.length > input.limit ? docs[docs.length - 1].id : null,
    };
});
exports.markNotificationRead = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ notificationId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .collection('notifications')
        .doc(input.notificationId)
        .set({ readAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
exports.markAllNotificationsRead = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const unread = await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .collection('notifications')
        .orderBy('createdAt', 'desc')
        .limit(200)
        .get();
    const batch = (0, admin_1.db)().batch();
    let marked = 0;
    for (const doc of unread.docs) {
        if (doc.data().readAt != null)
            continue;
        batch.update(doc.ref, { readAt: firestore_1.FieldValue.serverTimestamp() });
        marked += 1;
    }
    if (marked > 0)
        await batch.commit();
    return { ok: true, marked };
});
exports.deleteNotification = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ notificationId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('notifications').doc(input.notificationId).delete();
    return { ok: true };
});
exports.registerDevice = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        fcmToken: zod_1.z.string().min(20).max(4096),
        platform: zod_1.z.enum(['android', 'ios', 'web']),
        appVersion: zod_1.z.string().max(32).optional(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('users').doc(ctx.uid).collection('devices').doc(input.fcmToken.slice(-40));
    await ref.set({
        uid: ctx.uid,
        fcmToken: input.fcmToken,
        platform: input.platform,
        appVersion: input.appVersion ?? null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.unregisterDevice = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ fcmToken: zod_1.z.string().min(20).max(4096) }).parse(req.data);
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .collection('devices')
        .doc(input.fcmToken.slice(-40))
        .delete();
    return { ok: true };
});
exports.updateNotificationPrefs = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        prefs: zod_1.z.record(zod_1.z.enum(['bookings', 'reminders', 'social', 'safety', 'marketing']), zod_1.z.boolean()),
    })
        .parse(req.data);
    const userRef = (0, admin_1.db)().collection('users').doc(ctx.uid);
    await userRef.set({ notificationPrefs: input.prefs, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true, prefs: input.prefs };
});
exports.listHelpArticles = (0, callable_1.miloOnCall)({}, async (req) => {
    const input = zod_1.z
        .object({
        category: zod_1.z.string().max(40).optional(),
        search: zod_1.z.string().trim().max(80).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('helpArticles').where('published', '==', true).limit(input.limit);
    if (input.category)
        query = query.where('category', '==', input.category);
    const snap = await query.get();
    const articles = snap.docs
        .map((d) => {
        const data = d.data();
        return {
            id: d.id,
            title: data.title,
            body: data.body,
            category: data.category,
            order: data.order ?? 0,
        };
    })
        .filter((a) => input.search
        ? `${a.title} ${a.body}`.toLowerCase().includes(input.search.toLowerCase())
        : true);
    return { articles };
});
//# sourceMappingURL=center.js.map