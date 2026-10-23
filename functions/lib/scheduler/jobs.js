"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.expireBeacons = exports.archiveChats = exports.lockGroupChats = exports.completeFinishedEvents = exports.accountDeletionJob = exports.computeTrendScore = exports.eventReminders = exports.expireReservations = void 0;
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin_1 = require("../shared/admin");
const inventory_1 = require("../booking/inventory");
const notify_1 = require("../shared/notify");
const time_1 = require("../shared/time");
/**
 * Releases inventory held by abandoned checkouts (§13.3 `expireReservations`).
 * Runs every minute so a held seat never blocks another buyer for long.
 */
exports.expireReservations = (0, scheduler_1.onSchedule)({ schedule: 'every 1 minutes', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = firestore_1.Timestamp.now();
    const stale = await (0, admin_1.db)()
        .collection('bookings')
        .where('status', '==', 'pending_payment')
        .where('reservationExpiresAt', '<=', now)
        .limit(200)
        .get();
    let expired = 0;
    for (const doc of stale.docs) {
        const booking = doc.data();
        const updated = await (0, admin_1.db)()
            .collection('bookings')
            .doc(doc.id)
            .update({
            status: 'expired',
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        })
            .then(() => true)
            .catch(() => false);
        if (!updated)
            continue;
        const allocations = (booking.reservation?.shards ?? []);
        await (0, inventory_1.releaseInventory)(String(booking.eventId), allocations).catch(() => undefined);
        expired += 1;
    }
    if (expired > 0)
        firebase_functions_1.logger.info('expireReservations.complete', { expired });
});
/**
 * Sends the 24-hour and 2-hour event reminders (§14). Reminders are marked on
 * the ticket so a rescheduled run never double-sends.
 */
exports.eventReminders = (0, scheduler_1.onSchedule)({ schedule: 'every 15 minutes', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = new Date();
    const todayKey = (0, time_1.istDateKey)(now);
    const windows = [
        { hours: 24, id: 'event_reminder_24h' },
        { hours: 2, id: 'event_reminder_2h' },
    ];
    for (const window of windows) {
        const events = await (0, admin_1.db)()
            .collection('events')
            .where('status', 'in', ['live', 'sold_out'])
            .get();
        for (const eventDoc of events.docs) {
            const event = eventDoc.data();
            const startAt = event.schedule?.startAt;
            if (!startAt)
                continue;
            const deltaHours = (startAt.toMillis() - now.getTime()) / (60 * 60 * 1000);
            if (deltaHours <= 0 || deltaHours > window.hours)
                continue;
            const key = `${eventDoc.id}_${todayKey}_${window.hours}`;
            const marker = (0, admin_1.db)().collection('notificationMarkers').doc(key);
            const markerSnap = await marker.get();
            if (markerSnap.exists)
                continue;
            const attendees = await (0, admin_1.db)().collection('eventAttendees').where('eventId', '==', eventDoc.id).get();
            for (const attendee of attendees.docs) {
                const uid = String(attendee.data().uid);
                await (0, notify_1.notifyUser)(uid, window.id, window.hours === 24 ? 'Starting tomorrow' : 'Starting soon', `"${event.title}" starts in ${window.hours} hours. Open your ticket for the QR.`, { deepLink: `/event/${eventDoc.id}`, channel: 'reminders' }).catch(() => undefined);
            }
            await marker.set({ sentAt: firestore_1.FieldValue.serverTimestamp(), count: attendees.size }, { merge: true });
        }
    }
});
/**
 * Ranks events for the Trending rail using sales velocity, wishlist pressure
 * and recency (§13.3 `computeTrendScore`).
 */
