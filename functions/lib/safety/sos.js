"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveSOS = exports.updateSOSLocation = exports.triggerSOS = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const node_crypto_1 = require("node:crypto");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const notify_1 = require("../shared/notify");
const sms_1 = require("../shared/sms");
const ratelimit_1 = require("../shared/ratelimit");
const SOS_TRACKING_MINUTES = 60;
const SOS_LOCATION_INTERVAL_SECONDS = 15;
const SOS_RETENTION_DAYS = 90;
exports.triggerSOS = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        eventId: zod_1.z.string().min(1).max(64).optional(),
        latitude: zod_1.z.number().min(-90).max(90),
        longitude: zod_1.z.number().min(-180).max(180),
        accuracyM: zod_1.z.number().min(0).max(10_000).default(50),
        notes: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('sos_trigger', ctx.uid), 6, 60 * 60 * 1000);
    const userSnap = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    if (!userSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'User profile not found.');
    const user = userSnap.data();
    const contactsSnap = await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .collection('emergencyContacts')
        .get();
    const confirmed = contactsSnap.docs
        .map((d) => ({ ...d.data(), id: d.id }))
        .filter((c) => c.status === 'confirmed');
    const trackingToken = (0, node_crypto_1.randomBytes)(24).toString('hex');
    const trackingTokenHash = (0, node_crypto_1.createHash)('sha256').update(trackingToken).digest('hex');
    const trackingUrl = `https://milo.live/sos/${trackingToken}`;
    const alertRef = (0, admin_1.db)().collection('sosAlerts').doc();
    const now = firestore_1.Timestamp.now();
    const expiresAt = firestore_1.Timestamp.fromMillis(now.toMillis() + SOS_RETENTION_DAYS * 86_400_000);
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
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await alertRef.collection('locationUpdates').doc().set({
        location,
        accuracyM: input.accuracyM,
        at: now,
        expiresAt,
    });
    const contactsNotified = [];
    for (const contact of confirmed) {
        const sms = await (0, sms_1.sendSms)(contact.phone, process.env.SMS_TEMPLATE_SOS ?? 'SOS_TEMPLATE', [
            user.displayName ? String(user.displayName) : 'Someone',
            trackingUrl,
        ]);
        contactsNotified.push({
            contactId: contact.id,
            channel: 'sms',
            at: firestore_1.Timestamp.now(),
            status: sms.ok ? 'sent' : 'failed',
        });
    }
    let venueNotified = false;
    if (input.eventId) {
        const attendee = await (0, admin_1.db)().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`).get();
        if (attendee.exists) {
            const event = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
            const organizerId = event.data()?.organizerId;
            if (organizerId) {
                const organizer = await (0, admin_1.db)().collection('organizers').doc(organizerId).get();
                const deskPhone = organizer.data()?.emergencyPhone;
                if (deskPhone) {
                    const sms = await (0, sms_1.sendSms)(deskPhone, process.env.SMS_TEMPLATE_SOS_VENUE ?? 'SOS_VENUE_TEMPLATE', [
                        String(event.data()?.title ?? 'Event'),
                        trackingUrl,
                    ]);
                    venueNotified = sms.ok;
                }
                await (0, notify_1.notifyUser)(organizerId, 'sos_active', 'SOS alert at your event', 'A guest triggered an SOS alert. Check the venue security desk.', { deepLink: '/organizer/alerts', channel: 'safety' }).catch(() => undefined);
            }
        }
    }
    await alertRef.set({
        contactsNotified,
        venueNotified,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .set({
        sosActive: true,
        sosAlertId: alertRef.id,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
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
exports.updateSOSLocation = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        alertId: zod_1.z.string().min(1).max(64),
        latitude: zod_1.z.number().min(-90).max(90),
        longitude: zod_1.z.number().min(-180).max(180),
        accuracyM: zod_1.z.number().min(0).max(10_000).default(50),
    })
        .parse(req.data);
    const alertRef = (0, admin_1.db)().collection('sosAlerts').doc(input.alertId);
    const snap = await alertRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'SOS alert not found.');
    const alert = snap.data();
    if (alert.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This alert belongs to someone else.');
    if (alert.status !== 'active')
        (0, errors_1.fail)('CONFLICT', 'This alert is no longer active.');
    const startedAt = alert.startedAt?.toMillis() ?? Date.now();
    if (Date.now() - startedAt > SOS_TRACKING_MINUTES * 60 * 1000) {
        (0, errors_1.fail)('EVENT_ENDED', 'The SOS tracking window has ended.');
    }
    const location = { latitude: input.latitude, longitude: input.longitude };
    const at = firestore_1.Timestamp.now();
    const expiresAt = alert.expiresAt;
    await alertRef.collection('locationUpdates').doc().set({
        location,
        accuracyM: input.accuracyM,
        at,
        expiresAt,
    });
    await alertRef.set({
        lastLocation: location,
        lastLocationAt: at,
        accuracyM: input.accuracyM,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.resolveSOS = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        alertId: zod_1.z.string().min(1).max(64),
        resolution: zod_1.z.enum(['safe', 'cancelled']).default('safe'),
    })
        .parse(req.data);
    const alertRef = (0, admin_1.db)().collection('sosAlerts').doc(input.alertId);
    const snap = await alertRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'SOS alert not found.');
    const alert = snap.data();
    if (alert.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This alert belongs to someone else.');
    if (alert.status !== 'active')
        (0, errors_1.fail)('CONFLICT', 'This alert is already closed.');
    await alertRef.set({
        status: 'resolved',
        resolution: input.resolution,
        resolvedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .set({ sosActive: false, sosAlertId: null, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    const contacts = (alert.contactsNotified ?? []);
    for (const contact of contacts) {
        if (contact.status !== 'sent')
            continue;
        const contactSnap = await (0, admin_1.db)()
            .collection('users')
            .doc(ctx.uid)
            .collection('emergencyContacts')
            .doc(contact.contactId)
            .get();
        const phone = contactSnap.data()?.phone;
        if (!phone)
            continue;
        await (0, sms_1.sendSms)(phone, process.env.SMS_TEMPLATE_SOS_RESOLVED ?? 'SOS_RESOLVED_TEMPLATE', ['Safe']).catch(() => undefined);
    }
    return { ok: true };
});
//# sourceMappingURL=sos.js.map