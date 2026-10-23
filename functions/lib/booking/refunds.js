"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.organizerRejectRefund = exports.organizerApproveRefund = exports.requestRefund = void 0;
exports.processRefund = processRefund;
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const ids_1 = require("../shared/ids");
const razorpay_1 = require("../shared/razorpay");
const notify_1 = require("../shared/notify");
const config_1 = require("../shared/config");
const money_1 = require("../shared/money");
const time_1 = require("../shared/time");
const finance_1 = require("../settlement/finance");
const DEFAULT_POLICY = {
    windowDays: 7,
    type: 'full',
    cutoffHoursBefore: 24,
    processingFeePaise: 0,
};
const requestRefundSchema = zod_1.z.object({
    bookingId: zod_1.z.string().min(1).max(64),
    ticketIds: zod_1.z.array(zod_1.z.string().min(1).max(64)).max(50).optional(),
    reason: zod_1.z.string().trim().max(500).optional(),
});
exports.requestRefund = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = requestRefundSchema.parse(req.data);
    const bookingRef = (0, admin_1.db)().collection('bookings').doc(input.bookingId);
    const snap = await bookingRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Booking not found.');
    const booking = snap.data();
    if (booking.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This booking belongs to another account.');
    if (booking.status !== 'confirmed' && booking.status !== 'completed' && booking.status !== 'refunded_partial') {
        (0, errors_1.fail)('CONFLICT', 'This booking is not eligible for a refund.');
    }
    if (!booking.payment?.paymentId) {
        (0, errors_1.fail)('CONFLICT', 'We could not locate the payment for this booking.');
    }
    const eventSnap = await (0, admin_1.db)().collection('events').doc(booking.eventId).get();
    const event = eventSnap.data() ?? {};
    const policy = { ...DEFAULT_POLICY, ...(event.refundPolicy ?? {}) };
    if (policy.type === 'none') {
        (0, errors_1.fail)('CONFLICT', 'This event does not allow refunds.');
    }
    const startAt = booking.eventSnapshot?.startAt?.toDate?.() ?? null;
    const now = new Date();
    if (startAt) {
        const hoursToStart = (0, time_1.hoursBetween)(now, startAt);
        if (hoursToStart < policy.cutoffHoursBefore) {
            (0, errors_1.fail)('CONFLICT', `Refunds close ${policy.cutoffHoursBefore} hours before the event starts.`);
        }
        if (policy.windowDays > 0 && hoursToStart > policy.windowDays * 24) {
            (0, errors_1.fail)('CONFLICT', `The ${policy.windowDays}-day refund window for this event has closed.`);
        }
    }
    const ticketsSnap = await (0, admin_1.db)().collection('tickets').where('bookingId', '==', booking.id).get();
    let tickets = ticketsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    if (input.ticketIds && input.ticketIds.length > 0) {
        const wanted = new Set(input.ticketIds);
        tickets = tickets.filter((t) => wanted.has(t.id));
        if (tickets.length === 0)
            (0, errors_1.fail)('NOT_FOUND', 'No matching tickets found on this booking.');
    }
    const checkedIn = tickets.filter((t) => t.status === 'checked_in');
    const refundable = tickets.filter((t) => t.status === 'valid');
    if (refundable.length === 0) {
        (0, errors_1.fail)('TICKET_CHECKED_IN', 'These tickets have already been used at the gate.');
    }
    const ticketAmountPaise = refundable.reduce((sum, t) => {
        const item = booking.items.find((i) => i.tierId === t.tierId);
        return sum + (item?.unitPaise ?? 0);
    }, 0);
    const feesConfig = await (0, config_1.getFeesConfig)();
    const feeRefundPaise = feesConfig.refundPlatformFee
        ? booking.pricing.platformFeePaise + booking.pricing.gstOnFeePaise
        : 0;
    const grossRefundPaise = (0, money_1.min0)(ticketAmountPaise + feeRefundPaise);
    const processingFeePaise = policy.type === 'pro-rata' ? policy.processingFeePaise : 0;
    const refundAmountPaise = (0, money_1.min0)(grossRefundPaise - processingFeePaise);
    if (refundAmountPaise <= 0)
        (0, errors_1.fail)('CONFLICT', 'The refundable amount is zero.');
    const autoApprove = policy.type === 'full' && policy.cutoffHoursBefore >= 24;
    const refundId = (0, ids_1.newId)('rf');
    const refundRef = (0, admin_1.db)().collection('refunds').doc(refundId);
    await refundRef.set({
        schemaVersion: 1,
        bookingId: booking.id,
        userId: booking.userId,
        eventId: booking.eventId,
        organizerId: booking.organizerId,
        ticketIds: refundable.map((t) => t.id),
        excludedTicketIds: checkedIn.map((t) => t.id),
        amountPaise: refundAmountPaise,
        processingFeePaise,
        feeRefundPaise,
        currency: 'INR',
        reason: input.reason ?? null,
        status: autoApprove ? 'approved' : 'requested',
        gatewayPaymentId: booking.payment.paymentId ?? null,
        gatewayRefundId: null,
        autoApproved: autoApprove,
        requestedAt: firestore_1.FieldValue.serverTimestamp(),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    if (autoApprove) {
        await processRefund(refundId);
    }
    else {
        await (0, notify_1.notifyUser)(booking.organizerId, 'refund_requested', 'Refund requested', `${booking.refCode} has a refund request waiting for review.`, { deepLink: `/organizer/refunds/${refundId}`, channel: 'bookings' }).catch(() => undefined);
    }
    const latest = await refundRef.get();
    return { refundId, status: latest.data()?.status, amountPaise: refundAmountPaise };
});
async function processRefund(refundId) {
    const refundRef = (0, admin_1.db)().collection('refunds').doc(refundId);
    const snap = await refundRef.get();
    if (!snap.exists)
        throw new Error('REFUND_NOT_FOUND');
    const refund = snap.data();
    if (refund.status === 'processed' || refund.status === 'submitted')
        return;
    if (refund.status === 'requested')
        throw new Error('REFUND_NOT_APPROVED');
    const gatewayPaymentId = refund.gatewayPaymentId;
    if (!gatewayPaymentId)
        throw new Error('REFUND_MISSING_PAYMENT');
    try {
        const created = await (0, razorpay_1.createRefund)({
            paymentId: gatewayPaymentId,
            amountPaise: Number(refund.amountPaise ?? 0),
            notes: { refundId, bookingId: refund.bookingId, reason: 'customer_request' },
        });
        await refundRef.set({
            status: 'submitted',
            gatewayRefundId: created.id,
            submittedAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (err) {
        firebase_functions_1.logger.error('refund.gateway_failed', { refundId, error: String(err) });
        await refundRef.set({ status: 'failed', failureReason: String(err), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        throw err;
    }
    const bookingRef = (0, admin_1.db)().collection('bookings').doc(refund.bookingId);
    const ticketIds = (refund.ticketIds ?? []);
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const bookingSnap = await tx.get(bookingRef);
        const booking = bookingSnap.data();
        if (!booking)
            return;
        const alreadyRefunded = Number(booking.refundedPaise ?? 0);
        const remaining = booking.pricing.totalPaise - alreadyRefunded - Number(refund.amountPaise ?? 0);
        const fullyRefunded = remaining <= 0;
        tx.update(bookingRef, {
            status: fullyRefunded ? 'refunded' : 'refunded_partial',
            refundedPaise: alreadyRefunded + Number(refund.amountPaise ?? 0),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    for (const ticketId of ticketIds) {
        await (0, admin_1.db)()
            .collection('tickets')
            .doc(ticketId)
            .set({ status: 'void', voidedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    await (0, finance_1.recordRefund)({
        eventId: String(refund.eventId),
        amountPaise: Number(refund.amountPaise ?? 0),
    }).catch(() => undefined);
    await (0, notify_1.notifyUser)(refund.userId, 'refund_processed', 'Refund initiated', 'Your refund has been initiated and should reach your account in 5–7 working days.', { deepLink: `/booking/${refund.bookingId}`, channel: 'bookings' }).catch(() => undefined);
}
exports.organizerApproveRefund = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ refundId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const refundRef = (0, admin_1.db)().collection('refunds').doc(input.refundId);
    const snap = await refundRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Refund request not found.');
    const refund = snap.data();
    if (refund.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This refund belongs to another organiser.');
    if (refund.status !== 'requested')
        (0, errors_1.fail)('CONFLICT', 'This refund request is not pending review.');
    await refundRef.set({ status: 'approved', approvedBy: ctx.uid, approvedAt: firestore_1.FieldValue.serverTimestamp(), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    await processRefund(input.refundId);
    return { ok: true, refundId: input.refundId };
});
exports.organizerRejectRefund = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ refundId: zod_1.z.string().min(1).max(64), reason: zod_1.z.string().trim().max(500).optional() }).parse(req.data);
    const refundRef = (0, admin_1.db)().collection('refunds').doc(input.refundId);
    const snap = await refundRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Refund request not found.');
    const refund = snap.data();
    if (refund.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This refund belongs to another organiser.');
    if (refund.status !== 'requested')
        (0, errors_1.fail)('CONFLICT', 'This refund request is not pending review.');
    await refundRef.set({
        status: 'rejected',
        rejectedBy: ctx.uid,
        rejectionReason: input.reason ?? null,
        decidedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, notify_1.notifyUser)(refund.userId, 'refund_rejected', 'Refund request declined', 'Your refund request was declined. Contact support if you need help.', { deepLink: `/booking/${refund.bookingId}`, channel: 'bookings' }).catch(() => undefined);
    return { ok: true, refundId: input.refundId };
});
//# sourceMappingURL=refunds.js.map