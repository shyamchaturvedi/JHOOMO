"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestPromoterPayout = exports.becomePromoter = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const config_1 = require("../shared/config");
const tds_1 = require("../shared/tds");
const crypto_1 = require("../shared/crypto");
const claims_1 = require("../shared/claims");
const time_1 = require("../shared/time");
const notify_1 = require("../shared/notify");
const schemas_1 = require("../shared/schemas");
const PROMOTER_TERMS_VERSION = '1.0';
const becomePromoterSchema = zod_1.z.object({
    displayName: zod_1.z.string().trim().min(2).max(60),
    pan: schemas_1.panSchema,
    code: zod_1.z
        .string()
        .trim()
        .toUpperCase()
        .min(3)
        .max(12)
        .regex(/^[A-Z0-9_-]+$/, 'Code may contain letters, numbers, _ and -'),
    termsAccepted: zod_1.z.literal(true),
});
exports.becomePromoter = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = becomePromoterSchema.parse(req.data);
    const codeRef = (0, admin_1.db)().collection('referralCodes').doc(input.code);
    const existing = await codeRef.get();
    if (existing.exists)
        (0, errors_1.fail)('CONFLICT', 'That referral code is already taken.');
    const userRef = (0, admin_1.db)().collection('users').doc(ctx.uid);
    const userSnap = await userRef.get();
    const user = userSnap.data() ?? {};
    await (0, admin_1.db)()
        .collection('promoterPrivate')
        .doc(ctx.uid)
        .set({
        schemaVersion: 1,
        panHash: (0, crypto_1.sha256Hex)(input.pan),
        panLast4: input.pan.slice(-4),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, admin_1.db)()
        .collection('promoters')
        .doc(ctx.uid)
        .set({
        schemaVersion: 1,
        displayName: input.displayName,
        code: input.code,
        status: 'active',
        termsVersion: PROMOTER_TERMS_VERSION,
        termsAcceptedAt: firestore_1.FieldValue.serverTimestamp(),
        panLast4: input.pan.slice(-4),
        bank: null,
        totals: { bookings: 0, pendingPaise: 0, approvedPaise: 0, paidPaise: 0 },
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await codeRef.set({ promoterId: ctx.uid, active: true, createdAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    await userRef.set({
        schemaVersion: 1,
        roles: { ...(user.roles ?? {}), promoter: true },
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, claims_1.mergeCustomClaims)(ctx.uid, { promoter: true });
    return { ok: true, code: input.code, termsVersion: PROMOTER_TERMS_VERSION };
});
const requestPayoutSchema = zod_1.z.object({
    bankAccountNumber: zod_1.z.string().regex(/^\d{9,18}$/),
    ifsc: zod_1.z.string().regex(/^[A-Z]{4}0[A-Z0-9]{6}$/),
    bankName: zod_1.z.string().trim().min(2).max(80),
});
exports.requestPromoterPayout = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = requestPayoutSchema.parse(req.data);
    const promoterRef = (0, admin_1.db)().collection('promoters').doc(ctx.uid);
    const promoterSnap = await promoterRef.get();
    if (!promoterSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Promoter profile not found.');
    const promoter = promoterSnap.data();
    if (promoter.status !== 'active')
        (0, errors_1.fail)('FORBIDDEN', 'Your promoter account is not active.');
    const fees = await (0, config_1.getFeesConfig)();
    const approved = await (0, admin_1.db)()
        .collection('commissions')
        .where('promoterId', '==', ctx.uid)
        .where('status', '==', 'approved')
        .get();
    const availablePaise = approved.docs.reduce((sum, d) => sum + Number(d.data().amountPaise ?? 0), 0);
    if (availablePaise < fees.minPayoutPaise) {
        (0, errors_1.fail)('INVALID_INPUT', `Minimum payout is ₹${(fees.minPayoutPaise / 100).toFixed(2)}. Approved commission is ₹${(availablePaise / 100).toFixed(2)}.`);
    }
    const privateSnap = await (0, admin_1.db)().collection('promoterPrivate').doc(ctx.uid).get();
    const panPresent = Boolean(privateSnap.data()?.panHash);
    const fy = (0, time_1.indianFinancialYear)(new Date());
    const fyPaid = await (0, admin_1.db)()
        .collection('promoterPayouts')
        .where('promoterId', '==', ctx.uid)
        .where('financialYear', '==', fy.key)
        .get();
    const alreadyPaid = fyPaid.docs
        .filter((d) => d.data().status !== 'failed')
        .reduce((sum, d) => sum + Number(d.data().tdsPaise ?? 0), 0);
    const tds = (0, tds_1.computeTds)({
        amountPaise: availablePaise,
        panPresent,
        fyAlreadyPaidPaise: alreadyPaid,
        tdsPct: fees.tdsPct,
        thresholdPaise: fees.tdsThresholdPaise,
        rateWithoutPanPct: fees.tdsRateWithoutPanPct,
    });
    const payoutRef = (0, admin_1.db)().collection('promoterPayouts').doc();
    await payoutRef.set({
        schemaVersion: 1,
        promoterId: ctx.uid,
        amountPaise: availablePaise,
        tdsPaise: tds.tdsPaise,
        netPaise: availablePaise - tds.tdsPaise,
        tdsRatePct: tds.ratePct,
        tdsThresholdPaise: fees.tdsThresholdPaise,
        financialYear: fy.key,
        bank: {
            accountLast4: input.bankAccountNumber.slice(-4),
            ifsc: input.ifsc,
            bankName: input.bankName,
            verified: false,
        },
        status: 'requested',
        requestedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await promoterRef.set({
        schemaVersion: 1,
        bank: {
            bankName: input.bankName,
            last4: input.bankAccountNumber.slice(-4),
            verified: false,
            changedAt: firestore_1.FieldValue.serverTimestamp(),
        },
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, notify_1.notifyUser)(ctx.uid, 'promoter_payout_requested', 'Payout requested', `Payout of ₹${(availablePaise / 100).toFixed(2)} requested. TDS of ₹${(tds.tdsPaise / 100).toFixed(2)} will be deducted as applicable.`, { deepLink: '/promoter', channel: 'bookings' });
    return {
        ok: true,
        payoutId: payoutRef.id,
        amountPaise: availablePaise,
        tdsPaise: tds.tdsPaise,
        netPaise: availablePaise - tds.tdsPaise,
        tdsRatePct: tds.ratePct,
        tdsReason: tds.reason,
        panMissing: tds.panMissing,
        panMasked: privateSnap.data()?.panMasked ?? null,
    };
});
//# sourceMappingURL=promoter.js.map