import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall, requestIdOf } from '../shared/callable';
import { clientIp, requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { ifscSchema, panSchema, phoneSchema, pincodeSchema } from '../shared/schemas';
import { maskPan } from '../shared/crypto';
import { mergeCustomClaims } from '../shared/claims';
import { deliverEmailCode, issueEmailCode, verifyEmailCode } from '../shared/emailcode';
import { decryptField, encryptField, Envelope } from '../shared/envelope';
import { nameMatchScore, verifyBank, verifyPan } from '../shared/vendors';
import { notifyUser } from '../shared/notify';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';
import { writeAuditLog } from '../shared/audit';

export const AGREEMENT_VERSION = '1.0';
const NAME_MATCH_THRESHOLD = 80;

const ENTITY_BY_PAN_CHAR: Record<string, string> = {
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

const step1Schema = z.object({
  pan: panSchema.transform((v) => v.toUpperCase()),
  legalName: z.string().trim().min(2).max(120),
  address: z.object({
    line1: z.string().trim().min(2).max(160),
    line2: z.string().trim().max(160).optional(),
    city: z.string().trim().min(2).max(80),
    state: z.string().trim().min(2).max(80),
    pincode: pincodeSchema,
  }),
  aadhaarLinked: z.enum(['yes', 'no', 'na']),
  gstin: z
    .string()
    .trim()
    .toUpperCase()
    .regex(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]{1}$/, 'Invalid GSTIN')
    .optional(),
});

const step2Schema = z.object({
  pocName: z.string().trim().min(2).max(60),
  businessEmail: z.string().trim().toLowerCase().email().max(160),
  phone: phoneSchema,
});

const step3Schema = z.object({
  bankAccountNumber: z.string().trim().regex(/^[0-9]{9,18}$/, 'Enter a valid account number'),
  confirmAccountNumber: z.string().trim().regex(/^[0-9]{9,18}$/, 'Enter a valid account number'),
  ifsc: ifscSchema,
  bankName: z.string().trim().min(2).max(80),
  branch: z.string().trim().max(80).optional(),
  agreementAccepted: z.literal(true),
});

export const saveKycDraft = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const raw = req.data as { step?: number; step1?: unknown; step2?: unknown; step3?: unknown };
  const step = Number(raw.step ?? 1);

  const organizerRef = db().collection('organizers').doc(ctx.uid);
  const existing = (await organizerRef.get()).data() ?? {};
  const status = String(existing.kycStatus ?? 'none');

  if (status === 'submitted' || status === 'auto_verified' || status === 'approved') {
    fail('CONFLICT', 'Your KYC has already been submitted.');
  }
  if (status === 'suspended') fail('FORBIDDEN', 'Your organiser account is suspended.');

  const patch: Record<string, unknown> = {
    kycStatus: status === 'none' ? 'draft' : status,
    kycStep: step,
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (step === 1 && raw.step1) {
    const data = step1Schema.parse(raw.step1);
    const entityType = ENTITY_BY_PAN_CHAR[data.pan.charAt(3)] ?? 'other';

    const panCheck = await verifyPan(data.pan);
    let legalName = data.legalName;
    if (panCheck.status === 'valid' && panCheck.nameOnRecord) {
      legalName = panCheck.nameOnRecord;
    }
    const score = nameMatchScore(legalName, data.legalName);

    patch.entityType = entityType;
    patch.legalName = legalName;
    patch.panMasked = maskPan(data.pan);
    patch.aadhaarLinked = panCheck.aadhaarLinked ?? data.aadhaarLinked;
    patch.addressSummary = {
      city: data.address.city,
      state: data.address.state,
      pincode: data.address.pincode,
    };
    patch.nameMatchScore = score;

    const privateRef = db().collection('organizerPrivate').doc(ctx.uid);
    await privateRef.set(
      {
        schemaVersion: 1,
        panEnc: encryptField(data.pan),
        panLast4: data.pan.slice(-4),
        addressFull: data.address,
        gstin: data.gstin ?? null,
        vendorRefs: { panRef: panCheck.status === 'valid' ? (panCheck.entityType ?? 'verified') : undefined },
        dataKeyVersion: 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
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
      fail('INVALID_INPUT', 'The account numbers do not match.');
    }
    const privateRef = db().collection('organizerPrivate').doc(ctx.uid);
    await privateRef.set(
      {
        bankAccountEnc: encryptField(data.bankAccountNumber),
        ifsc: data.ifsc,
        bankName: data.bankName,
        branch: data.branch ?? null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    patch.bank = {
      bankName: data.bankName,
      branch: data.branch ?? '',
      last4: data.bankAccountNumber.slice(-4),
      verified: false,
      changedAt: FieldValue.serverTimestamp(),
    };
  }

  await organizerRef.set(patch, { merge: true });
  return { ok: true, kycStep: step, kycStatus: patch.kycStatus ?? status };
});

export const verifyPanCallable = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ pan: panSchema.transform((v) => v.toUpperCase()) }).parse(req.data);
  await consumeRateLimit(rateLimitKey('kyc_pan', ctx.uid), 10, 10 * 60 * 1000);

  const result = await verifyPan(input.pan);
  const entityType = ENTITY_BY_PAN_CHAR[input.pan.charAt(3)] ?? 'other';
  return {
    status: result.status,
    entityType,
    nameOnRecord: result.nameOnRecord ?? null,
    aadhaarLinked: result.aadhaarLinked ?? null,
    message: result.message ?? null,
  };
});

