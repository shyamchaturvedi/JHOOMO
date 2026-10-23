import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { z } from 'zod';
import { db } from '../shared/admin';
import { miloOnCall } from '../shared/callable';
import { requireAuth, requireAdmin } from '../shared/auth';
import { fail } from '../shared/errors';
import { createTransfer } from '../shared/razorpay';
import { computeSettlement, evaluateSettlementHolds } from '../shared/settlement';
import { getLimitsConfig } from '../shared/config';
import { settlementScheduledFor } from '../shared/time';
import { notifyUser } from '../shared/notify';
import { writeAuditLog } from '../shared/audit';
import { requestIdOf } from '../shared/callable';
import { newId } from '../shared/ids';

interface EventForSettlement {
  organizerId: string;
  title: string;
  status: string;
  schedule: { startAt: Timestamp; endAt: Timestamp };
  promoter: { enabled: boolean; commissionPct: number };
}

/**
 * Daily settlement run — 11:00 IST on the day after the event's last day
 * (PRD §8.3 / §12.3). Funds are released to the organiser through Razorpay
 * Route held transfers; Milo never custodies the money itself.
 */
export const settlementRun = onSchedule(
  { schedule: 'every day 11:00', timeZone: 'Asia/Kolkata', region: 'asia-south1', maxInstances: 1 },
  async () => {
    const now = new Date();
    const events = await db()
      .collection('events')
      .where('status', 'in', ['live', 'sold_out', 'completed', 'paused'])
      .get();

    let processed = 0;
    for (const doc of events.docs) {
      const event = doc.data() as EventForSettlement;
      const endAt = event.schedule?.endAt?.toDate?.();
      if (!endAt) continue;
      const scheduledFor = settlementScheduledFor(endAt);
      if (scheduledFor.getTime() > now.getTime()) continue;

      const existing = await db().collection('settlements').where('eventId', '==', doc.id).limit(1).get();
      if (!existing.empty) continue;

      try {
        await createSettlement(doc.id, event, now);
        processed += 1;
      } catch (err) {
        logger.error('settlementRun.failed', { eventId: doc.id, error: String(err) });
      }
    }

    logger.info('settlementRun.complete', { processed, scanned: events.size });
  },
);

