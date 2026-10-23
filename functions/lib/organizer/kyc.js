"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getKycStatus = exports.submitKyc = exports.verifyEmailCodeCallable = exports.sendEmailCodeCallable = exports.verifyBankCallable = exports.verifyPanCallable = exports.saveKycDraft = exports.AGREEMENT_VERSION = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const schemas_1 = require("../shared/schemas");
const crypto_1 = require("../shared/crypto");
const claims_1 = require("../shared/claims");
const emailcode_1 = require("../shared/emailcode");
const envelope_1 = require("../shared/envelope");
const vendors_1 = require("../shared/vendors");
const notify_1 = require("../shared/notify");
const ratelimit_1 = require("../shared/ratelimit");
const audit_1 = require("../shared/audit");
exports.AGREEMENT_VERSION = '1.0';
const NAME_MATCH_THRESHOLD = 80;
const ENTITY_BY_PAN_CHAR = {
    P: 'individual',
    C: 'company',
    F: 'firm',
    T: 'trust',
    A: 'aop',
    H: 'huf',
    L: 'local_authority',
    J: 'artificial_juridical_person',
    G: 'government',
};
const step1Schema = zod_1.z.object({
    pan: schemas_1.panSchema.transform((v) => v.toUpperCase()),
    legalName: zod_1.z.string().trim().min(2).max(120),
    address: zod_1.z.object({
        line1: zod_1.z.string().trim().min(2).max(160),
        line2: zod_1.z.string().trim().max(160).optional(),
        city: zod_1.z.string().trim().min(2).max(80),
        state: zod_1.z.string().trim().min(2).max(80),
        pincode: schemas_1.pincodeSchema,
    }),
    aadhaarLinked: zod_1.z.enum(['yes', 'no', 'na']),
    gstin: zod_1.z
        .string()
        .trim()
        .toUpperCase()
        .regex(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]{1}$/, 'Invalid GSTIN')
        .optional(),
});
const step2Schema = zod_1.z.object({
    pocName: zod_1.z.string().trim().min(2).max(60),
    businessEmail: zod_1.z.string().trim().toLowerCase().email().max(160),
    phone: schemas_1.phoneSchema,
});
const step3Schema = zod_1.z.object({
    bankAccountNumber: zod_1.z.string().trim().regex(/^[0-9]{9,18}$/, 'Enter a valid account number'),
    confirmAccountNumber: zod_1.z.string().trim().regex(/^[0-9]{9,18}$/, 'Enter a valid account number'),
    ifsc: schemas_1.ifscSchema,
    bankName: zod_1.z.string().trim().min(2).max(80),
    branch: zod_1.z.string().trim().max(80).optional(),
    agreementAccepted: zod_1.z.literal(true),
});
exports.saveKycDraft = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const raw = req.data;
    const step = Number(raw.step ?? 1);
    const organizerRef = (0, admin_1.db)().collection('organizers').doc(ctx.uid);
    const existing = (await organizerRef.get()).data() ?? {};
    const status = String(existing.kycStatus ?? 'none');
    if (status === 'submitted' || status === 'auto_verified' || status === 'approved') {
        (0, errors_1.fail)('CONFLICT', 'Your KYC has already been submitted.');
    }
    if (status === 'suspended')
        (0, errors_1.fail)('FORBIDDEN', 'Your organiser account is suspended.');
    const patch = {
        kycStatus: status === 'none' ? 'draft' : status,
        kycStep: step,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    if (step === 1 && raw.step1) {
        const data = step1Schema.parse(raw.step1);
        const entityType = ENTITY_BY_PAN_CHAR[data.pan.charAt(3)] ?? 'other';
        const panCheck = await (0, vendors_1.verifyPan)(data.pan);
        let legalName = data.legalName;
        if (panCheck.status === 'valid' && panCheck.nameOnRecord) {
            legalName = panCheck.nameOnRecord;
        }
        const score = (0, vendors_1.nameMatchScore)(legalName, data.legalName);
        patch.entityType = entityType;
        patch.legalName = legalName;
        patch.panMasked = (0, crypto_1.maskPan)(data.pan);
        patch.aadhaarLinked = panCheck.aadhaarLinked ?? data.aadhaarLinked;
        patch.addressSummary = {
            city: data.address.city,
            state: data.address.state,
            pincode: data.address.pincode,
        };
        patch.nameMatchScore = score;
        const privateRef = (0, admin_1.db)().collection('organizerPrivate').doc(ctx.uid);
        await privateRef.set({
            schemaVersion: 1,
            panEnc: (0, envelope_1.encryptField)(data.pan),
            panLast4: data.pan.slice(-4),
            addressFull: data.address,
            gstin: data.gstin ?? null,
            vendorRefs: { panRef: panCheck.status === 'valid' ? (panCheck.entityType ?? 'verified') : undefined },
            dataKeyVersion: 1,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    if (step === 2 && raw.step2) {
        const data = step2Schema.parse(raw.step2);
        patch.pocName = data.pocName;
        patch.businessEmail = data.businessEmail;
        patch.emailVerified = existing.emailVerified === true && existing.businessEmail === data.businessEmail;
    }
    if (step === 3 && raw.step3) {
        const data = step3Schema.parse(raw.step3);
        if (data.bankAccountNumber !== data.confirmAccountNumber) {
            (0, errors_1.fail)('INVALID_INPUT', 'The account numbers do not match.');
        }
        const privateRef = (0, admin_1.db)().collection('organizerPrivate').doc(ctx.uid);
        await privateRef.set({
            bankAccountEnc: (0, envelope_1.encryptField)(data.bankAccountNumber),
            ifsc: data.ifsc,
            bankName: data.bankName,
            branch: data.branch ?? null,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        patch.bank = {
            bankName: data.bankName,
            branch: data.branch ?? '',
            last4: data.bankAccountNumber.slice(-4),
            verified: false,
            changedAt: firestore_1.FieldValue.serverTimestamp(),
        };
    }
    await organizerRef.set(patch, { merge: true });
    return { ok: true, kycStep: step, kycStatus: patch.kycStatus ?? status };
});
exports.verifyPanCallable = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ pan: schemas_1.panSchema.transform((v) => v.toUpperCase()) }).parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('kyc_pan', ctx.uid), 10, 10 * 60 * 1000);
    const result = await (0, vendors_1.verifyPan)(input.pan);
    const entityType = ENTITY_BY_PAN_CHAR[input.pan.charAt(3)] ?? 'other';
    return {
        status: result.status,
        entityType,
        nameOnRecord: result.nameOnRecord ?? null,
        aadhaarLinked: result.aadhaarLinked ?? null,
        message: result.message ?? null,
    };
});
exports.verifyBankCallable = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        bankAccountNumber: zod_1.z.string().trim().regex(/^[0-9]{9,18}$/),
        ifsc: schemas_1.ifscSchema,
        name: zod_1.z.string().trim().min(2).max(120),
    })
        .parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('kyc_bank', ctx.uid), 10, 10 * 60 * 1000);
    const result = await (0, vendors_1.verifyBank)({
        accountNumber: input.bankAccountNumber,
        ifsc: input.ifsc,
        name: input.name,
    });
    const organizerSnap = await (0, admin_1.db)().collection('organizers').doc(ctx.uid).get();
    const legalName = String(organizerSnap.data()?.legalName ?? '');
    const score = (0, vendors_1.nameMatchScore)(result.beneficiaryName ?? '', legalName);
    return {
        status: result.status,
        beneficiaryName: result.beneficiaryName ?? null,
        bankName: result.bankName ?? null,
        branch: result.branch ?? null,
        reference: result.reference ?? null,
        nameMatchScore: score,
        passes: result.status === 'verified' && score >= NAME_MATCH_THRESHOLD,
        message: result.message ?? null,
    };
});
exports.sendEmailCodeCallable = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ email: zod_1.z.string().trim().toLowerCase().email().max(160) }).parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('kyc_email', ctx.uid, input.email), 5, 10 * 60 * 1000);
    const code = await (0, emailcode_1.issueEmailCode)(input.email, 'organizer_email', 15);
    await (0, emailcode_1.deliverEmailCode)(input.email, code);
    const ref = (0, admin_1.db)().collection('organizers').doc(ctx.uid);
    await ref.set({ businessEmail: input.email, emailVerified: false, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true, expiresInSeconds: 900 };
});
exports.verifyEmailCodeCallable = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ email: zod_1.z.string().trim().toLowerCase().email(), code: zod_1.z.string().trim().length(6) }).parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('kyc_email_verify', ctx.uid, input.email), 10, 10 * 60 * 1000);
    const ok = await (0, emailcode_1.verifyEmailCode)(input.email, input.code, 'organizer_email');
    if (!ok)
        (0, errors_1.fail)('INVALID_INPUT', 'That code is invalid or has expired.');
    const ref = (0, admin_1.db)().collection('organizers').doc(ctx.uid);
    await ref.set({ businessEmail: input.email, emailVerified: true, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true, emailVerified: true };
});
exports.submitKyc = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const organizerRef = (0, admin_1.db)().collection('organizers').doc(ctx.uid);
    const snap = await organizerRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Start the KYC form first.');
    const organizer = snap.data();
    const status = String(organizer.kycStatus ?? 'none');
    if (status === 'submitted' || status === 'auto_verified' || status === 'approved') {
        (0, errors_1.fail)('CONFLICT', 'Your KYC has already been submitted.');
    }
    if (!organizer.panMasked)
        (0, errors_1.fail)('INVALID_INPUT', 'Complete step 1 before submitting.');
    if (!organizer.emailVerified)
        (0, errors_1.fail)('INVALID_INPUT', 'Verify your business email before submitting.');
    if (!organizer.bank || !organizer.panMasked)
        (0, errors_1.fail)('INVALID_INPUT', 'Complete step 3 before submitting.');
    const privateSnap = await (0, admin_1.db)().collection('organizerPrivate').doc(ctx.uid).get();
    const priv = privateSnap.data() ?? {};
    if (!priv.panEnc)
        (0, errors_1.fail)('INVALID_INPUT', 'Complete step 1 before submitting.');
    if (!priv.bankAccountEnc)
        (0, errors_1.fail)('INVALID_INPUT', 'Complete step 3 before submitting.');
    const eventsRef = organizerRef.collection('kycEvents').doc();
    await eventsRef.set({
        type: 'submitted',
        note: null,
        by: ctx.uid,
        at: firestore_1.FieldValue.serverTimestamp(),
    });
    await organizerRef.set({
        kycStatus: 'submitted',
        kycStep: 3,
        agreement: {
            version: exports.AGREEMENT_VERSION,
            acceptedAt: firestore_1.FieldValue.serverTimestamp(),
            ip: (0, auth_1.clientIp)(req),
        },
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const autoVerified = await runAutomatedChecks(ctx.uid, organizer, priv);
    if (autoVerified) {
        await organizerRef.set({
            kycStatus: 'auto_verified',
            approvedAt: firestore_1.FieldValue.serverTimestamp(),
            bank: { ...organizer.bank, verified: true, verifiedAt: firestore_1.FieldValue.serverTimestamp() },
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        await organizerRef.collection('kycEvents').doc().set({
            type: 'auto_verified',
            note: 'PAN, penny-drop and name-match checks passed.',
            by: 'system',
            at: firestore_1.FieldValue.serverTimestamp(),
        });
        await (0, claims_1.mergeCustomClaims)(ctx.uid, { organizer: true });
        await (0, notify_1.notifyUser)(ctx.uid, 'kyc_update', 'Organiser verification complete', 'Your organiser account is active. Payouts unlock after Milo review (usually 24 hours).', { deepLink: '/organizer/kyc', channel: 'bookings' });
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'kyc.submitted',
        targetType: 'organizer',
        targetId: ctx.uid,
        after: { kycStatus: autoVerified ? 'auto_verified' : 'submitted' },
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true, kycStatus: autoVerified ? 'auto_verified' : 'submitted', eventId: eventsRef.id };
});
async function runAutomatedChecks(uid, organizer, priv) {
    const privateRef = (0, admin_1.db)().collection('organizerPrivate').doc(uid);
    const pan = (0, envelope_1.decryptField)(priv.panEnc);
    const accountNumber = (0, envelope_1.decryptField)(priv.bankAccountEnc);
    if (!pan || !accountNumber)
        return false;
    const panCheck = await (0, vendors_1.verifyPan)(pan);
    if (panCheck.status !== 'valid')
        return false;
    const bankCheck = await (0, vendors_1.verifyBank)({
        accountNumber,
        ifsc: String(priv.ifsc ?? ''),
        name: String(organizer.legalName ?? ''),
    });
    if (bankCheck.status !== 'verified')
        return false;
    const score = (0, vendors_1.nameMatchScore)(bankCheck.beneficiaryName ?? '', String(organizer.legalName ?? ''));
    if (score < NAME_MATCH_THRESHOLD) {
        await privateRef.set({ nameMatchScore: score, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        return false;
    }
    await privateRef.set({
        nameMatchScore: score,
        vendorRefs: {
            panRef: panCheck.entityType ?? 'verified',
            pennyDropRef: bankCheck.reference ?? 'verified',
        },
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
}
exports.getKycStatus = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const snap = await (0, admin_1.db)().collection('organizers').doc(ctx.uid).get();
    const data = snap.data() ?? {};
    const events = await (0, admin_1.db)()
        .collection('organizers')
        .doc(ctx.uid)
        .collection('kycEvents')
        .orderBy('at', 'desc')
        .limit(20)
        .get();
    return {
        kycStatus: data.kycStatus ?? 'none',
        kycStep: data.kycStep ?? 1,
        entityType: data.entityType ?? null,
        legalName: data.legalName ?? null,
        panMasked: data.panMasked ?? null,
        aadhaarLinked: data.aadhaarLinked ?? null,
        addressSummary: data.addressSummary ?? null,
        pocName: data.pocName ?? null,
        businessEmail: data.businessEmail ?? null,
        emailVerified: data.emailVerified === true,
        bank: data.bank ?? null,
        nameMatchScore: data.nameMatchScore ?? null,
        adminRemarks: data.adminRemarks ?? [],
        trusted: data.trusted === true,
        timeline: events.docs.map((d) => ({ id: d.id, ...d.data() })),
    };
});
//# sourceMappingURL=kyc.js.map