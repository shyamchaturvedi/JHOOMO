"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recordConfirmedBooking = recordConfirmedBooking;
exports.recordRefund = recordRefund;
exports.recordDailyLedger = recordDailyLedger;
exports.markEventCompleted = markEventCompleted;
const firestore_1 = require("firebase-admin/firestore");
const admin_1 = require("../shared/admin");
const settlement_1 = require("../shared/settlement");
/**
 * Applies a confirmed booking to the event finance ledger.
 * Called from the Razorpay capture path so ticket counts, gross, discounts,
 * fees and promoter commission always move together.
 */
async function recordConfirmedBooking(params) {
    const financeRef = (0, admin_1.db)().collection('eventFinance').doc(params.eventId);
    let commissionPaise = 0;
    if (params.promoterId && (params.commissionPct ?? 0) > 0) {
        const taxableBase = params.grossPaise - params.discountPaise;
        const commission = (0, settlement_1.computeCommission)(taxableBase, params.commissionPct);
        commissionPaise = commission.amountPaise;
        await (0, admin_1.db)()
            .collection('commissions')
            .add({
            schemaVersion: 1,
            promoterId: params.promoterId,
            bookingId: params.bookingId,
            eventId: params.eventId,
            basePaise: commission.basePaise,
            pct: commission.pct,
            amountPaise: commission.amountPaise,
            status: 'pending',
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        })
            .catch(() => undefined);
    }
    const byTier = {};
    for (const line of params.lines) {
        const current = byTier[line.tierId] ?? { sold: 0, grossPaise: 0 };
        current.sold += line.qty;
        current.grossPaise += line.unitPaise * line.qty;
        byTier[line.tierId] = current;
    }
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const snap = await tx.get(financeRef);
        const data = snap.data() ?? {};
        const existingByTier = (data.byTier ?? {});
        const merged = { ...existingByTier };
        for (const [tierId, value] of Object.entries(byTier)) {
            const prev = merged[tierId] ?? { sold: 0, grossPaise: 0 };
            merged[tierId] = { sold: prev.sold + value.sold, grossPaise: prev.grossPaise + value.grossPaise };
        }
        tx.set(financeRef, {
            schemaVersion: 1,
            eventId: params.eventId,
            ticketsSold: Number(data.ticketsSold ?? 0) + params.lines.reduce((s, l) => s + l.qty, 0),
            grossPaise: Number(data.grossPaise ?? 0) + params.grossPaise,
            discountPaise: Number(data.discountPaise ?? 0) + params.discountPaise,
            refundsPaise: Number(data.refundsPaise ?? 0),
            platformFeePaise: Number(data.platformFeePaise ?? 0) + params.platformFeePaise,
            gstOnFeePaise: Number(data.gstOnFeePaise ?? 0) + params.gstOnFeePaise,
            promoterCommissionPaise: Number(data.promoterCommissionPaise ?? 0) + commissionPaise,
            netPayablePaise: Number(data.netPayablePaise ?? 0) +
                params.grossPaise -
                params.discountPaise -
                params.platformFeePaise -
                params.gstOnFeePaise -
                commissionPaise,
            byTier: merged,
            feeBearer: params.feeBearer,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    return { commissionPaise };
}
/** Applies a settled refund to the event finance ledger. */
async function recordRefund(params) {
    const financeRef = (0, admin_1.db)().collection('eventFinance').doc(params.eventId);
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const snap = await tx.get(financeRef);
        const data = snap.data() ?? {};
        tx.set(financeRef, {
            refundsPaise: Number(data.refundsPaise ?? 0) + params.amountPaise,
            netPayablePaise: Math.max(0, Number(data.netPayablePaise ?? 0) - params.amountPaise),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
}
/** Daily ledger row used by the organiser sales report (PRD §11.2). */
async function recordDailyLedger(params) {
    const ref = (0, admin_1.db)().collection('eventFinance').doc(params.eventId).collection('daily').doc(params.dateKey);
    await ref.set({
        schemaVersion: 1,
        dateKey: params.dateKey,
        tickets: firestore_1.FieldValue.increment(params.tickets),
        grossPaise: firestore_1.FieldValue.increment(params.grossPaise),
        refundsPaise: firestore_1.FieldValue.increment(params.refundsPaise),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function markEventCompleted(eventId) {
    const ref = (0, admin_1.db)().collection('events').doc(eventId);
    await ref.set({ status: 'completed', updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
}
//# sourceMappingURL=finance.js.map