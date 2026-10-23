import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db, messaging } from './admin';

export type MiloChannel = 'bookings' | 'reminders' | 'social' | 'safety' | 'marketing';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  channel?: MiloChannel;
  priority?: 'high' | 'normal';
}

const ANDROID_PRIORITY: Record<MiloChannel, 'high' | 'normal'> = {
  bookings: 'high',
  reminders: 'normal',
  social: 'normal',
  safety: 'high',
  marketing: 'normal',
};

async function deviceTokens(uid: string): Promise<string[]> {
  const snap = await db().collection('users').doc(uid).collection('devices').get();
  return snap.docs.map((d) => String(d.data().fcmToken ?? '')).filter((t) => t.length > 0);
}

export async function sendPushToUser(uid: string, payload: PushPayload): Promise<void> {
  const tokens = await deviceTokens(uid);
  if (tokens.length === 0) return;
  const channel = payload.channel ?? 'social';
  try {
    await messaging().sendEachForMulticast({
      tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: {
        priority: payload.priority ?? ANDROID_PRIORITY[channel],
        notification: { channelId: channel, tag: payload.data?.deepLink ?? undefined },
      },
      apns: { headers: { 'apns-priority': channel === 'safety' ? '10' : '5' } },
    });
  } catch (err) {
    console.warn('push failed', uid, err instanceof Error ? err.message : err);
  }
}

export async function sendPushToUsers(uids: string[], payload: PushPayload): Promise<void> {
  await Promise.all(uids.map((uid) => sendPushToUser(uid, payload)));
}

export async function sendPushToTopic(topic: string, payload: PushPayload): Promise<void> {
  try {
    await messaging().send({
      topic,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: payload.priority ?? ANDROID_PRIORITY[payload.channel ?? 'social'] },
    });
  } catch (err) {
    console.warn('topic push failed', topic, err instanceof Error ? err.message : err);
  }
}

export async function createNotification(
  uid: string,
  type: string,
  title: string,
  body: string,
  opts: { deepLink?: string; data?: Record<string, string>; ttlDays?: number } = {},
): Promise<string> {
  const ref = db().collection('users').doc(uid).collection('notifications').doc();
  const ttlDays = opts.ttlDays ?? 90;
  await ref.set({
    type,
    title,
    body,
    deepLink: opts.deepLink ?? null,
    data: opts.data ?? {},
    readAt: null,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + ttlDays * 24 * 60 * 60 * 1000),
  });
  return ref.id;
}

export async function notifyUser(
  uid: string,
  type: string,
  title: string,
  body: string,
  opts: { deepLink?: string; data?: Record<string, string>; channel?: MiloChannel; ttlDays?: number } = {},
): Promise<void> {
  await createNotification(uid, type, title, body, opts);
  await sendPushToUser(uid, {
    title,
    body,
    data: { type, deepLink: opts.deepLink ?? '', ...(opts.data ?? {}) },
    channel: opts.channel ?? 'social',
  });
}
