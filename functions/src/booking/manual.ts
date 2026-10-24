import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { randomBytes } from 'node:crypto';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { getFeesConfig, getPublicConfig } from '../shared/config';
import { computePricing, PricingLine } from '../shared/pricing';
import { isAtLeastAge, MIN_AGE } from '../shared/age';
import { bindBookingRef, newId, nextBookingRef } from '../shared/ids';
import { eventIdSchema, tierIdSchema } from '../shared/schemas';
import { notifyUser } from '../shared/notify';
import { recordConfirmedBooking } from '../settlement/finance';
import { confirmInventory, ensureShards, releaseInventory, reserveInventory, ShardAllocation } from './inventory';

const submitManualPaymentSchema = z.object({
  eventId: eventIdSchema,
  tierId: tierIdSchema,
  quantity: z.number().int().min(1).max(20),
  method: z.enum(['RAZORPAY']),
  utr: z.string().trim().min(4).max(80),
  attendeeName: z.string().trim().min(1).max(80),
  attendeePhone: z.string().trim().min(6).max(20),
  organizerUpiId: z.string().trim().max(120).optional(),
  proofUrl: z.string().trim().url().max(600).optional(),
  note: z.string().trim().max(500).optional(),
  idempotencyKey: z.string().max(80).optional(),
});

const reviewManualPaymentSchema = z.object({
  requestId: z.string().min(1).max(80),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().max(300).optional(),
});

interface EventDoc {
  organizerId: string;
  status: string;
  title: string;
  ageLimit: number;
  perUserLimit: number;
  schedule: { startAt: Timestamp; endAt: Timestamp; doorsOpenAt: Timestamp };
  sale: { startAt: Timestamp; endAt: Timestamp };
  media: { posterUrl: string };
  venue: { name: string };
  cityId: string;
  refundPolicy: unknown;
  slug: string;
}

interface TierDoc {
  name: string;
  pricePaise: number;
  capacity: number;
  admits: number;
  perOrderMax: number;
  sale?: { startAt: Timestamp; endAt: Timestamp };
  status: string;
  sortOrder: number;
}

interface ManualRequestDoc {
  booking_id: string;
  user_id: string;
  organizer_id: string;
  event_id: string;
  status: string;
  total_amount: number;
}

const HOLD_MINUTES = 10;

