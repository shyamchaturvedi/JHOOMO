import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';

export const listNotifications = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      limit: z.number().int().min(1).max(100).default(30),
      cursor: z.string().max(128).optional(),
      unreadOnly: z.boolean().default(false),
    })
    .parse(req.data ?? {});

  let query = db()
    .collection('users')
    .doc(ctx.uid)
    .collection('notifications')
    .orderBy('createdAt', 'desc')
    .limit(input.limit + 1);

  if (input.cursor) {
    const snap = await db().collection('users').doc(ctx.uid).collection('notifications').doc(input.cursor).get();
    if (snap.exists) query = query.startAfter(snap);
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
    nextCursor: snap.docs.length > input.limit ? docs[docs.length - 1]!.id : null,
  };
});

export const markNotificationRead = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ notificationId: z.string().min(1).max(64) }).parse(req.data);
  await db()
    .collection('users')
    .doc(ctx.uid)
    .collection('notifications')
    .doc(input.notificationId)
    .set({ readAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true };
});

export const markAllNotificationsRead = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const unread = await db()
    .collection('users')
    .doc(ctx.uid)
    .collection('notifications')
    .orderBy('createdAt', 'desc')
    .limit(200)
    .get();
  const batch = db().batch();
  let marked = 0;
  for (const doc of unread.docs) {
    if (doc.data().readAt != null) continue;
    batch.update(doc.ref, { readAt: FieldValue.serverTimestamp() });
    marked += 1;
  }
  if (marked > 0) await batch.commit();
  return { ok: true, marked };
});

export const deleteNotification = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ notificationId: z.string().min(1).max(64) }).parse(req.data);
  await db().collection('users').doc(ctx.uid).collection('notifications').doc(input.notificationId).delete();
  return { ok: true };
});

export const registerDevice = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      fcmToken: z.string().min(20).max(4096),
      platform: z.enum(['android', 'ios', 'web']),
      appVersion: z.string().max(32).optional(),
    })
    .parse(req.data);

  const ref = db().collection('users').doc(ctx.uid).collection('devices').doc(input.fcmToken.slice(-40));
  await ref.set(
    {
      uid: ctx.uid,
      fcmToken: input.fcmToken,
      platform: input.platform,
      appVersion: input.appVersion ?? null,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true };
});

export const unregisterDevice = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ fcmToken: z.string().min(20).max(4096) }).parse(req.data);
  await db()
    .collection('users')
    .doc(ctx.uid)
    .collection('devices')
    .doc(input.fcmToken.slice(-40))
    .delete();
  return { ok: true };
});

export const updateNotificationPrefs = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      prefs: z.record(
        z.enum(['bookings', 'reminders', 'social', 'safety', 'marketing']),
        z.boolean(),
      ),
    })
    .parse(req.data);

  const userRef = db().collection('users').doc(ctx.uid);
  await userRef.set(
    { notificationPrefs: input.prefs, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { ok: true, prefs: input.prefs };
});

export const listHelpArticles = miloOnCall({}, async (req) => {
  const input = z
    .object({
      category: z.string().max(40).optional(),
      search: z.string().trim().max(80).optional(),
      limit: z.number().int().min(1).max(100).default(50),
    })
    .parse(req.data ?? {});

  let query = db().collection('helpArticles').where('published', '==', true).limit(input.limit);
  if (input.category) query = query.where('category', '==', input.category);

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
    .filter((a) =>
      input.search
        ? `${a.title} ${a.body}`.toLowerCase().includes(input.search.toLowerCase())
        : true,
    );

  return { articles };
});
