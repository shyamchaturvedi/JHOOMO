import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { getFeesConfig } from '../shared/config';
import { computeTds } from '../shared/tds';
import { sha256Hex } from '../shared/crypto';
import { mergeCustomClaims } from '../shared/claims';
import { indianFinancialYear } from '../shared/time';
import { notifyUser } from '../shared/notify';
import { panSchema } from '../shared/schemas';

const PROMOTER_TERMS_VERSION = '1.0';

const becomePromoterSchema = z.object({
  displayName: z.string().trim().min(2).max(60),
  pan: panSchema,
  code: z
    .string()
    .trim()
    .toUpperCase()
    .min(3)
    .max(12)
    .regex(/^[A-Z0-9_-]+$/, 'Code may contain letters, numbers, _ and -'),
  termsAccepted: z.literal(true),
});

export const becomePromoter = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = becomePromoterSchema.parse(req.data);

  const codeRef = db().collection('referralCodes').doc(input.code);
  const existing = await codeRef.get();
  if (existing.exists) fail('CONFLICT', 'That referral code is already taken.');

  const userRef = db().collection('users').doc(ctx.uid);
  const userSnap = await userRef.get();
  const user = userSnap.data() ?? {};

  await db()
    .collection('promoterPrivate')
    .doc(ctx.uid)
    .set(
      {
        schemaVersion: 1,
        panHash: sha256Hex(input.pan),
        panLast4: input.pan.slice(-4),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await db()
    .collection('promoters')
    .doc(ctx.uid)
    .set(
      {
        schemaVersion: 1,
        displayName: input.displayName,
        code: input.code,
        status: 'active',
        termsVersion: PROMOTER_TERMS_VERSION,
        termsAcceptedAt: FieldValue.serverTimestamp(),
        panLast4: input.pan.slice(-4),
        bank: null,
        totals: { bookings: 0, pendingPaise: 0, approvedPaise: 0, paidPaise: 0 },
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await codeRef.set(
    { promoterId: ctx.uid, active: true, createdAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  await userRef.set(
    {
      schemaVersion: 1,
      roles: { ...(user.roles ?? {}), promoter: true },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await mergeCustomClaims(ctx.uid, { promoter: true });

  return { ok: true, code: input.code, termsVersion: PROMOTER_TERMS_VERSION };
});

const requestPayoutSchema = z.object({
  bankAccountNumber: z.string().regex(/^\d{9,18}$/),
  ifsc: z.string().regex(/^[A-Z]{4}0[A-Z0-9]{6}$/),
  bankName: z.string().trim().min(2).max(80),
});

export const requestPromoterPayout = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = requestPayoutSchema.parse(req.data);

  const promoterRef = db().collection('promoters').doc(ctx.uid);
  const promoterSnap = await promoterRef.get();
  if (!promoterSnap.exists) fail('NOT_FOUND', 'Promoter profile not found.');
  const promoter = promoterSnap.data()!;
  if (promoter.status !== 'active') fail('FORBIDDEN', 'Your promoter account is not active.');

  const fees = await getFeesConfig();
  const approved = await db()
    .collection('commissions')
    .where('promoterId', '==', ctx.uid)
    .where('status', '==', 'approved')
    .get();

  const availablePaise = approved.docs.reduce((sum, d) => sum + Number(d.data().amountPaise ?? 0), 0);
  if (availablePaise < fees.minPayoutPaise) {
    fail(
      'INVALID_INPUT',
      `Minimum payout is ₹${(fees.minPayoutPaise / 100).toFixed(2)}. Approved commission is ₹${(availablePaise / 100).toFixed(2)}.`,
    );
  }

  const privateSnap = await db().collection('promoterPrivate').doc(ctx.uid).get();
  const panPresent = Boolean(privateSnap.data()?.panHash);

  const fy = indianFinancialYear(new Date());
  const fyPaid = await db()
    .collection('promoterPayouts')
    .where('promoterId', '==', ctx.uid)
    .where('financialYear', '==', fy.key)
    .get();
  const alreadyPaid = fyPaid.docs
    .filter((d) => d.data().status !== 'failed')
    .reduce((sum, d) => sum + Number(d.data().tdsPaise ?? 0), 0);

  const tds = computeTds({
    amountPaise: availablePaise,
    panPresent,
    fyAlreadyPaidPaise: alreadyPaid,
    tdsPct: fees.tdsPct,
    thresholdPaise: fees.tdsThresholdPaise,
    rateWithoutPanPct: fees.tdsRateWithoutPanPct,
  });

  const payoutRef = db().collection('promoterPayouts').doc();
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
    requestedAt: FieldValue.serverTimestamp(),
  });

  await promoterRef.set(
    {
      schemaVersion: 1,
      bank: {
        bankName: input.bankName,
        last4: input.bankAccountNumber.slice(-4),
        verified: false,
        changedAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await notifyUser(
    ctx.uid,
    'promoter_payout_requested',
    'Payout requested',
    `Payout of ₹${(availablePaise / 100).toFixed(2)} requested. TDS of ₹${(tds.tdsPaise / 100).toFixed(2)} will be deducted as applicable.`,
    { deepLink: '/promoter', channel: 'bookings' },
  );

  return {
    ok: true,
    payoutId: payoutRef.id,
    amountPaise: availablePaise,
    tdsPaise: tds.tdsPaise,
    netPaise: availablePaise - tds.tdsPaise,
    tdsRatePct: tds.ratePct,
    tdsReason: tds.reason,
    panMissing: tds.panMissing,
    panMasked: (privateSnap.data()?.panMasked as string | undefined) ?? null,
  };
});