export const submitRazorpayPayment = miloOnCall(
  { rateLimit: { key: 'razorpayPayment', limit: 20, windowMs: 60 * 60 * 1000 } },
  async (req) => {
    const ctx = requireAuth(req);
    const data = (req.data ?? {}) as Record<string, unknown>;
    const input = submitManualPaymentSchema.parse({ ...data, method: 'RAZORPAY' });
    const now = new Date();

    const [publicConfig, feesConfig] = await Promise.all([getPublicConfig(), getFeesConfig()]);
    if (publicConfig.featureFlags.bookings === false) {
      fail('FEATURE_DISABLED', 'Bookings are temporarily paused. Please try again shortly.');
    }

    if (input.idempotencyKey) {
      const existing = await db()
        .collection('bookings')
        .where('userId', '==', ctx.uid)
        .where('idempotencyKey', '==', input.idempotencyKey)
        .limit(1)
        .get();
      if (!existing.empty) {
        const doc = existing.docs[0]!;
        return {
          bookingId: doc.id,
          requestId: doc.data().manualRequestId ?? '',
          refCode: doc.data().refCode ?? '',
          pricing: doc.data().pricing,
          replayed: true,
        };
      }
    }

    const eventSnap = await db().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists) fail('NOT_FOUND', 'This event is no longer available.');
    const event = eventSnap.data() as EventDoc;

    if (event.status !== 'live') {
      if (event.status === 'sold_out') fail('SOLD_OUT', 'This event is sold out.');
      if (event.status === 'completed') fail('EVENT_ENDED', 'This event has already ended.');
      if (event.status === 'cancelled') fail('EVENT_ENDED', 'This event was cancelled.');
      fail('EVENT_NOT_ON_SALE', 'Tickets are not on sale for this event.');
    }

    if (event.sale?.startAt && event.sale.startAt.toMillis() > now.getTime()) {
      fail('EVENT_NOT_ON_SALE', 'Ticket sales have not started yet.');
    }
    if (event.sale?.endAt && event.sale.endAt.toMillis() < now.getTime()) {
      fail('EVENT_NOT_ON_SALE', 'Ticket sales have closed for this event.');
    }

    const userSnap = await db().collection('users').doc(ctx.uid).get();
    const user = userSnap.data();
    if (!user?.dob) fail('INVALID_INPUT', 'Complete your profile before booking tickets.');
    const dob = user.dob as Timestamp;
    const eventAgeLimit = Number(event.ageLimit ?? 0);
    const requiredAge = Math.max(MIN_AGE, eventAgeLimit);
    if (!isAtLeastAge(dob.toDate(), requiredAge, now)) {
      fail(
        'AGE_RESTRICTED',
        eventAgeLimit > 0
          ? `This event is ${eventAgeLimit}+ only.`
          : 'Milo is for users aged 18 and above.',
      );
    }

    const tierSnap = await db()
      .collection('events')
      .doc(input.eventId)
      .collection('ticketTiers')
      .doc(input.tierId)
      .get();
    if (!tierSnap.exists) fail('NOT_FOUND', 'This ticket is no longer available.');
    const tier = tierSnap.data() as TierDoc;
    if (tier.status !== 'active') fail('NOT_FOUND', 'This ticket is no longer available.');
    if (tier.sale?.startAt && tier.sale.startAt.toMillis() > now.getTime()) {
      fail('EVENT_NOT_ON_SALE', 'Sales for this ticket have not started.');
    }
    if (tier.sale?.endAt && tier.sale.endAt.toMillis() < now.getTime()) {
      fail('EVENT_NOT_ON_SALE', 'Sales for this ticket have closed.');
    }

    const alreadyBought = await db()
      .collection('bookings')
      .where('userId', '==', ctx.uid)
      .where('eventId', '==', input.eventId)
      .where('status', 'in', ['confirmed', 'pending_payment', 'pending_approval', 'completed'])
      .get();
    const alreadyQty = alreadyBought.docs.reduce((sum, doc) => {
      const items = (doc.data().items ?? []) as Array<{ qty: number }>;
      return sum + items.reduce((s, item) => s + item.qty, 0);
    }, 0);

    const remainingUserAllowance = Math.max(0, (event.perUserLimit ?? 4) - alreadyQty);
    if (input.quantity > remainingUserAllowance) {
      fail('LIMIT_EXCEEDED', `You can book up to ${event.perUserLimit ?? 4} tickets per event.`);
    }
    const maxQty = Math.min(tier.perOrderMax ?? 10, remainingUserAllowance);
    if (input.quantity > maxQty) {
      fail('LIMIT_EXCEEDED', `You can buy up to ${maxQty} of "${tier.name}" per order.`);
    }

    const lines: PricingLine[] = [
      {
        tierId: input.tierId,
        tierName: tier.name,
        qty: input.quantity,
        unitPaise: tier.pricePaise,
        admits: tier.admits ?? 1,
      },
    ];
    const pricing = computePricing({
      lines,
      promoDiscountPaise: 0,
      platformFeePct: feesConfig.platformFeePct,
      gstPct: feesConfig.gstPct,
      feeBearer: feesConfig.feeBearer,
      freeTicketFeePaise: feesConfig.freeTicketFeePaise,
    });

    await ensureShards(input.eventId, input.tierId, tier.capacity);
    const allocations = await reserveInventory(input.eventId, input.tierId, input.quantity);

    try {
      const bookingId = newId('bk');
      const requestId = newId('prq');
      const refCode = await nextBookingRef();
      await bindBookingRef(refCode, bookingId);

      const reservationExpiresAt = Timestamp.fromMillis(now.getTime() + HOLD_MINUTES * 60 * 1000);
      const bookingRef = db().collection('bookings').doc(bookingId);
      const requestRef = db().collection('payment_requests').doc(requestId);

      const batch = db().batch();
      batch.set(bookingRef, {
        schemaVersion: 1,
        refCode,
        userId: ctx.uid,
        eventId: input.eventId,
        organizerId: event.organizerId,
        cityId: event.cityId,
        eventSnapshot: {
          title: event.title,
          startAt: event.schedule.startAt,
          venueName: event.venue?.name ?? '',
          posterUrl: event.media?.posterUrl ?? '',
        },
        items: [
          {
            tierId: input.tierId,
            tierName: tier.name,
            qty: input.quantity,
            unitPaise: tier.pricePaise,
            admits: tier.admits ?? 1,
            holderNames: null,
          },
        ],
        pricing: {
          subtotalPaise: pricing.subtotalPaise,
          discountPaise: pricing.discountPaise,
          platformFeePaise: pricing.platformFeePaise,
          gstOnFeePaise: pricing.gstOnFeePaise,
          totalPaise: pricing.totalPaise,
          currency: 'INR',
          feeBearer: pricing.feeBearer,
          feePct: pricing.feePct,
          gstPct: pricing.gstPct,
        },
        promo: null,
        referral: null,
        payment: {
          provider: 'razorpay',
          method: 'RAZORPAY',
          utr: input.utr,
          organizerUpiId: null,
          proofUrl: null,
          note: input.note ?? null,
          status: 'captured',
        },
        status: 'confirmed',
        reservationExpiresAt,
        reservation: { shards: allocations },
        ticketIds: [],
        contactEmail: user.email ?? null,
        idempotencyKey: input.idempotencyKey ?? null,
        manualRequestId: requestId,
        confirmedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      batch.set(requestRef, {
        schemaVersion: 1,
        booking_id: bookingId,
        user_id: ctx.uid,
        organizer_id: event.organizerId,
        event_id: input.eventId,
        event_title: event.title,
        tier_id: input.tierId,
        tier_name: tier.name,
        quantity: input.quantity,
        total_amount: pricing.totalPaise / 100,
        attendee_name: input.attendeeName,
        attendee_phone: input.attendeePhone,
        utr_number: input.utr,
        organizer_upi_id: '',
        proof_image_url: '',
        note: input.note ?? '',
        payment_method: 'RAZORPAY',
        status: 'APPROVED',
        auto_approved: true,
        reviewed_by: 'system',
        reviewed_at: FieldValue.serverTimestamp(),
        reservation_expires_at: reservationExpiresAt,
        created_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      });
      await batch.commit();

      try {
        const userSnap2 = await db().collection('users').doc(ctx.uid).get();
        const user2 = userSnap2.data() ?? {};
        const ticketIds: string[] = [];
        const ticketDocs: Array<{ id: string; data: Record<string, unknown> }> = [];
        const secretDocs: Array<{ id: string; data: Record<string, unknown> }> = [];
        let seq = 1;
        for (let qi = 0; qi < input.quantity; qi += 1) {
          const ticketId = `tk_${randomBytes(9).toString('hex')}`;
          ticketIds.push(ticketId);
          ticketDocs.push({
            id: ticketId,
            data: {
              schemaVersion: 1,
              bookingId,
              refCode,
              userId: ctx.uid,
              eventId: input.eventId,
              organizerId: event.organizerId,
              tierId: input.tierId,
              tierName: tier.name,
              eventStartAt: event.schedule.startAt,
              eventTitle: event.title,
              seq,
              admits: tier.admits ?? 1,
              holderName: input.attendeeName,
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
        const attendeeRef = db().collection('eventAttendees').doc(`${input.eventId}_${ctx.uid}`);
        const batch2 = db().batch();
        batch2.update(bookingRef, { ticketIds, updatedAt: FieldValue.serverTimestamp() });
        for (const doc of ticketDocs) batch2.set(db().collection('tickets').doc(doc.id), doc.data);
        for (const doc of secretDocs) batch2.set(db().collection('ticketSecrets').doc(doc.id), doc.data);
        batch2.set(attendeeRef, {
          schemaVersion: 1,
          eventId: input.eventId,
          uid: ctx.uid,
          ticketCount: FieldValue.increment(ticketIds.length),
          firstTicketAt: FieldValue.serverTimestamp(),
          radarOptIn: false,
          incognito: user2.privacy?.incognito === true,
        }, { merge: true });
        await batch2.commit();
        await confirmInventory(input.eventId, allocations).catch(() => undefined);
        await recordConfirmedBooking({
          eventId: input.eventId,
          bookingId,
          lines: [{ tierId: input.tierId, qty: input.quantity, unitPaise: tier.pricePaise }],
          grossPaise: pricing.subtotalPaise,
          discountPaise: pricing.discountPaise,
          platformFeePaise: pricing.platformFeePaise,
          gstOnFeePaise: pricing.gstOnFeePaise,
          feeBearer: pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer',
        }).catch(() => undefined);
        await notifyUser(ctx.uid, 'booking_confirmed', 'Booking Confirmed', `Your tickets for ${event.title} are ready.`, { deepLink: `/booking/${bookingId}`, channel: 'bookings' }).catch(() => undefined);
      } catch (e) {
        console.error('razorpay auto-issue error', e);
      }

      return {
        bookingId,
        requestId,
        refCode,
        pricing,
        reservationExpiresAt: reservationExpiresAt.toDate().toISOString(),
        status: 'confirmed',
      };
    } catch (err) {
      await releaseInventory(input.eventId, allocations).catch(() => undefined);
      throw err;
    }
  },
);

export const reviewManualPayment = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = reviewManualPaymentSchema.parse(req.data);
  const isAdmin = (ctx.token as Record<string, unknown>).admin === true;

  const requestRef = db().collection('payment_requests').doc(input.requestId);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) fail('NOT_FOUND', 'Payment request not found.');
  const request = requestSnap.data() as ManualRequestDoc;

  if (!isAdmin && request.organizer_id !== ctx.uid) {
    fail('FORBIDDEN', 'Only the event organizer can review this payment.');
  }
  if (request.status !== 'PENDING') {
    fail('CONFLICT', 'This payment request has already been reviewed.');
  }

  const bookingRef = db().collection('bookings').doc(request.booking_id);
  const bookingSnap = await bookingRef.get();
  if (!bookingSnap.exists) fail('NOT_FOUND', 'Booking not found.');
  const booking = bookingSnap.data()!;
  const allocations = (booking.reservation?.shards ?? []) as ShardAllocation[];

  if (input.decision === 'reject') {
    await db()
      .runTransaction(async (tx) => {
        const [freshRequest, freshBooking] = await Promise.all([tx.get(requestRef), tx.get(bookingRef)]);
        if (freshRequest.data()?.status !== 'PENDING') {
          throw new Error('ALREADY_REVIEWED');
        }
        if (freshBooking.data()?.status !== 'pending_approval') {
          throw new Error('BOOKING_NOT_PENDING');
        }
        tx.update(requestRef, {
          status: 'REJECTED',
          rejection_reason: input.reason ?? 'Payment could not be verified.',
          reviewed_by: ctx.uid,
          reviewed_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        });
        tx.update(bookingRef, {
          status: 'rejected',
          payment: { ...(freshBooking.data()?.payment ?? {}), status: 'rejected' },
          rejectionReason: input.reason ?? 'Payment could not be verified.',
          updatedAt: FieldValue.serverTimestamp(),
        });
      })
      .catch((err) => {
        if (err instanceof Error && err.message === 'ALREADY_REVIEWED') {
          fail('CONFLICT', 'This payment request has already been reviewed.');
        }
        if (err instanceof Error && err.message === 'BOOKING_NOT_PENDING') {
          fail('CONFLICT', 'This booking can no longer be rejected.');
        }
        throw err;
      });
    await releaseInventory(String(booking.eventId), allocations).catch(() => undefined);
    await notifyUser(
      String(booking.userId),
      'payment_rejected',
      'Payment not verified',
      input.reason ?? 'The organizer could not verify your payment. Please contact support.',
      { deepLink: `/booking/${request.booking_id}`, channel: 'bookings' },
    ).catch(() => undefined);
    return { ok: true, status: 'REJECTED' };
  }

  const reservationExpiresAt = booking.reservationExpiresAt as Timestamp | undefined;
  if (reservationExpiresAt && reservationExpiresAt.toMillis() < Date.now()) {
    fail('HOLD_EXPIRED', 'This payment hold has expired. Please ask the attendee to book again.');
  }

  const items = (booking.items ?? []) as Array<{
    tierId: string;
    tierName: string;
    qty: number;
    unitPaise: number;
    admits: number;
    holderNames?: string[] | null;
  }>;
  const userSnap = await db().collection('users').doc(String(booking.userId)).get();
  const user = userSnap.data() ?? {};

  const ticketIds: string[] = [];
  const ticketDocs: Array<{ id: string; data: Record<string, unknown> }> = [];
  const secretDocs: Array<{ id: string; data: Record<string, unknown> }> = [];

  let seq = 1;
  for (const item of items) {
    for (let i = 0; i < item.qty; i += 1) {
      const ticketId = `tk_${randomBytes(9).toString('hex')}`;
      ticketIds.push(ticketId);
      ticketDocs.push({
        id: ticketId,
        data: {
          schemaVersion: 1,
          bookingId: request.booking_id,
          refCode: booking.refCode,
          userId: booking.userId,
          eventId: booking.eventId,
          organizerId: booking.organizerId,
          tierId: item.tierId,
          tierName: item.tierName,
          eventStartAt: booking.eventSnapshot?.startAt ?? null,
          eventTitle: booking.eventSnapshot?.title ?? '',
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

  const attendeeRef = db().collection('eventAttendees').doc(`${booking.eventId}_${booking.userId}`);

  await db().runTransaction(async (tx) => {
    const [freshRequest, freshBooking, freshAttendee] = await Promise.all([
      tx.get(requestRef),
      tx.get(bookingRef),
      tx.get(attendeeRef),
    ]);
    if (freshRequest.data()?.status !== 'PENDING') {
      throw new Error('ALREADY_REVIEWED');
    }
    if (freshBooking.data()?.status !== 'pending_approval') {
      throw new Error('BOOKING_NOT_PENDING');
    }

    tx.update(requestRef, {
      status: 'APPROVED',
      reviewed_by: ctx.uid,
      reviewed_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });
    tx.update(bookingRef, {
      status: 'confirmed',
      payment: {
        ...(freshBooking.data()?.payment ?? {}),
        status: 'captured',
        reviewedBy: ctx.uid,
      },
      confirmedAt: FieldValue.serverTimestamp(),
      ticketIds,
      updatedAt: FieldValue.serverTimestamp(),
    });
    for (const doc of ticketDocs) tx.set(db().collection('tickets').doc(doc.id), doc.data);
    for (const doc of secretDocs) tx.set(db().collection('ticketSecrets').doc(doc.id), doc.data);
    const existingAttendee = freshAttendee.data();
    tx.set(
      attendeeRef,
      {
        schemaVersion: 1,
        eventId: booking.eventId,
        uid: booking.userId,
        ticketCount: FieldValue.increment(ticketIds.length),
        firstTicketAt: existingAttendee?.firstTicketAt ?? FieldValue.serverTimestamp(),
        radarOptIn: existingAttendee?.radarOptIn ?? false,
        incognito: user.privacy?.incognito === true,
      },
      { merge: true },
    );
  }).catch((err) => {
    if (err instanceof Error && err.message === 'ALREADY_REVIEWED') {
      fail('CONFLICT', 'This payment request has already been reviewed.');
    }
    if (err instanceof Error && err.message === 'BOOKING_NOT_PENDING') {
      fail('CONFLICT', 'This booking can no longer be approved.');
    }
    throw err;
  });

  await confirmInventory(String(booking.eventId), allocations).catch(() => undefined);

  const pricing = (booking.pricing ?? {}) as Record<string, number | string>;
  await recordConfirmedBooking({
    eventId: String(booking.eventId),
    bookingId: request.booking_id,
    lines: items.map((item) => ({ tierId: item.tierId, qty: item.qty, unitPaise: item.unitPaise })),
    grossPaise: Number(pricing.subtotalPaise ?? 0),
    discountPaise: Number(pricing.discountPaise ?? 0),
    platformFeePaise: Number(pricing.platformFeePaise ?? 0),
    gstOnFeePaise: Number(pricing.gstOnFeePaise ?? 0),
    feeBearer: pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer',
  }).catch(() => undefined);

  await notifyUser(
    String(booking.userId),
    'booking_confirmed',
    'Booking confirmed',
    `Your tickets for ${booking.eventSnapshot?.title ?? 'your event'} are confirmed.`,
    { deepLink: `/ticket/${ticketIds[0] ?? ''}`, channel: 'bookings' },
  ).catch(() => undefined);

  return { ok: true, status: 'APPROVED', ticketIds };
});