export const verifyBankCallable = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      bankAccountNumber: z.string().trim().regex(/^[0-9]{9,18}$/),
      ifsc: ifscSchema,
      name: z.string().trim().min(2).max(120),
    })
    .parse(req.data);
  await consumeRateLimit(rateLimitKey('kyc_bank', ctx.uid), 10, 10 * 60 * 1000);

  const result = await verifyBank({
    accountNumber: input.bankAccountNumber,
    ifsc: input.ifsc,
    name: input.name,
  });

  const organizerSnap = await db().collection('organizers').doc(ctx.uid).get();
  const legalName = String(organizerSnap.data()?.legalName ?? '');
  const score = nameMatchScore(result.beneficiaryName ?? '', legalName);

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

export const sendEmailCodeCallable = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ email: z.string().trim().toLowerCase().email().max(160) }).parse(req.data);
  await consumeRateLimit(rateLimitKey('kyc_email', ctx.uid, input.email), 5, 10 * 60 * 1000);

  const code = await issueEmailCode(input.email, 'organizer_email', 15);
  await deliverEmailCode(input.email, code);

  const ref = db().collection('organizers').doc(ctx.uid);
  await ref.set(
    { businessEmail: input.email, emailVerified: false, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  return { ok: true, expiresInSeconds: 900 };
});

export const verifyEmailCodeCallable = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ email: z.string().trim().toLowerCase().email(), code: z.string().trim().length(6) }).parse(req.data);
  await consumeRateLimit(rateLimitKey('kyc_email_verify', ctx.uid, input.email), 10, 10 * 60 * 1000);

  const ok = await verifyEmailCode(input.email, input.code, 'organizer_email');
  if (!ok) fail('INVALID_INPUT', 'That code is invalid or has expired.');

  const ref = db().collection('organizers').doc(ctx.uid);
  await ref.set(
    { businessEmail: input.email, emailVerified: true, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { ok: true, emailVerified: true };
});

