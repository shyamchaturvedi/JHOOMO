"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadPromo = loadPromo;
exports.evaluatePromo = evaluatePromo;
exports.incrementPromoUsage = incrementPromoUsage;
const firestore_1 = require("firebase-admin/firestore");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const money_1 = require("../shared/money");
async function loadPromo(code, eventId) {
    const normalised = code.trim().toUpperCase();
    const eventScoped = await (0, admin_1.db)().collection('promoCodes').doc(`${eventId}_${normalised}`).get();
    if (eventScoped.exists) {
        return { doc: eventScoped.data(), docId: eventScoped.id };
    }
    const platform = await (0, admin_1.db)().collection('promoCodes').doc(`PLATFORM_${normalised}`).get();
    if (platform.exists) {
        return { doc: platform.data(), docId: platform.id };
    }
    return null;
}
async function evaluatePromo(params) {
    const now = params.now ?? new Date();
    const loaded = await loadPromo(params.code, params.eventId);
    if (!loaded)
        throw new errors_1.MiloError('INVALID_INPUT', 'That promo code is not valid.', { reason: 'NOT_FOUND' });
    const promo = loaded.doc;
    if (!promo.active)
        throw new errors_1.MiloError('INVALID_INPUT', 'That promo code is not active.', { reason: 'INACTIVE' });
    if (promo.validFrom && promo.validFrom.toMillis() > now.getTime()) {
        throw new errors_1.MiloError('INVALID_INPUT', 'That promo code is not active yet.', { reason: 'NOT_STARTED' });
    }
    if (promo.validTo && promo.validTo.toMillis() < now.getTime()) {
        throw new errors_1.MiloError('INVALID_INPUT', 'That promo code has expired.', { reason: 'EXPIRED' });
    }
    if (promo.maxUses > 0 && Number(promo.usedCount ?? 0) >= promo.maxUses) {
        throw new errors_1.MiloError('INVALID_INPUT', 'That promo code has reached its usage limit.', { reason: 'MAX_USES' });
    }
    if (promo.minOrderPaise && params.subtotalPaise < promo.minOrderPaise) {
        throw new errors_1.MiloError('INVALID_INPUT', 'Your order does not meet the minimum value for this code.', {
            reason: 'MIN_ORDER',
        });
    }
    if (promo.tierIds && promo.tierIds.length > 0) {
        const applicable = params.lines.some((l) => promo.tierIds.includes(l.tierId));
        if (!applicable) {
            throw new errors_1.MiloError('INVALID_INPUT', 'That promo code does not apply to the selected tickets.', {
                reason: 'TIER_MISMATCH',
            });
        }
    }
    const userUsage = await (0, admin_1.db)()
        .collection('bookings')
        .where('userId', '==', params.userId)
        .where('promo.code', '==', promo.code)
        .where('status', 'in', ['confirmed', 'pending_payment', 'completed', 'refunded_partial'])
        .get();
    const nowMs = now.getTime();
    const usedCount = userUsage.docs.filter((d) => {
        const data = d.data();
        if (data.status === 'pending_payment') {
            // Only an abandoned hold should not burn the user's promo quota.
            const expiresAt = data.reservationExpiresAt;
            return !expiresAt || expiresAt.toMillis() > nowMs;
        }
        return data.status !== 'cancelled_by_user';
    }).length;
    if (promo.perUserLimit > 0 && usedCount >= promo.perUserLimit) {
        throw new errors_1.MiloError('INVALID_INPUT', 'You have already used this promo code.', { reason: 'PER_USER_LIMIT' });
    }
    const discountPaise = promo.type === 'percent'
        ? (0, money_1.applyBps)(params.subtotalPaise, (0, money_1.pctToBps)(promo.value))
        : (0, money_1.min0)(promo.value);
    return {
        doc: promo,
        docId: loaded.docId,
        discountPaise: (0, money_1.min0)(discountPaise),
        fundedBy: promo.fundedBy,
    };
}
async function incrementPromoUsage(docId) {
    await (0, admin_1.db)()
        .collection('promoCodes')
        .doc(docId)
        .set({ usedCount: firestore_1.FieldValue.increment(1), updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
}
//# sourceMappingURL=promo.js.map