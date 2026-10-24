"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.razorpayWebhook = void 0;
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/https");
const node_crypto_1 = require("node:crypto");
const admin_1 = require("../shared/admin");
const razorpay_1 = require("../shared/razorpay");
const notify_1 = require("../shared/notify");
const inventory_1 = require("./inventory");
const promo_1 = require("./promo");
const finance_1 = require("../settlement/finance");
exports.razorpayWebhook = (0, https_1.onRequest)({
    region: 'asia-south1',
    secrets: [razorpay_1.RAZORPAY_KEY_ID, razorpay_1.RAZORPAY_KEY_SECRET, razorpay_1.RAZORPAY_WEBHOOK_SECRET],
}, async (req, res) => {
    const signature = req.header('x-razorpay-signature') ?? '';
    const rawBody = req.rawBody ?? Buffer.from(JSON.stringify(req.body ?? {}));
    if (!(0, razorpay_1.verifyWebhookSignature)(rawBody, signature)) {
        firebase_functions_1.logger.warn('razorpay.webhook.invalid_signature');
        res.status(401).json({ ok: false, error: 'INVALID_SIGNATURE' });
        return;
    }
    const body = (req.body ?? {});
    const eventName = body.event ?? '';
    const entity = body.payload?.payment?.entity;
    const refundEntity = body.payload?.refund?.entity;
    if (eventName === 'payment.captured' && entity?.order_id && entity.id) {
        await handleCaptured(entity.order_id, entity.id, Number(entity.amount ?? 0), entity.method ?? 'unknown');
    }
    else if (eventName === 'payment.failed' && entity?.order_id) {
        await handleFailed(entity.order_id, entity.id ?? '');
    }
    else if (eventName === 'refund.processed' && refundEntity?.payment_id) {
        await handleRefundProcessed(refundEntity.payment_id, refundEntity.id ?? '', Number(refundEntity.amount ?? 0));
    }
    else if (eventName === 'refund.failed' && refundEntity?.payment_id) {
        await handleRefundFailed(refundEntity.payment_id, refundEntity.id ?? '');
    }
    else {
        firebase_functions_1.logger.info('razorpay.webhook.unhandled', { eventName });
    }
    res.status(200).json({ ok: true });
});
async function findBookingByOrderId(orderId) {
    const snap = await (0, admin_1.db)().collection('bookings').where('payment.orderId', '==', orderId).limit(1).get();
    if (snap.empty)
        return null;
    const doc = snap.docs[0];
    return { ref: doc.ref, id: doc.id, data: doc.data() };
}
async function handleCaptured(orderId, gatewayPaymentId, amountPaise, method) {
    const found = await findBookingByOrderId(orderId);
    if (!found) {
        firebase_functions_1.logger.warn('razorpay.webhook.no_booking', { orderId });
        return;
    }
    const paymentId = gatewayPaymentId;
    const paymentRef = (0, admin_1.db)().collection('payments').doc(paymentId);
    const alreadyCaptured = await (0, admin_1.db)()
        .collection('bookings')
        .doc(found.id)
        .get()
        .then((s) => s.data()?.status === 'confirmed' || s.data()?.status === 'completed');
    if (alreadyCaptured) {
        firebase_functions_1.logger.info('razorpay.webhook.duplicate_ignored', { bookingId: found.id });
        return;
    }
    const expired = found.data.status === 'expired';
    if (expired) {
        const stillAvailable = await hasInventory(found.data);
        if (!stillAvailable) {
            await autoRefundLateCapture(found.id, paymentId, amountPaise);
            return;
        }
    }
    const allocations = (found.data.reservation?.shards ?? []);
    const ticketIds = [];
    const ticketDocs = [];
    const secretDocs = [];
    const items = (found.data.items ?? []);
    const userSnap = await (0, admin_1.db)().collection('users').doc(found.data.userId).get();
    const user = userSnap.data() ?? {};
    let seq = 1;
    for (const item of items) {
        for (let i = 0; i < item.qty; i += 1) {
            const ticketId = `tk_${(0, node_crypto_1.randomBytes)(9).toString('hex')}`;
            ticketIds.push(ticketId);
            ticketDocs.push({
                id: ticketId,
                data: {
                    schemaVersion: 1,
                    bookingId: found.id,
                    refCode: found.data.refCode,
                    userId: found.data.userId,
                    eventId: found.data.eventId,
                    organizerId: found.data.organizerId,
                    tierId: item.tierId,
                    tierName: item.tierName,
                    eventStartAt: found.data.eventSnapshot?.startAt ?? null,
                    eventTitle: found.data.eventSnapshot?.title ?? '',
                    seq,
                    admits: item.admits ?? 1,
                    holderName: item.holderNames?.[i] ?? null,
                    status: 'valid',
                    qrVersion: 1,
                    issuedAt: firestore_1.FieldValue.serverTimestamp(),
                },
            });
            secretDocs.push({
                id: ticketId,
                data: {
                    schemaVersion: 1,
                    secret: (0, node_crypto_1.randomBytes)(32).toString('base64'),
                    version: 1,
                    createdAt: firestore_1.FieldValue.serverTimestamp(),
                },
            });
            seq += 1;
        }
    }
    const attendeeRef = (0, admin_1.db)()
        .collection('eventAttendees')
        .doc(`${found.data.eventId}_${found.data.userId}`);
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const [bookingSnap, attendeeSnap, paymentSnap] = await Promise.all([
            tx.get(found.ref),
            tx.get(attendeeRef),
            tx.get(paymentRef),
        ]);
        const status = bookingSnap.data()?.status;
        if (status === 'confirmed' || status === 'completed')
            return;
        if (status === 'cancelled_by_user') {
            throw new Error('BOOKING_CANCELLED');
        }
        tx.update(found.ref, {
            status: 'confirmed',
            payment: {
                provider: 'razorpay',
                orderId,
                paymentId,
                method,
                status: 'captured',
            },
            confirmedAt: firestore_1.FieldValue.serverTimestamp(),
            ticketIds,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        for (const doc of ticketDocs)
            tx.set((0, admin_1.db)().collection('tickets').doc(doc.id), doc.data);
        for (const doc of secretDocs)
            tx.set((0, admin_1.db)().collection('ticketSecrets').doc(doc.id), doc.data);
        const existingAttendee = attendeeSnap.data();
        tx.set(attendeeRef, {
            schemaVersion: 1,
            eventId: found.data.eventId,
            uid: found.data.userId,
            ticketCount: firestore_1.FieldValue.increment(ticketIds.length),
            firstTicketAt: existingAttendee?.firstTicketAt ?? firestore_1.FieldValue.serverTimestamp(),
            radarOptIn: existingAttendee?.radarOptIn ?? false,
            incognito: user.privacy?.incognito === true,
        }, { merge: true });
        const webhookEventIds = (paymentSnap.data()?.webhookEventIds ?? []);
        tx.set(paymentRef, {
            schemaVersion: 1,
            bookingId: found.id,
            userId: found.data.userId,
            provider: 'razorpay',
            orderId,
            gatewayPaymentId: paymentId,
            method,
            amountPaise,
            status: 'captured',
            webhookEventIds: [...new Set([...webhookEventIds, `payment.captured:${paymentId}`])],
            capturedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }).catch(async (err) => {
        if (err instanceof Error && err.message === 'BOOKING_CANCELLED') {
            await autoRefundLateCapture(found.id, paymentId, amountPaise);
            return;
        }
        throw err;
    });
    await (0, inventory_1.confirmInventory)(found.data.eventId, allocations).catch((err) => {
        firebase_functions_1.logger.error('razorpay.webhook.inventory_confirm_failed', { bookingId: found.id, error: String(err) });
    });
    const promoDocId = found.data.promo?.docId;
    if (promoDocId) {
        await (0, promo_1.incrementPromoUsage)(promoDocId).catch((err) => {
            firebase_functions_1.logger.error('razorpay.webhook.promo_usage_failed', { bookingId: found.id, error: String(err) });
        });
    }
    const pricing = (found.data.pricing ?? {});
    const eventSnap = await (0, admin_1.db)().collection('events').doc(found.data.eventId).get();
    const eventPromoter = (eventSnap.data()?.promoter ?? {});
    const referral = (found.data.referral ?? null);
    await (0, finance_1.recordConfirmedBooking)({
        eventId: String(found.data.eventId),
        bookingId: found.id,
        lines: items.map((i) => ({ tierId: i.tierId, qty: i.qty, unitPaise: i.unitPaise })),
        grossPaise: Number(pricing.subtotalPaise ?? 0),
        discountPaise: Number(pricing.discountPaise ?? 0),
        platformFeePaise: Number(pricing.platformFeePaise ?? 0),
        gstOnFeePaise: Number(pricing.gstOnFeePaise ?? 0),
        feeBearer: (pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer'),
        promoterId: referral?.promoterId ?? null,
        commissionPct: eventPromoter.enabled === true ? Number(eventPromoter.commissionPct ?? 0) : 0,
    }).catch((err) => {
        firebase_functions_1.logger.error('razorpay.webhook.finance_update_failed', { bookingId: found.id, error: String(err) });
    });
    await (0, notify_1.notifyUser)(found.data.userId, 'booking_confirmed', 'Booking confirmed', `Your tickets for ${found.data.eventSnapshot?.title ?? 'your event'} are confirmed.`, { deepLink: `/ticket/${ticketIds[0] ?? ''}`, channel: 'bookings' }).catch(() => undefined);
    firebase_functions_1.logger.info('razorpay.webhook.booking_confirmed', { bookingId: found.id, ticketCount: ticketIds.length });
}
async function hasInventory(booking) {
    const allocations = (booking.reservation?.shards ?? []);
    for (const alloc of allocations) {
        const snap = await (0, admin_1.db)()
            .collection('events')
            .doc(String(booking.eventId))
            .collection('ticketTiers')
            .doc(alloc.tierId)
            .collection('shards')
            .doc(alloc.shard)
            .get();
        const data = snap.data() ?? {};
        const available = Number(data.capacity ?? 0) - Number(data.held ?? 0) - Number(data.sold ?? 0);
        if (available < alloc.qty)
            return false;
    }
    return true;
}
async function autoRefundLateCapture(bookingId, paymentId, amountPaise) {
    firebase_functions_1.logger.warn('razorpay.webhook.late_capture_autorefund', { bookingId, paymentId });
    try {
        const refund = await (0, razorpay_1.createRefund)({ paymentId, amountPaise, notes: { reason: 'late_capture' } });
        await (0, admin_1.db)()
            .collection('payments')
            .doc(paymentId)
            .set({ refundId: refund.id, refundStatus: 'processed', refundedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    catch (err) {
        firebase_functions_1.logger.error('razorpay.webhook.auto_refund_failed', { bookingId, error: String(err) });
    }
    const bookingSnap = await (0, admin_1.db)().collection('bookings').doc(bookingId).get();
    const booking = (bookingSnap.data() ?? {});
    await (0, admin_1.db)()
        .collection('bookings')
        .doc(bookingId)
        .set({ status: 'refunded', updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    await (0, inventory_1.releaseInventory)(String(booking.eventId), (booking.reservation?.shards ?? [])).catch(() => undefined);
    await (0, notify_1.notifyUser)(String(booking.userId), 'payment_refunded', 'Refund initiated', 'We could not confirm your tickets in time, so the payment has been refunded. It will reach you in 5–7 working days.', { deepLink: `/booking/${bookingId}`, channel: 'bookings' }).catch(() => undefined);
}
async function handleFailed(orderId, gatewayPaymentId) {
    const found = await findBookingByOrderId(orderId);
    if (!found)
        return;
    await (0, admin_1.db)()
        .collection('bookings')
        .doc(found.id)
        .set({
        status: 'failed',
        payment: { ...(found.data.payment ?? {}), paymentId: gatewayPaymentId, status: 'failed' },
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, notify_1.notifyUser)(found.data.userId, 'payment_failed', 'Payment failed', 'Your payment did not go through. Please try again.', { deepLink: `/booking/${found.id}`, channel: 'bookings' }).catch(() => undefined);
}
async function handleRefundProcessed(paymentId, refundId, amountPaise) {
    const paymentSnap = await (0, admin_1.db)().collection('payments').doc(paymentId).get();
    const payment = paymentSnap.data() ?? {};
    await (0, admin_1.db)()
        .collection('payments')
        .doc(paymentId)
        .set({
        refundId,
        refundStatus: 'processed',
        refundAmountPaise: amountPaise,
        refundedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const bookingId = payment.bookingId;
    if (!bookingId)
        return;
    const refunds = await (0, admin_1.db)().collection('refunds').where('gatewayPaymentId', '==', paymentId).get();
    for (const refund of refunds.docs) {
        await refund.ref.set({
            status: 'processed',
            gatewayRefundId: refundId,
            processedAt: firestore_1.Timestamp.fromDate(new Date()),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
}
async function handleRefundFailed(paymentId, refundId) {
    const paymentSnap = await (0, admin_1.db)().collection('payments').doc(paymentId).get();
    const payment = paymentSnap.data() ?? {};
    await (0, admin_1.db)()
        .collection('payments')
        .doc(paymentId)
        .set({ refundId, refundStatus: 'failed' }, { merge: true });
    const bookingId = payment.bookingId;
    if (!bookingId)
        return;
    const refunds = await (0, admin_1.db)().collection('refunds').where('gatewayPaymentId', '==', paymentId).get();
    for (const refund of refunds.docs) {
        await refund.ref.set({ status: 'failed', updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
}
//# sourceMappingURL=webhooks.js.map