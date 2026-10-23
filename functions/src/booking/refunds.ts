import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { newId } from '../shared/ids';
import { createRefund } from '../shared/razorpay';
import { notifyUser } from '../shared/notify';
import { getFeesConfig } from '../shared/config';
import { min0 } from '../shared/money';
import { hoursBetween } from '../shared/time';
import { recordRefund } from '../settlement/finance';

interface RefundPolicy {
  windowDays?: number;
  type?: 'full' | 'pro-rata' | 'none';
  cutoffHoursBefore?: number;
  processingFeePaise?: number;
}

interface BookingForRefund {
  id: string;
  userId: string;
  eventId: string;
  organizerId: string;
  status: string;
  refCode: string;
  items: Array<{ tierId: string; tierName: string; qty: number; unitPaise: number; admits: number }>;
  pricing: {
    subtotalPaise: number;
    discountPaise: number;
    platformFeePaise: number;
    gstOnFeePaise: number;
    totalPaise: number;
  };
  payment: { provider?: string; orderId?: string; paymentId?: string; status?: string };
  eventSnapshot: { title?: string; startAt?: Timestamp };
}

const DEFAULT_POLICY: Required<RefundPolicy> = {
  windowDays: 7,
  type: 'full',
  cutoffHoursBefore: 24,
  processingFeePaise: 0,
};

const requestRefundSchema = z.object({
  bookingId: z.string().min(1).max(64),
  ticketIds: z.array(z.string().min(1).max(64)).max(50).optional(),
  reason: z.string().trim().max(500).optional(),
});

export const requestRefund = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = requestRefundSchema.parse(req.data);

  const bookingRef = db().collection('bookings').doc(input.bookingId);
  const snap = await bookingRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Booking not found.');
  const booking = snap.data() as BookingForRefund;
  if (booking.userId !== ctx.uid) fail('FORBIDDEN', 'This booking belongs to another account.');
  if (booking.status !== 'confirmed' && booking.status !== 'completed' && booking.status !== 'refunded_partial') {
    fail('CONFLICT', 'This booking is not eligible for a refund.');
  }
  if (!booking.payment?.paymentId) {
    fail('CONFLICT', 'We could not locate the payment for this booking.');
  }

  const eventSnap = await db().collection('events').doc(booking.eventId).get();
  const event = eventSnap.data() ?? {};
  const policy: Required<RefundPolicy> = { ...DEFAULT_POLICY, ...((event.refundPolicy ?? {}) as RefundPolicy) };
  if (policy.type === 'none') {
    fail('CONFLICT', 'This event does not allow refunds.');
  }

  const startAt = booking.eventSnapshot?.startAt?.toDate?.() ?? null;
  const now = new Date();
  if (startAt) {
    const hoursToStart = hoursBetween(now, startAt);
    if (hoursToStart < policy.cutoffHoursBefore) {
      fail('CONFLICT', `Refunds close ${policy.cutoffHoursBefore} hours before the event starts.`);
    }
    if (policy.windowDays > 0 && hoursToStart > policy.windowDays * 24) {
      fail('CONFLICT', `The ${policy.windowDays}-day refund window for this event has closed.`);
    }
  }

  const ticketsSnap = await db().collection('tickets').where('bookingId', '==', booking.id).get();
  let tickets = ticketsSnap.docs.map((d) => ({ id: d.id, ...d.data() } as { id: string; tierId: string; unitPaise?: number; status: string }));
  if (input.ticketIds && input.ticketIds.length > 0) {
    const wanted = new Set(input.ticketIds);
    tickets = tickets.filter((t) => wanted.has(t.id));
    if (tickets.length === 0) fail('NOT_FOUND', 'No matching tickets found on this booking.');
  }

  const checkedIn = tickets.filter((t) => t.status === 'checked_in');
  const refundable = tickets.filter((t) => t.status === 'valid');
  if (refundable.length === 0) {
    fail('TICKET_CHECKED_IN', 'These tickets have already been used at the gate.');
  }

  const ticketAmountPaise = refundable.reduce((sum, t) => {
    const item = booking.items.find((i) => i.tierId === t.tierId);
    return sum + (item?.unitPaise ?? 0);
  }, 0);

  const feesConfig = await getFeesConfig();
  const feeRefundPaise = feesConfig.refundPlatformFee
    ? booking.pricing.platformFeePaise + booking.pricing.gstOnFeePaise
    : 0;

  const grossRefundPaise = min0(ticketAmountPaise + feeRefundPaise);
  const processingFeePaise = policy.type === 'pro-rata' ? policy.processingFeePaise : 0;
  const refundAmountPaise = min0(grossRefundPaise - processingFeePaise);
  if (refundAmountPaise <= 0) fail('CONFLICT', 'The refundable amount is zero.');

  const autoApprove = policy.type === 'full' && policy.cutoffHoursBefore >= 24;

  const refundId = newId('rf');
  const refundRef = db().collection('refunds').doc(refundId);
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
    requestedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  if (autoApprove) {
    await processRefund(refundId);
  } else {
    await notifyUser(
      booking.organizerId,
      'refund_requested',
      'Refund requested',
      `${booking.refCode} has a refund request waiting for review.`,
      { deepLink: `/organizer/refunds/${refundId}`, channel: 'bookings' },
    ).catch(() => undefined);
  }

  const latest = await refundRef.get();
  return { refundId, status: latest.data()?.status, amountPaise: refundAmountPaise };
});

