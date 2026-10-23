import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { createHash, randomBytes } from 'node:crypto';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { notifyUser } from '../shared/notify';
import { sendSms } from '../shared/sms';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';

const SOS_TRACKING_MINUTES = 60;
const SOS_LOCATION_INTERVAL_SECONDS = 15;
const SOS_RETENTION_DAYS = 90;

interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
  relationship?: string;
  status: 'pending' | 'confirmed' | 'declined';
}

export const triggerSOS = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      eventId: z.string().min(1).max(64).optional(),
      latitude: z.number().min(-90).max(90),
      longitude: z.number().min(-180).max(180),
      accuracyM: z.number().min(0).max(10_000).default(50),
      notes: z.string().trim().max(500).optional(),
    })
    .parse(req.data);

  await consumeRateLimit(rateLimitKey('sos_trigger', ctx.uid), 6, 60 * 60 * 1000);

  const userSnap = await db().collection('users').doc(ctx.uid).get();
  if (!userSnap.exists) fail('NOT_FOUND', 'User profile not found.');
  const user = userSnap.data()!;

  const contactsSnap = await db()
    .collection('users')
    .doc(ctx.uid)
    .collection('emergencyContacts')
    .get();
  const confirmed = contactsSnap.docs
    .map((d) => ({ ...(d.data() as EmergencyContact), id: d.id }))
    .filter((c) => c.status === 'confirmed');

  const trackingToken = randomBytes(24).toString('hex');
  const trackingTokenHash = createHash('sha256').update(trackingToken).digest('hex');
  const trackingUrl = `https://milo.live/sos/${trackingToken}`;

  const alertRef = db().collection('sosAlerts').doc();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + SOS_RETENTION_DAYS * 86_400_000);

  const location = { latitude: input.latitude, longitude: input.longitude };

  await alertRef.set({
    schemaVersion: 1,
    userId: ctx.uid,
    eventId: input.eventId ?? null,
    organizerId: null,
    status: 'active',
    startedAt: now,
    lastLocation: location,
    lastLocationAt: now,
    accuracyM: input.accuracyM,
    contactsNotified: [],
    venueNotified: false,
    trackingTokenHash,
    notes: input.notes ?? null,
    expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });

  await alertRef.collection('locationUpdates').doc().set({
    location,
    accuracyM: input.accuracyM,
    at: now,
    expiresAt,
  });

  const contactsNotified: Array<{ contactId: string; channel: 'sms' | 'push'; at: Timestamp; status: 'sent' | 'failed' }> = [];

  for (const contact of confirmed) {
    const sms = await sendSms(contact.phone, process.env.SMS_TEMPLATE_SOS ?? 'SOS_TEMPLATE', [
      user.displayName ? String(user.displayName) : 'Someone',
      trackingUrl,
    ]);
    contactsNotified.push({
      contactId: contact.id,
      channel: 'sms',
      at: Timestamp.now(),
      status: sms.ok ? 'sent' : 'failed',
    });
  }

  let venueNotified = false;
  if (input.eventId) {
    const attendee = await db().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
    if (attendee.exists) {
      const event = await db().collection('events').doc(input.eventId).get();
      const organizerId = event.data()?.organizerId as string | undefined;
      if (organizerId) {
        const organizer = await db().collection('organizers').doc(organizerId).get();
        const deskPhone = organizer.data()?.emergencyPhone as string | undefined;
        if (deskPhone) {
          const sms = await sendSms(deskPhone, process.env.SMS_TEMPLATE_SOS_VENUE ?? 'SOS_VENUE_TEMPLATE', [
            String(event.data()?.title ?? 'Event'),
            trackingUrl,
          ]);
          venueNotified = sms.ok;
        }
        await notifyUser(
          organizerId,
          'sos_active',
          'SOS alert at your event',
          'A guest triggered an SOS alert. Check the venue security desk.',
          { deepLink: '/organizer/alerts', channel: 'safety' },
        ).catch(() => undefined);
      }
    }
  }

  await alertRef.set(
    {
      contactsNotified,
      venueNotified,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db()
    .collection('users')
    .doc(ctx.uid)
    .set(
      {
        sosActive: true,
        sosAlertId: alertRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  return {
    ok: true,
    alertId: alertRef.id,
    trackingUrl,
    contactsNotified,
    venueNotified,
    trackingWindowMinutes: SOS_TRACKING_MINUTES,
    locationIntervalSeconds: SOS_LOCATION_INTERVAL_SECONDS,
    confirmedContactCount: confirmed.length,
  };
});

export const updateSOSLocation = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      alertId: z.string().min(1).max(64),
      latitude: z.number().min(-90).max(90),
      longitude: z.number().min(-180).max(180),
      accuracyM: z.number().min(0).max(10_000).default(50),
    })
    .parse(req.data);

  const alertRef = db().collection('sosAlerts').doc(input.alertId);
  const snap = await alertRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'SOS alert not found.');
  const alert = snap.data()!;
  if (alert.userId !== ctx.uid) fail('FORBIDDEN', 'This alert belongs to someone else.');
  if (alert.status !== 'active') fail('CONFLICT', 'This alert is no longer active.');

  const startedAt = (alert.startedAt as Timestamp | undefined)?.toMillis() ?? Date.now();
  if (Date.now() - startedAt > SOS_TRACKING_MINUTES * 60 * 1000) {
    fail('EVENT_ENDED', 'The SOS tracking window has ended.');
  }

  const location = { latitude: input.latitude, longitude: input.longitude };
  const at = Timestamp.now();
  const expiresAt = alert.expiresAt as Timestamp;

  await alertRef.collection('locationUpdates').doc().set({
    location,
    accuracyM: input.accuracyM,
    at,
    expiresAt,
  });
  await alertRef.set(
    {
      lastLocation: location,
      lastLocationAt: at,
      accuracyM: input.accuracyM,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true };
});

export const resolveSOS = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      alertId: z.string().min(1).max(64),
      resolution: z.enum(['safe', 'cancelled']).default('safe'),
    })
    .parse(req.data);

  const alertRef = db().collection('sosAlerts').doc(input.alertId);
  const snap = await alertRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'SOS alert not found.');
  const alert = snap.data()!;
  if (alert.userId !== ctx.uid) fail('FORBIDDEN', 'This alert belongs to someone else.');
  if (alert.status !== 'active') fail('CONFLICT', 'This alert is already closed.');

  await alertRef.set(
    {
      status: 'resolved',
      resolution: input.resolution,
      resolvedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db()
    .collection('users')
    .doc(ctx.uid)
    .set({ sosActive: false, sosAlertId: null, updatedAt: FieldValue.serverTimestamp() }, { merge: true });

  const contacts = (alert.contactsNotified ?? []) as Array<{ contactId: string; status: string }>;
  for (const contact of contacts) {
    if (contact.status !== 'sent') continue;
    const contactSnap = await db()
      .collection('users')
      .doc(ctx.uid)
      .collection('emergencyContacts')
      .doc(contact.contactId)
      .get();
    const phone = contactSnap.data()?.phone as string | undefined;
    if (!phone) continue;
    await sendSms(
      phone,
      process.env.SMS_TEMPLATE_SOS_RESOLVED ?? 'SOS_RESOLVED_TEMPLATE',
      ['Safe'],
    ).catch(() => undefined);
  }

  return { ok: true };
});
