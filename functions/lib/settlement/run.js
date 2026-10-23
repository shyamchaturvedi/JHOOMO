"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSettlements = exports.approveSettlement = exports.settlementRun = void 0;
exports.releasePromoterCommissions = releasePromoterCommissions;
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const zod_1 = require("zod");
const admin_1 = require("../shared/admin");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const errors_1 = require("../shared/errors");
const razorpay_1 = require("../shared/razorpay");
const settlement_1 = require("../shared/settlement");
const config_1 = require("../shared/config");
const time_1 = require("../shared/time");
const notify_1 = require("../shared/notify");
const audit_1 = require("../shared/audit");
const callable_2 = require("../shared/callable");
const ids_1 = require("../shared/ids");
/**
 * Daily settlement run — 11:00 IST on the day after the event's last day
 * (PRD §8.3 / §12.3). Funds are released to the organiser through Razorpay
 * Route held transfers; Milo never custodies the money itself.
 */
exports.settlementRun = (0, scheduler_1.onSchedule)({ schedule: 'every day 11:00', timeZone: 'Asia/Kolkata', region: 'asia-south1', maxInstances: 1 }, async () => {
    const now = new Date();
    const events = await (0, admin_1.db)()
        .collection('events')
        .where('status', 'in', ['live', 'sold_out', 'completed', 'paused'])
        .get();
    let processed = 0;
    for (const doc of events.docs) {
        const event = doc.data();
        const endAt = event.schedule?.endAt?.toDate?.();
        if (!endAt)
            continue;
        const scheduledFor = (0, time_1.settlementScheduledFor)(endAt);
        if (scheduledFor.getTime() > now.getTime())
            continue;
        const existing = await (0, admin_1.db)().collection('settlements').where('eventId', '==', doc.id).limit(1).get();
        if (!existing.empty)
            continue;
        try {
            await createSettlement(doc.id, event, now);
            processed += 1;
        }
        catch (err) {
            firebase_functions_1.logger.error('settlementRun.failed', { eventId: doc.id, error: String(err) });
        }
    }
    firebase_functions_1.logger.info('settlementRun.complete', { processed, scanned: events.size });
});
async function createSettlement(eventId, event, now) {
    const organizerSnap = await (0, admin_1.db)().collection('organizers').doc(event.organizerId).get();
    const organizer = organizerSnap.data() ?? {};
    const bookingsSnap = await (0, admin_1.db)()
        .collection('bookings')
        .where('eventId', '==', eventId)
        .where('status', 'in', ['confirmed', 'completed', 'refunded_partial', 'refunded'])
        .get();
    let grossPaise = 0;
    let discountPaise = 0;
    let platformFeePaise = 0;
    let gstOnFeePaise = 0;
    let promoterCommissionPaise = 0;
    let refundsPaise = 0;
    let organizerFundedDiscountPaise = 0;
    let feeBearer = 'organizer';
    for (const doc of bookingsSnap.docs) {
        const booking = doc.data();
        const pricing = (booking.pricing ?? {});
        grossPaise += Number(pricing.subtotalPaise ?? 0);
        discountPaise += Number(pricing.discountPaise ?? 0);
        platformFeePaise += Number(pricing.platformFeePaise ?? 0);
        gstOnFeePaise += Number(pricing.gstOnFeePaise ?? 0);
        refundsPaise += Number(booking.refundedPaise ?? 0);
        feeBearer = pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer';
        const promo = booking.promo;
        if (promo?.fundedBy === 'organizer') {
            organizerFundedDiscountPaise += Number(pricing.discountPaise ?? 0);
        }
    }
    const commissionsSnap = await (0, admin_1.db)()
        .collection('commissions')
        .where('eventId', '==', eventId)
        .where('status', 'in', ['pending', 'approved'])
        .get();
    for (const doc of commissionsSnap.docs) {
        promoterCommissionPaise += Number(doc.data().amountPaise ?? 0);
    }
    const settlement = (0, settlement_1.computeSettlement)({
        grossPaise,
        refundsPaise,
        platformFeePaise,
        gstOnFeePaise,
        promoterCommissionPaise,
        organizerFundedDiscountPaise,
        feeBearer,
    });
    const limits = await (0, config_1.getLimitsConfig)();
    const bankChangedAt = organizer.bank?.changedAt?.toDate?.() ?? null;
    const fraudFlags = await (0, admin_1.db)().collection('fraudFlags').where('eventId', '==', eventId).get();
    const disputes = await (0, admin_1.db)()
        .collection('supportTickets')
        .where('eventId', '==', eventId)
        .where('status', 'in', ['open', 'in_progress'])
        .get();
    const holdResult = (0, settlement_1.evaluateSettlementHolds)({
        kycStatus: String(organizer.kycStatus ?? 'none'),
        hasOpenDispute: !disputes.empty,
        hasFraudFlag: !fraudFlags.empty,
        bankChangedAt,
        now,
        underInvestigation: String(event.status) === 'paused',
        netPaise: settlement.netPaise,
        fourEyesThresholdPaise: limits.fourEyesThresholdPaise,
        approvals: [],
    });
    const settlementId = (0, ids_1.newId)('st');
    const settlementRef = (0, admin_1.db)().collection('settlements').doc(settlementId);
    const endAt = event.schedule.endAt.toDate();
    const scheduledFor = (0, time_1.settlementScheduledFor)(endAt);
    await settlementRef.set({
        schemaVersion: 1,
        organizerId: event.organizerId,
        eventId,
        status: holdResult.eligible ? 'scheduled' : 'on_hold',
        holdReasons: holdResult.holdReasons,
        grossPaise: settlement.grossPaise,
        refundsPaise: settlement.refundsPaise,
        platformFeePaise: settlement.platformFeePaise,
        gstOnFeePaise: settlement.gstOnFeePaise,
        promoterCommissionPaise: settlement.promoterCommissionPaise,
        netPaise: settlement.netPaise,
        organizerFundedDiscountPaise,
        feeBearer,
        bankMasked: String(organizer.bank?.last4 ?? ''),
        approvals: [],
        scheduledFor: firestore_1.Timestamp.fromDate(scheduledFor),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await releasePromoterCommissions(eventId);
    if (holdResult.eligible) {
        await disburseSettlement(settlementId, eventId, event.organizerId);
    }
    else {
        await (0, notify_1.notifyUser)(event.organizerId, 'settlement_update', 'Settlement on hold', `The payout for "${event.title}" is on hold pending review. Our team will contact you shortly.`, { deepLink: '/organizer/settlements', channel: 'bookings' }).catch(() => undefined);
    }
    return settlementId;
}
async function disburseSettlement(settlementId, eventId, organizerId) {
    const settlementRef = (0, admin_1.db)().collection('settlements').doc(settlementId);
    const snap = await settlementRef.get();
    const settlement = snap.data() ?? {};
    const netPaise = Number(settlement.netPaise ?? 0);
    if (netPaise <= 0) {
        await settlementRef.set({ status: 'paid', paidAt: firestore_1.FieldValue.serverTimestamp(), netPaise: 0 }, { merge: true });
        return;
    }
    const privateSnap = await (0, admin_1.db)().collection('organizerPrivate').doc(organizerId).get();
    const razorpayAccount = privateSnap.data()?.razorpayAccountId;
    if (!razorpayAccount) {
        await settlementRef.set({
            status: 'on_hold',
            holdReasons: [...(settlement.holdReasons ?? []), 'BANK_ACCOUNT_NOT_ONBOARDED'],
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return;
    }
    await settlementRef.set({ status: 'processing', updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    try {
        const transfer = await (0, razorpay_1.createTransfer)({
            account: razorpayAccount,
            amountPaise: netPaise,
            referenceId: settlementId,
            notes: { eventId, settlementId },
        });
        await settlementRef.set({
            gatewayTransferId: transfer.id,
            transferStatus: transfer.status,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (err) {
        firebase_functions_1.logger.error('settlement.transfer_failed', { settlementId, error: String(err) });
        await settlementRef.set({ status: 'failed', failureReason: String(err), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
}
/** Promoter commissions become payable once the event and its refund window close. */
async function releasePromoterCommissions(eventId) {
    const commissions = await (0, admin_1.db)()
        .collection('commissions')
        .where('eventId', '==', eventId)
        .where('status', '==', 'pending')
        .get();
    for (const doc of commissions.docs) {
        await doc.ref.set({ status: 'approved', approvedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        await (0, notify_1.notifyUser)(String(doc.data().promoterId), 'commission_update', 'Commission approved', 'Your commission for a recent event is now available for payout.', { deepLink: '/promoter', channel: 'bookings' }).catch(() => undefined);
    }
}
exports.approveSettlement = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L3');
    const input = zod_1.z.object({ settlementId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const settlementRef = (0, admin_1.db)().collection('settlements').doc(input.settlementId);
    const snap = await settlementRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Settlement not found.');
    const settlement = snap.data();
    if (settlement.status !== 'on_hold')
        (0, errors_1.fail)('CONFLICT', 'This settlement is not on hold.');
    const approvals = (settlement.approvals ?? []);
    if (approvals.some((a) => a.by === req.auth?.uid)) {
        (0, errors_1.fail)('FORBIDDEN', 'You have already approved this settlement.');
    }
    approvals.push({ by: String(req.auth?.uid), at: firestore_1.Timestamp.now() });
    const holdReasons = (settlement.holdReasons ?? []).filter((r) => r !== 'FOUR_EYES_REQUIRED');
    const onlyFourEyes = holdReasons.length === 0;
    await settlementRef.set({
        approvals,
        holdReasons,
        status: onlyFourEyes && approvals.length >= 2 ? 'scheduled' : 'on_hold',
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    if (onlyFourEyes && approvals.length >= 2) {
        await disburseSettlement(input.settlementId, String(settlement.eventId), String(settlement.organizerId));
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: String(req.auth?.uid),
        actorLevel: 'L3',
        action: 'settlement.approved',
        targetType: 'settlement',
        targetId: input.settlementId,
        after: { approvals: approvals.length },
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true, approvals: approvals.length, status: onlyFourEyes && approvals.length >= 2 ? 'scheduled' : 'on_hold' };
});
exports.listSettlements = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({ status: zod_1.z.string().max(20).optional(), limit: zod_1.z.number().int().min(1).max(50).default(20) })
        .parse(req.data);
    let query = (0, admin_1.db)().collection('settlements').where('organizerId', '==', ctx.uid);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.orderBy('scheduledFor', 'desc').limit(input.limit).get();
    return {
        settlements: snap.docs.map((d) => {
            const data = d.data();
            return {
                settlementId: d.id,
                eventId: data.eventId,
                status: data.status,
                holdReasons: data.holdReasons ?? [],
                grossPaise: data.grossPaise,
                refundsPaise: data.refundsPaise,
                platformFeePaise: data.platformFeePaise,
                gstOnFeePaise: data.gstOnFeePaise,
                promoterCommissionPaise: data.promoterCommissionPaise,
                netPaise: data.netPaise,
                bankMasked: data.bankMasked,
                utr: data.utr ?? null,
                scheduledFor: data.scheduledFor,
                paidAt: data.paidAt ?? null,
                approvals: data.approvals ?? [],
            };
        }),
    };
});
//# sourceMappingURL=run.js.map