export async function processRefund(refundId: string): Promise<void> {
  const refundRef = db().collection('refunds').doc(refundId);
  const snap = await refundRef.get();
  if (!snap.exists) throw new Error('REFUND_NOT_FOUND');
  const refund = snap.data()!;
  if (refund.status === 'processed' || refund.status === 'submitted') return;
  if (refund.status === 'requested') throw new Error('REFUND_NOT_APPROVED');

  const gatewayPaymentId = refund.gatewayPaymentId as string | null;
  if (!gatewayPaymentId) throw new Error('REFUND_MISSING_PAYMENT');

  try {
    const created = await createRefund({
      paymentId: gatewayPaymentId,
      amountPaise: Number(refund.amountPaise ?? 0),
      notes: { refundId, bookingId: refund.bookingId, reason: 'customer_request' },
    });
    await refundRef.set(
      {
        status: 'submitted',
        gatewayRefundId: created.id,
        submittedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (err) {
    logger.error('refund.gateway_failed', { refundId, error: String(err) });
    await refundRef.set(
      { status: 'failed', failureReason: String(err), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    throw err;
  }

  const bookingRef = db().collection('bookings').doc(refund.bookingId);
  const ticketIds = (refund.ticketIds ?? []) as string[];

  await db().runTransaction(async (tx) => {
    const bookingSnap = await tx.get(bookingRef);
    const booking = bookingSnap.data() as BookingForRefund | undefined;
    if (!booking) return;

    const alreadyRefunded = Number((booking as { refundedPaise?: number }).refundedPaise ?? 0);
    const remaining = booking.pricing.totalPaise - alreadyRefunded - Number(refund.amountPaise ?? 0);
    const fullyRefunded = remaining <= 0;

    tx.update(bookingRef, {
      status: fullyRefunded ? 'refunded' : 'refunded_partial',
      refundedPaise: alreadyRefunded + Number(refund.amountPaise ?? 0),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  for (const ticketId of ticketIds) {
    await db()
      .collection('tickets')
      .doc(ticketId)
      .set({ status: 'void', voidedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  await recordRefund({
    eventId: String(refund.eventId),
    amountPaise: Number(refund.amountPaise ?? 0),
  }).catch(() => undefined);

  await notifyUser(
    refund.userId,
    'refund_processed',
    'Refund initiated',
    'Your refund has been initiated and should reach your account in 5–7 working days.',
    { deepLink: `/booking/${refund.bookingId}`, channel: 'bookings' },
  ).catch(() => undefined);
}

export const organizerApproveRefund = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ refundId: z.string().min(1).max(64) }).parse(req.data);

  const refundRef = db().collection('refunds').doc(input.refundId);
  const snap = await refundRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Refund request not found.');
  const refund = snap.data()!;
  if (refund.organizerId !== ctx.uid) fail('FORBIDDEN', 'This refund belongs to another organiser.');
  if (refund.status !== 'requested') fail('CONFLICT', 'This refund request is not pending review.');

  await refundRef.set(
    { status: 'approved', approvedBy: ctx.uid, approvedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  await processRefund(input.refundId);
  return { ok: true, refundId: input.refundId };
});

export const organizerRejectRefund = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ refundId: z.string().min(1).max(64), reason: z.string().trim().max(500).optional() }).parse(req.data);

  const refundRef = db().collection('refunds').doc(input.refundId);
  const snap = await refundRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Refund request not found.');
  const refund = snap.data()!;
  if (refund.organizerId !== ctx.uid) fail('FORBIDDEN', 'This refund belongs to another organiser.');
  if (refund.status !== 'requested') fail('CONFLICT', 'This refund request is not pending review.');

  await refundRef.set(
    {
      status: 'rejected',
      rejectedBy: ctx.uid,
      rejectionReason: input.reason ?? null,
      decidedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await notifyUser(
    refund.userId,
    'refund_rejected',
    'Refund request declined',
    'Your refund request was declined. Contact support if you need help.',
    { deepLink: `/booking/${refund.bookingId}`, channel: 'bookings' },
  ).catch(() => undefined);

  return { ok: true, refundId: input.refundId };
});