async function createSettlement(
  eventId: string,
  event: EventForSettlement,
  now: Date,
): Promise<string> {
  const organizerSnap = await db().collection('organizers').doc(event.organizerId).get();
  const organizer = organizerSnap.data() ?? {};

  const bookingsSnap = await db()
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
  let feeBearer: 'buyer' | 'organizer' = 'organizer';

  for (const doc of bookingsSnap.docs) {
    const booking = doc.data();
    const pricing = (booking.pricing ?? {}) as Record<string, number | string>;
    grossPaise += Number(pricing.subtotalPaise ?? 0);
    discountPaise += Number(pricing.discountPaise ?? 0);
    platformFeePaise += Number(pricing.platformFeePaise ?? 0);
    gstOnFeePaise += Number(pricing.gstOnFeePaise ?? 0);
    refundsPaise += Number(booking.refundedPaise ?? 0);
    feeBearer = pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer';

    const promo = booking.promo as { fundedBy?: string } | null;
    if (promo?.fundedBy === 'organizer') {
      organizerFundedDiscountPaise += Number(pricing.discountPaise ?? 0);
    }
  }

  const commissionsSnap = await db()
    .collection('commissions')
    .where('eventId', '==', eventId)
    .where('status', 'in', ['pending', 'approved'])
    .get();
  for (const doc of commissionsSnap.docs) {
    promoterCommissionPaise += Number(doc.data().amountPaise ?? 0);
  }

  const settlement = computeSettlement({
    grossPaise,
    refundsPaise,
    platformFeePaise,
    gstOnFeePaise,
    promoterCommissionPaise,
    organizerFundedDiscountPaise,
    feeBearer,
  });

  const limits = await getLimitsConfig();
  const bankChangedAt = (organizer.bank?.changedAt as Timestamp | undefined)?.toDate?.() ?? null;
  const fraudFlags = await db().collection('fraudFlags').where('eventId', '==', eventId).get();
  const disputes = await db()
    .collection('supportTickets')
    .where('eventId', '==', eventId)
    .where('status', 'in', ['open', 'in_progress'])
    .get();

  const holdResult = evaluateSettlementHolds({
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

  const settlementId = newId('st');
  const settlementRef = db().collection('settlements').doc(settlementId);
  const endAt = event.schedule.endAt.toDate();
  const scheduledFor = settlementScheduledFor(endAt);

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
    scheduledFor: Timestamp.fromDate(scheduledFor),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await releasePromoterCommissions(eventId);

  if (holdResult.eligible) {
    await disburseSettlement(settlementId, eventId, event.organizerId);
  } else {
    await notifyUser(
      event.organizerId,
      'settlement_update',
      'Settlement on hold',
      `The payout for "${event.title}" is on hold pending review. Our team will contact you shortly.`,
      { deepLink: '/organizer/settlements', channel: 'bookings' },
    ).catch(() => undefined);
  }

  return settlementId;
}

async function disburseSettlement(
  settlementId: string,
  eventId: string,
  organizerId: string,
): Promise<void> {
  const settlementRef = db().collection('settlements').doc(settlementId);
  const snap = await settlementRef.get();
  const settlement = snap.data() ?? {};
  const netPaise = Number(settlement.netPaise ?? 0);
  if (netPaise <= 0) {
    await settlementRef.set({ status: 'paid', paidAt: FieldValue.serverTimestamp(), netPaise: 0 }, { merge: true });
    return;
  }

  const privateSnap = await db().collection('organizerPrivate').doc(organizerId).get();
  const razorpayAccount = privateSnap.data()?.razorpayAccountId as string | undefined;
  if (!razorpayAccount) {
    await settlementRef.set(
      {
        status: 'on_hold',
        holdReasons: [...(settlement.holdReasons ?? []), 'BANK_ACCOUNT_NOT_ONBOARDED'],
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return;
  }

  await settlementRef.set({ status: 'processing', updatedAt: FieldValue.serverTimestamp() }, { merge: true });

  try {
    const transfer = await createTransfer({
      account: razorpayAccount,
      amountPaise: netPaise,
      referenceId: settlementId,
      notes: { eventId, settlementId },
    });
    await settlementRef.set(
      {
        gatewayTransferId: transfer.id,
        transferStatus: transfer.status,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (err) {
    logger.error('settlement.transfer_failed', { settlementId, error: String(err) });
    await settlementRef.set(
      { status: 'failed', failureReason: String(err), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
}

/** Promoter commissions become payable once the event and its refund window close. */
export async function releasePromoterCommissions(eventId: string): Promise<void> {
  const commissions = await db()
    .collection('commissions')
    .where('eventId', '==', eventId)
    .where('status', '==', 'pending')
    .get();

  for (const doc of commissions.docs) {
    await doc.ref.set(
      { status: 'approved', approvedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    await notifyUser(
      String(doc.data().promoterId),
      'commission_update',
      'Commission approved',
      'Your commission for a recent event is now available for payout.',
      { deepLink: '/promoter', channel: 'bookings' },
    ).catch(() => undefined);
  }
}

export const approveSettlement = miloOnCall({}, async (req) => {
  requireAdmin(req, 'L3');
  const input = z.object({ settlementId: z.string().min(1).max(64) }).parse(req.data);

  const settlementRef = db().collection('settlements').doc(input.settlementId);
  const snap = await settlementRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Settlement not found.');
  const settlement = snap.data()!;
  if (settlement.status !== 'on_hold') fail('CONFLICT', 'This settlement is not on hold.');

  const approvals = (settlement.approvals ?? []) as Array<{ by: string; at: Timestamp }>;
  if (approvals.some((a) => a.by === req.auth?.uid)) {
    fail('FORBIDDEN', 'You have already approved this settlement.');
  }
  approvals.push({ by: String(req.auth?.uid), at: Timestamp.now() });

  const holdReasons = (settlement.holdReasons ?? []).filter(
    (r: string) => r !== 'FOUR_EYES_REQUIRED',
  );
  const onlyFourEyes = holdReasons.length === 0;

  await settlementRef.set(
    {
      approvals,
      holdReasons,
      status: onlyFourEyes && approvals.length >= 2 ? 'scheduled' : 'on_hold',
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  if (onlyFourEyes && approvals.length >= 2) {
    await disburseSettlement(input.settlementId, String(settlement.eventId), String(settlement.organizerId));
  }

  await writeAuditLog({
    actorUid: String(req.auth?.uid),
    actorLevel: 'L3',
    action: 'settlement.approved',
    targetType: 'settlement',
    targetId: input.settlementId,
    after: { approvals: approvals.length },
    requestId: requestIdOf(req),
  });

  return { ok: true, approvals: approvals.length, status: onlyFourEyes && approvals.length >= 2 ? 'scheduled' : 'on_hold' };
});

export const listSettlements = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({ status: z.string().max(20).optional(), limit: z.number().int().min(1).max(50).default(20) })
    .parse(req.data);

  let query = db().collection('settlements').where('organizerId', '==', ctx.uid);
  if (input.status) query = query.where('status', '==', input.status);
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