export const submitKyc = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const organizerRef = db().collection('organizers').doc(ctx.uid);
  const snap = await organizerRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Start the KYC form first.');
  const organizer = snap.data()!;

  const status = String(organizer.kycStatus ?? 'none');
  if (status === 'submitted' || status === 'auto_verified' || status === 'approved') {
    fail('CONFLICT', 'Your KYC has already been submitted.');
  }

  if (!organizer.panMasked) fail('INVALID_INPUT', 'Complete step 1 before submitting.');
  if (!organizer.emailVerified) fail('INVALID_INPUT', 'Verify your business email before submitting.');
  if (!organizer.bank || !organizer.panMasked) fail('INVALID_INPUT', 'Complete step 3 before submitting.');

  const privateSnap = await db().collection('organizerPrivate').doc(ctx.uid).get();
  const priv = privateSnap.data() ?? {};
  if (!priv.panEnc) fail('INVALID_INPUT', 'Complete step 1 before submitting.');
  if (!priv.bankAccountEnc) fail('INVALID_INPUT', 'Complete step 3 before submitting.');

  const eventsRef = organizerRef.collection('kycEvents').doc();
  await eventsRef.set({
    type: 'submitted',
    note: null,
    by: ctx.uid,
    at: FieldValue.serverTimestamp(),
  });

  await organizerRef.set(
    {
      kycStatus: 'submitted',
      kycStep: 3,
      agreement: {
        version: AGREEMENT_VERSION,
        acceptedAt: FieldValue.serverTimestamp(),
        ip: clientIp(req),
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const autoVerified = await runAutomatedChecks(ctx.uid, organizer, priv);

  if (autoVerified) {
    await organizerRef.set(
      {
        kycStatus: 'auto_verified',
        approvedAt: FieldValue.serverTimestamp(),
        bank: { ...(organizer.bank as object), verified: true, verifiedAt: FieldValue.serverTimestamp() },
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await organizerRef.collection('kycEvents').doc().set({
      type: 'auto_verified',
      note: 'PAN, penny-drop and name-match checks passed.',
      by: 'system',
      at: FieldValue.serverTimestamp(),
    });
    await mergeCustomClaims(ctx.uid, { organizer: true });
    await notifyUser(
      ctx.uid,
      'kyc_update',
      'Organiser verification complete',
      'Your organiser account is active. Payouts unlock after Milo review (usually 24 hours).',
      { deepLink: '/organizer/kyc', channel: 'bookings' },
    );
  }

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'kyc.submitted',
    targetType: 'organizer',
    targetId: ctx.uid,
    after: { kycStatus: autoVerified ? 'auto_verified' : 'submitted' },
    requestId: requestIdOf(req),
  });

  return { ok: true, kycStatus: autoVerified ? 'auto_verified' : 'submitted', eventId: eventsRef.id };
});

async function runAutomatedChecks(
  uid: string,
  organizer: Record<string, unknown>,
  priv: Record<string, unknown>,
): Promise<boolean> {
  const privateRef = db().collection('organizerPrivate').doc(uid);
  const pan = decryptField(priv.panEnc as Envelope | undefined);
  const accountNumber = decryptField(priv.bankAccountEnc as Envelope | undefined);
  if (!pan || !accountNumber) return false;

  const panCheck = await verifyPan(pan);
  if (panCheck.status !== 'valid') return false;

  const bankCheck = await verifyBank({
    accountNumber,
    ifsc: String(priv.ifsc ?? ''),
    name: String(organizer.legalName ?? ''),
  });
  if (bankCheck.status !== 'verified') return false;

  const score = nameMatchScore(bankCheck.beneficiaryName ?? '', String(organizer.legalName ?? ''));
  if (score < NAME_MATCH_THRESHOLD) {
    await privateRef.set({ nameMatchScore: score, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return false;
  }

  await privateRef.set(
    {
      nameMatchScore: score,
      vendorRefs: {
        panRef: panCheck.entityType ?? 'verified',
        pennyDropRef: bankCheck.reference ?? 'verified',
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return true;
}

export const getKycStatus = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const snap = await db().collection('organizers').doc(ctx.uid).get();
  const data = snap.data() ?? {};
  const events = await db()
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
