import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onRequest } from 'firebase-functions/https';
import { randomBytes } from 'node:crypto';
import { db } from '../shared/admin';
import {
  createRefund,
  RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET,
  RAZORPAY_WEBHOOK_SECRET,
  verifyWebhookSignature,
} from '../shared/razorpay';
import { notifyUser } from '../shared/notify';
import { confirmInventory, releaseInventory } from './inventory';
import { incrementPromoUsage } from './promo';
import { recordConfirmedBooking } from '../settlement/finance';

interface WebhookPayload {
  event?: string;
  payload?: {
    payment?: {
      entity?: {
        id?: string;
        order_id?: string;
        amount?: number;
        method?: string;
        status?: string;
      };
    };
    refund?: {
      entity?: {
        id?: string;
        payment_id?: string;
        amount?: number;
        status?: string;
      };
    };
  };
}

export const razorpayWebhook = onRequest(
  {
    region: 'asia-south1',
    secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET],
  },
  async (req, res) => {
    const signature = req.header('x-razorpay-signature') ?? '';
    const rawBody = req.rawBody ?? Buffer.from(JSON.stringify(req.body ?? {}));
    if (!verifyWebhookSignature(rawBody, signature)) {
      logger.warn('razorpay.webhook.invalid_signature');
      res.status(401).json({ ok: false, error: 'INVALID_SIGNATURE' });
      return;
    }

    const body = (req.body ?? {}) as WebhookPayload;
    const eventName = body.event ?? '';
    const entity = body.payload?.payment?.entity;
    const refundEntity = body.payload?.refund?.entity;

    if (eventName === 'payment.captured' && entity?.order_id && entity.id) {
      await handleCaptured(entity.order_id, entity.id, Number(entity.amount ?? 0), entity.method ?? 'unknown');
    } else if (eventName === 'payment.failed' && entity?.order_id) {
      await handleFailed(entity.order_id, entity.id ?? '');
    } else if (eventName === 'refund.processed' && refundEntity?.payment_id) {
      await handleRefundProcessed(refundEntity.payment_id, refundEntity.id ?? '', Number(refundEntity.amount ?? 0));
    } else if (eventName === 'refund.failed' && refundEntity?.payment_id) {
      await handleRefundFailed(refundEntity.payment_id, refundEntity.id ?? '');
    } else {
      logger.info('razorpay.webhook.unhandled', { eventName });
    }

    res.status(200).json({ ok: true });
  },
);

async function findBookingByOrderId(orderId: string) {
  const snap = await db().collection('bookings').where('payment.orderId', '==', orderId).limit(1).get();
  if (snap.empty) return null;
  const doc = snap.docs[0]!;
  return { ref: doc.ref, id: doc.id, data: doc.data() };
}