exports.computeTrendScore = (0, scheduler_1.onSchedule)({ schedule: 'every 1 hours', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = Date.now();
    const events = await (0, admin_1.db)()
        .collection('events')
        .where('status', 'in', ['live', 'sold_out'])
        .limit(300)
        .get();
    for (const doc of events.docs) {
        const event = doc.data();
        const soldPct = Number(event.soldPct ?? 0);
        const startAt = event.schedule?.startAt?.toMillis() ?? now;
        const daysOut = Math.max(0, (startAt - now) / 86_400_000);
        const statsSnap = await (0, admin_1.db)().collection('eventStats').doc(doc.id).get();
        const wishlistCount = Number(statsSnap.data()?.wishlistCount ?? 0);
        const radarCount = Number(statsSnap.data()?.radarCount ?? 0);
        const velocity = soldPct / Math.max(0.5, daysOut);
        const wishlistPressure = Math.min(40, wishlistCount * 2);
        const radarPressure = Math.min(20, radarCount);
        const recency = Math.max(0, 30 - daysOut);
        const score = Math.round(velocity * 12 + wishlistPressure + radarPressure + recency);
        if (Number(event.trendScore ?? 0) === score)
            continue;
        await doc.ref.set({ trendScore: score, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    firebase_functions_1.logger.info('computeTrendScore.complete', { scanned: events.size });
});
/**
 * Executes account deletions after the 30-day grace period (§13.3
 * `accountDeletionJob`). PII is erased; financial records are retained for the
 * statutory period (8 years, OPEN-10).
 */
exports.accountDeletionJob = (0, scheduler_1.onSchedule)({ schedule: 'every day 03:00', timeZone: 'Asia/Kolkata', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = firestore_1.Timestamp.now();
    const pending = await (0, admin_1.db)()
        .collection('users')
        .where('status', '==', 'deletion_pending')
        .where('deletionScheduledAt', '<=', now)
        .limit(50)
        .get();
    for (const doc of pending.docs) {
        const uid = doc.id;
        try {
            await (0, admin_1.db)()
                .collection('users')
                .doc(uid)
                .set({
                status: 'deleted',
                displayName: 'Deleted user',
                avatarUrl: null,
                bio: null,
                interests: [],
                phone: null,
                email: null,
                dob: null,
                faceVerified: false,
                deletedAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            await (0, admin_1.db)()
                .collection('publicProfiles')
                .doc(uid)
                .set({ schemaVersion: 1, deleted: true }, { merge: true })
                .catch(() => undefined);
            await (0, admin_1.db)().collection('users').doc(uid).collection('notifications').get().then((s) => Promise.all(s.docs.map((d) => d.ref.delete())).catch(() => undefined));
            await (0, admin_1.authAdmin)().deleteUser(uid).catch(() => undefined);
            firebase_functions_1.logger.info('accountDeletionJob.deleted', { uid });
        }
        catch (err) {
            firebase_functions_1.logger.error('accountDeletionJob.failed', { uid, error: String(err) });
        }
    }
});
/**
 * Marks finished events as `completed` so settlement can be scheduled
 * (PRD §9 event state machine).
 */
exports.completeFinishedEvents = (0, scheduler_1.onSchedule)({ schedule: 'every 30 minutes', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = firestore_1.Timestamp.now();
    const events = await (0, admin_1.db)()
        .collection('events')
        .where('status', 'in', ['live', 'sold_out'])
        .get();
    let completed = 0;
    for (const doc of events.docs) {
        const endAt = doc.data().schedule?.endAt;
        if (!endAt || endAt.toMillis() > now.toMillis())
            continue;
        await doc.ref.set({ status: 'completed', completedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        completed += 1;
    }
    if (completed > 0)
        firebase_functions_1.logger.info('completeFinishedEvents.complete', { completed });
});
/**
 * Locks event group chats 24 h after the event ends and archives them 7 days
 * after that (PRD S-23 lifecycle, §13.3 `lockGroupChats` / `archiveChats`).
 */
exports.lockGroupChats = (0, scheduler_1.onSchedule)({ schedule: 'every 15 minutes', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = Date.now();
    const chats = await (0, admin_1.db)()
        .collection('chats')
        .where('type', '==', 'event_group')
        .where('status', '==', 'active')
        .limit(200)
        .get();
    let locked = 0;
    for (const doc of chats.docs) {
        const eventId = String(doc.data().eventId ?? '');
        if (!eventId)
            continue;
        const event = await (0, admin_1.db)().collection('events').doc(eventId).get();
        const endAt = event.data()?.schedule?.endAt;
        if (!endAt)
            continue;
        if (endAt.toMillis() + 24 * 60 * 60 * 1000 > now)
            continue;
        await doc.ref.set({ status: 'locked', lockAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        locked += 1;
    }
    if (locked > 0)
        firebase_functions_1.logger.info('lockGroupChats.complete', { locked });
});
exports.archiveChats = (0, scheduler_1.onSchedule)({ schedule: 'every day 04:30', timeZone: 'Asia/Kolkata', region: 'asia-south1', maxInstances: 1 }, async () => {
    const cutoff = firestore_1.Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const chats = await (0, admin_1.db)()
        .collection('chats')
        .where('status', '==', 'locked')
        .limit(300)
        .get();
    let archived = 0;
    for (const doc of chats.docs) {
        const lockAt = doc.data().lockAt;
        if (!lockAt || lockAt.toMillis() > cutoff.toMillis())
            continue;
        await doc.ref.set({ status: 'archived' }, { merge: true });
        archived += 1;
    }
    if (archived > 0)
        firebase_functions_1.logger.info('archiveChats.complete', { archived });
});
/**
 * Expires beacons at the end of their event (PRD S-24).
 */
exports.expireBeacons = (0, scheduler_1.onSchedule)({ schedule: 'every 15 minutes', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = firestore_1.Timestamp.now();
    const beacons = await (0, admin_1.db)()
        .collection('beacons')
        .where('status', 'in', ['active', 'full'])
        .limit(300)
        .get();
    let expired = 0;
    for (const doc of beacons.docs) {
        const expiresAt = doc.data().expiresAt;
        if (!expiresAt || expiresAt.toMillis() > now.toMillis())
            continue;
        await doc.ref.set({ status: 'expired' }, { merge: true });
        expired += 1;
    }
    if (expired > 0)
        firebase_functions_1.logger.info('expireBeacons.complete', { expired });
});
//# sourceMappingURL=jobs.js.map