async function handleCaptured(
  orderId: string,
  gatewayPaymentId: string,
  amountPaise: number,
  method: string,
): Promise<void> {
  const found = await findBookingByOrderId(orderId);
  if (!found) {
    logger.warn('razorpay.webhook.no_booking', { orderId });
    return;
  }

  const paymentId = gatewayPaymentId;
  const paymentRef = db().collection('payments').doc(paymentId);

  const alreadyCaptured = await db()
    .collection('bookings')
    .doc(found.id)
    .get()
    .then((s) => s.data()?.status === 'confirmed' || s.data()?.status === 'completed');

  if (alreadyCaptured) {
    logger.info('razorpay.webhook.duplicate_ignored', { bookingId: found.id });
    return;
  }

  const expired = found.data.status === 'expired';
  if (expired) {
    const stillAvailable = await hasInventory(found.data);
    if (!stillAvailable) {
      await autoRefundLateCapture(found.id, paymentId, amountPaise);
      return;
    }
  }

  const allocations = (found.data.reservation?.shards ?? []) as Array<{
    tierId: string;
    shard: string;
    qty: number;
  }>;

  const ticketIds: string[] = [];
  const ticketDocs: Array<{ id: string; data: Record<string, unknown> }> = [];
  const secretDocs: Array<{ id: string; data: Record<string, unknown> }> = [];

  const items = (found.data.items ?? []) as Array<{
    tierId: string;
    tierName: string;
    qty: number;
    unitPaise: number;
    admits: number;
    holderNames?: string[] | null;
  }>;

  const userSnap = await db().collection('users').doc(found.data.userId).get();
  const user = userSnap.data() ?? {};

  let seq = 1;
  for (const item of items) {
    for (let i = 0; i < item.qty; i += 1) {
      const ticketId = `tk_${randomBytes(9).toString('hex')}`;
      ticketIds.push(ticketId);
      ticketDocs.push({
        id: ticketId,
        data: {
          schemaVersion: 1,
          bookingId: found.id,
          refCode: found.data.refCode,
          userId: found.data.userId,
          eventId: found.data.eventId,
          organizerId: found.data.organizerId,
          tierId: item.tierId,
          tierName: item.tierName,
          eventStartAt: found.data.eventSnapshot?.startAt ?? null,
          eventTitle: found.data.eventSnapshot?.title ?? '',
          seq,
          admits: item.admits ?? 1,
          holderName: item.holderNames?.[i] ?? null,
          status: 'valid',
          qrVersion: 1,
          issuedAt: FieldValue.serverTimestamp(),
        },
      });
      secretDocs.push({
        id: ticketId,
        data: {
          schemaVersion: 1,
          secret: randomBytes(32).toString('base64'),
          version: 1,
          createdAt: FieldValue.serverTimestamp(),
        },
      });
      seq += 1;
    }
  }

  const attendeeRef = db()
    .collection('eventAttendees')
    .doc(`${found.data.eventId}_${found.data.userId}`);

  await db().runTransaction(async (tx) => {
    const [bookingSnap, attendeeSnap, paymentSnap] = await Promise.all([
      tx.get(found.ref),
      tx.get(attendeeRef),
      tx.get(paymentRef),
    ]);
    const status = bookingSnap.data()?.status;
    if (status === 'confirmed' || status === 'completed') return;
    if (status === 'cancelled_by_user') {
      throw new Error('BOOKING_CANCELLED');
    }

    tx.update(found.ref, {
      status: 'confirmed',
      payment: {
        provider: 'razorpay',
        orderId,
        paymentId,
        method,
        status: 'captured',
      },
      confirmedAt: FieldValue.serverTimestamp(),
      ticketIds,
      updatedAt: FieldValue.serverTimestamp(),
    });

    for (const doc of ticketDocs) tx.set(db().collection('tickets').doc(doc.id), doc.data);
    for (const doc of secretDocs) tx.set(db().collection('ticketSecrets').doc(doc.id), doc.data);

    const existingAttendee = attendeeSnap.data();
    tx.set(
      attendeeRef,
      {
        schemaVersion: 1,
        eventId: found.data.eventId,
        uid: found.data.userId,
        ticketCount: FieldValue.increment(ticketIds.length),
        firstTicketAt: existingAttendee?.firstTicketAt ?? FieldValue.serverTimestamp(),
        radarOptIn: existingAttendee?.radarOptIn ?? false,
        incognito: user.privacy?.incognito === true,
      },
      { merge: true },
    );

    const webhookEventIds: string[] = (paymentSnap.data()?.webhookEventIds ?? []) as string[];
    tx.set(
      paymentRef,
      {
        schemaVersion: 1,
        bookingId: found.id,
        userId: found.data.userId,
        provider: 'razorpay',
        orderId,
        gatewayPaymentId: paymentId,
        method,
        amountPaise,
        status: 'captured',
        webhookEventIds: [...new Set([...webhookEventIds, `payment.captured:${paymentId}`])],
        capturedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }).catch(async (err) => {
    if (err instanceof Error && err.message === 'BOOKING_CANCELLED') {
      await autoRefundLateCapture(found.id, paymentId, amountPaise);
      return;
    }
    throw err;
  });

  await confirmInventory(found.data.eventId, allocations).catch((err) => {
    logger.error('razorpay.webhook.inventory_confirm_failed', { bookingId: found.id, error: String(err) });
  });

  const promoDocId = (found.data.promo as { docId?: string } | null)?.docId;
  if (promoDocId) {
    await incrementPromoUsage(promoDocId).catch((err) => {
      logger.error('razorpay.webhook.promo_usage_failed', { bookingId: found.id, error: String(err) });
    });
  }

  const pricing = (found.data.pricing ?? {}) as Record<string, number | string>;
  const eventSnap = await db().collection('events').doc(found.data.eventId).get();
  const eventPromoter = (eventSnap.data()?.promoter ?? {}) as { enabled?: boolean; commissionPct?: number };
  const referral = (found.data.referral ?? null) as { promoterId?: string } | null;

  await recordConfirmedBooking({
    eventId: String(found.data.eventId),
    bookingId: found.id,
    lines: items.map((i) => ({ tierId: i.tierId, qty: i.qty, unitPaise: i.unitPaise })),
    grossPaise: Number(pricing.subtotalPaise ?? 0),
    discountPaise: Number(pricing.discountPaise ?? 0),
    platformFeePaise: Number(pricing.platformFeePaise ?? 0),
    gstOnFeePaise: Number(pricing.gstOnFeePaise ?? 0),
    feeBearer: (pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer'),
    promoterId: referral?.promoterId ?? null,
    commissionPct: eventPromoter.enabled === true ? Number(eventPromoter.commissionPct ?? 0) : 0,
  }).catch((err) => {
    logger.error('razorpay.webhook.finance_update_failed', { bookingId: found.id, error: String(err) });
  });

  await notifyUser(
    found.data.userId,
    'booking_confirmed',
    'Booking confirmed',
    `Your tickets for ${found.data.eventSnapshot?.title ?? 'your event'} are confirmed.`,
    { deepLink: `/ticket/${ticketIds[0] ?? ''}`, channel: 'bookings' },
  ).catch(() => undefined);

  logger.info('razorpay.webhook.booking_confirmed', { bookingId: found.id, ticketCount: ticketIds.length });
}

async function hasInventory(booking: { eventId?: unknown; reservation?: { shards?: unknown } }): Promise<boolean> {
  const allocations = (booking.reservation?.shards ?? []) as Array<{
    tierId: string;
    shard: string;
    qty: number;
  }>;
  for (const alloc of allocations) {
    const snap = await db()
      .collection('events')
      .doc(String(booking.eventId))
      .collection('ticketTiers')
      .doc(alloc.tierId)
      .collection('shards')
      .doc(alloc.shard)
      .get();
    const data = snap.data() ?? {};
    const available = Number(data.capacity ?? 0) - Number(data.held ?? 0) - Number(data.sold ?? 0);
    if (available < alloc.qty) return false;
  }
  return true;
}

async function autoRefundLateCapture(bookingId: string, paymentId: string, amountPaise: number): Promise<void> {
  logger.warn('razorpay.webhook.late_capture_autorefund', { bookingId, paymentId });
  try {
    const refund = await createRefund({ paymentId, amountPaise, notes: { reason: 'late_capture' } });
    await db()
      .collection('payments')
      .doc(paymentId)
      .set(
        { refundId: refund.id, refundStatus: 'processed', refundedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
  } catch (err) {
    logger.error('razorpay.webhook.auto_refund_failed', { bookingId, error: String(err) });
  }

  const bookingSnap = await db().collection('bookings').doc(bookingId).get();
  const booking = (bookingSnap.data() ?? {}) as {
    eventId?: string;
    userId?: string;
    reservation?: { shards?: unknown };
  };
  await db()
    .collection('bookings')
    .doc(bookingId)
    .set({ status: 'refunded', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  await releaseInventory(String(booking.eventId), (booking.reservation?.shards ?? []) as Array<{
    tierId: string;
    shard: string;
    qty: number;
  }>).catch(() => undefined);

  await notifyUser(
    String(booking.userId),
    'payment_refunded',
    'Refund initiated',
    'We could not confirm your tickets in time, so the payment has been refunded. It will reach you in 5–7 working days.',
    { deepLink: `/booking/${bookingId}`, channel: 'bookings' },
  ).catch(() => undefined);
}

async function handleFailed(orderId: string, gatewayPaymentId: string): Promise<void> {
  const found = await findBookingByOrderId(orderId);
  if (!found) return;
  await db()
    .collection('bookings')
    .doc(found.id)
    .set(
      {
        status: 'failed',
        payment: { ...(found.data.payment ?? {}), paymentId: gatewayPaymentId, status: 'failed' },
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  await notifyUser(
    found.data.userId,
    'payment_failed',
    'Payment failed',
    'Your payment did not go through. Please try again.',
    { deepLink: `/booking/${found.id}`, channel: 'bookings' },
  ).catch(() => undefined);
}

async function handleRefundProcessed(paymentId: string, refundId: string, amountPaise: number): Promise<void> {
  const paymentSnap = await db().collection('payments').doc(paymentId).get();
  const payment = paymentSnap.data() ?? {};
  await db()
    .collection('payments')
    .doc(paymentId)
    .set(
      {
        refundId,
        refundStatus: 'processed',
        refundAmountPaise: amountPaise,
        refundedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  const bookingId = payment.bookingId as string | undefined;
  if (!bookingId) return;

  const refunds = await db().collection('refunds').where('gatewayPaymentId', '==', paymentId).get();
  for (const refund of refunds.docs) {
    await refund.ref.set(
      {
        status: 'processed',
        gatewayRefundId: refundId,
        processedAt: Timestamp.fromDate(new Date()),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}

async function handleRefundFailed(paymentId: string, refundId: string): Promise<void> {
  const paymentSnap = await db().collection('payments').doc(paymentId).get();
  const payment = paymentSnap.data() ?? {};
  await db()
    .collection('payments')
    .doc(paymentId)
    .set({ refundId, refundStatus: 'failed' }, { merge: true });

  const bookingId = payment.bookingId as string | undefined;
  if (!bookingId) return;
  const refunds = await db().collection('refunds').where('gatewayPaymentId', '==', paymentId).get();
  for (const refund of refunds.docs) {
    await refund.ref.set({ status: 'failed', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
}
