import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail, MiloError } from '../shared/errors';
import { getFeesConfig, getPublicConfig } from '../shared/config';
import { computePricing, PricingLine } from '../shared/pricing';
import { isAtLeastAge, MIN_AGE } from '../shared/age';
import { bindBookingRef, newId, nextBookingRef } from '../shared/ids';
import { createOrder, cancelOrder } from '../shared/razorpay';
import { eventIdSchema, promoCodeSchema, tierIdSchema } from '../shared/schemas';
import { confirmInventory, ensureShards, releaseInventory, reserveInventory } from './inventory';
import { evaluatePromo } from './promo';

const createBookingSchema = z.object({
  eventId: eventIdSchema,
  items: z
    .array(
      z.object({
        tierId: tierIdSchema,
        qty: z.number().int().min(1).max(20),
        holderNames: z.array(z.string().trim().min(1).max(60)).max(20).optional(),
      }),
    )
    .min(1)
    .max(10),
  promoCode: promoCodeSchema.optional(),
  referralCode: z.string().trim().toUpperCase().min(3).max(24).optional(),
  contactEmail: z.string().email().max(160).optional(),
  idempotencyKey: z.string().max(80).optional(),
});

interface EventDoc {
  organizerId: string;
  status: string;
  title: string;
  ageLimit: number;
  perUserLimit: number;
  namedTickets: boolean;
  schedule: { startAt: Timestamp; endAt: Timestamp; doorsOpenAt: Timestamp };
  sale: { startAt: Timestamp; endAt: Timestamp };
  media: { posterUrl: string };
  venue: { name: string };
  cityId: string;
  promo?: { enabled: boolean };
  promoter?: { enabled: boolean; commissionPct: number };
  refundPolicy: unknown;
  slug: string;
}

interface TierDoc {
  name: string;
  type: string;
  pricePaise: number;
  capacity: number;
  admits: number;
  perOrderMax: number;
  sale?: { startAt: Timestamp; endAt: Timestamp };
  status: string;
  sortOrder: number;
}

export const createBooking = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = createBookingSchema.parse(req.data);
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
      return { bookingId: doc.id, orderId: doc.data().payment?.orderId, pricing: doc.data().pricing, replayed: true };
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
  if (!user?.dob) {
    fail('INVALID_INPUT', 'Complete your profile before booking tickets.');
  }
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

  const tierDocs = await Promise.all(
    input.items.map(async (item) => {
      const snap = await db()
        .collection('events')
        .doc(input.eventId)
        .collection('ticketTiers')
        .doc(item.tierId)
        .get();
      return { item, snap };
    }),
  );

  for (const { snap } of tierDocs) {
    if (!snap.exists) fail('NOT_FOUND', 'One of the selected tickets no longer exists.');
    const tier = snap.data() as TierDoc;
    if (tier.status !== 'active') fail('NOT_FOUND', 'One of the selected tickets is unavailable.');
    if (tier.sale?.startAt && tier.sale.startAt.toMillis() > now.getTime()) {
      fail('EVENT_NOT_ON_SALE', 'Sales for one of the selected tickets have not started.');
    }
    if (tier.sale?.endAt && tier.sale.endAt.toMillis() < now.getTime()) {
      fail('EVENT_NOT_ON_SALE', 'Sales for one of the selected tickets have closed.');
    }
  }

  const alreadyBought = await db()
    .collection('bookings')
    .where('userId', '==', ctx.uid)
    .where('eventId', '==', input.eventId)
    .where('status', 'in', ['confirmed', 'pending_payment', 'completed'])
    .get();
  const alreadyQty = alreadyBought.docs.reduce((sum, d) => {
    const items = (d.data().items ?? []) as Array<{ qty: number }>;
    return sum + items.reduce((s, i) => s + i.qty, 0);
  }, 0);

  const requestedQty = input.items.reduce((sum, i) => sum + i.qty, 0);
  const remainingUserAllowance = Math.max(0, (event.perUserLimit ?? 4) - alreadyQty);
  if (requestedQty > remainingUserAllowance) {
    fail('LIMIT_EXCEEDED', `You can book up to ${event.perUserLimit ?? 4} tickets per event.`);
  }

  const lines: PricingLine[] = [];
  for (const { item, snap } of tierDocs) {
    const tier = snap.data() as TierDoc;
    const maxQty = Math.min(tier.perOrderMax ?? 10, remainingUserAllowance);
    if (item.qty > maxQty) {
      fail('LIMIT_EXCEEDED', `You can buy up to ${maxQty} of "${tier.name}" per order.`);
    }
    if (event.namedTickets && item.holderNames && item.holderNames.length !== item.qty) {
      fail('INVALID_INPUT', 'Enter a name for each ticket holder.');
    }
    lines.push({
      tierId: item.tierId,
      tierName: tier.name,
      qty: item.qty,
      unitPaise: tier.pricePaise,
      admits: tier.admits ?? 1,
      holderNames: item.holderNames,
    });
  }

  const subtotalPaise = lines.reduce((sum, l) => sum + l.unitPaise * l.qty, 0);

  let promoRef: { code: string; type: string; valuePaise: number; fundedBy: string; docId: string } | undefined;
  let discountPaise = 0;
  if (input.promoCode) {
    const promo = await evaluatePromo({
      code: input.promoCode,
      eventId: input.eventId,
      userId: ctx.uid,
      lines,
      subtotalPaise,
      now,
    });
    discountPaise = promo.discountPaise;
    promoRef = {
      code: promo.doc.code,
      type: promo.doc.type,
      valuePaise: promo.discountPaise,
      fundedBy: promo.fundedBy,
      docId: promo.docId,
    };
  }

  const pricing = computePricing({
    lines,
    promoDiscountPaise: discountPaise,
    platformFeePct: feesConfig.platformFeePct,
    gstPct: feesConfig.gstPct,
    feeBearer: feesConfig.feeBearer,
    freeTicketFeePaise: feesConfig.freeTicketFeePaise,
  });

  let referral: { code: string; promoterId: string } | null = null;
  if (input.referralCode) {
    const referralSnap = await db().collection('referralCodes').doc(input.referralCode).get();
    const promoterId = referralSnap.data()?.promoterId as string | undefined;
    if (promoterId && promoterId !== ctx.uid) {
      referral = { code: input.referralCode, promoterId };
    }
  }

  const allocations = [];
  for (const line of lines) {
    const tierSnap = tierDocs.find((t) => t.item.tierId === line.tierId)!.snap;
    const tier = tierSnap.data() as TierDoc;
    await ensureShards(input.eventId, line.tierId, tier.capacity);
    const alloc = await reserveInventory(input.eventId, line.tierId, line.qty);
    allocations.push(...alloc);
  }

  try {
    const bookingId = newId('bk');
    const refCode = await nextBookingRef();
    await bindBookingRef(refCode, bookingId);

    const order = await createOrder({
      amountPaise: pricing.totalPaise,
      receipt: bookingId,
      notes: { bookingId, eventId: input.eventId, userId: ctx.uid },
    });

    const holdMinutes = publicConfig.holdMinutes ?? 10;
    const reservationExpiresAt = Timestamp.fromMillis(now.getTime() + holdMinutes * 60 * 1000);

    const bookingRef = db().collection('bookings').doc(bookingId);
    await bookingRef.set({
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
      items: lines.map((l) => ({
        tierId: l.tierId,
        tierName: l.tierName,
        qty: l.qty,
        unitPaise: l.unitPaise,
        admits: l.admits,
        holderNames: l.holderNames ?? null,
      })),
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
      promo: promoRef
        ? {
            code: promoRef.code,
            type: promoRef.type,
            valuePaise: promoRef.valuePaise,
            fundedBy: promoRef.fundedBy,
            docId: promoRef.docId,
          }
        : null,
      referral,
      payment: { provider: 'razorpay', orderId: order.id, status: 'created' },
      status: 'pending_payment',
      reservationExpiresAt,
      reservation: { shards: allocations },
      ticketIds: [],
      contactEmail: input.contactEmail ?? null,
      idempotencyKey: input.idempotencyKey ?? null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      bookingId,
      refCode,
      orderId: order.id,
      pricing,
      reservationExpiresAt: reservationExpiresAt.toDate().toISOString(),
      holdMinutes,
    };
  } catch (err) {
    await releaseInventory(input.eventId, allocations).catch(() => undefined);
    throw err;
  }
});

const applyPromoSchema = z.object({
  bookingId: z.string().min(1).max(64),
  promoCode: promoCodeSchema,
});

export const applyPromo = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = applyPromoSchema.parse(req.data);

  const bookingRef = db().collection('bookings').doc(input.bookingId);
  const snap = await bookingRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Booking not found.');
  const booking = snap.data()!;
  if (booking.userId !== ctx.uid) fail('FORBIDDEN', 'This booking belongs to another account.');
  if (booking.status !== 'pending_payment') {
    fail('CONFLICT', 'Promo codes can only be applied before payment.');
  }

  const reservationExpiresAt = booking.reservationExpiresAt as Timestamp | undefined;
  if (reservationExpiresAt && reservationExpiresAt.toMillis() < Date.now()) {
    fail('HOLD_EXPIRED', 'Your booking hold has expired. Please start again.');
  }

  const lines = (booking.items ?? []) as Array<{
    tierId: string;
    tierName: string;
    qty: number;
    unitPaise: number;
    admits: number;
  }>;
  const subtotalPaise = lines.reduce((sum, l) => sum + l.unitPaise * l.qty, 0);
  const feesConfig = await getFeesConfig();

  const promo = await evaluatePromo({
    code: input.promoCode,
    eventId: booking.eventId,
    userId: ctx.uid,
    lines,
    subtotalPaise,
  });

  const pricing = computePricing({
    lines,
    promoDiscountPaise: promo.discountPaise,
    platformFeePct: feesConfig.platformFeePct,
    gstPct: feesConfig.gstPct,
    feeBearer: feesConfig.feeBearer,
    freeTicketFeePaise: feesConfig.freeTicketFeePaise,
  });

  const previousOrderId = booking.payment?.orderId as string | undefined;

  const order = await createOrder({
    amountPaise: pricing.totalPaise,
    receipt: booking.id,
    notes: { bookingId: booking.id, eventId: booking.eventId, userId: ctx.uid },
  });

  if (previousOrderId && previousOrderId !== order.id) {
    await cancelOrder(previousOrderId).catch(() => undefined);
  }

  await bookingRef.set(
    {
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
      promo: {
        code: promo.doc.code,
        type: promo.doc.type,
        valuePaise: promo.discountPaise,
        fundedBy: promo.fundedBy,
        docId: promo.docId,
      },
      payment: { ...(booking.payment ?? {}), orderId: order.id, status: 'created' },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { pricing, orderId: order.id };
});

export const cancelPendingBooking = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ bookingId: z.string().min(1).max(64) }).parse(req.data);

  const bookingRef = db().collection('bookings').doc(input.bookingId);
  const snap = await bookingRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Booking not found.');
  const booking = snap.data()!;
  if (booking.userId !== ctx.uid) fail('FORBIDDEN', 'This booking belongs to another account.');
  if (booking.status !== 'pending_payment') {
    fail('CONFLICT', 'This booking can no longer be cancelled.');
  }

  await db().runTransaction(async (tx) => {
    const fresh = await tx.get(bookingRef);
    if (fresh.data()?.status !== 'pending_payment') {
      throw new MiloError('CONFLICT', 'This booking can no longer be cancelled.');
    }
    tx.update(bookingRef, {
      status: 'cancelled_by_user',
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const allocations = (booking.reservation?.shards ?? []) as Array<{ tierId: string; shard: string; qty: number }>;
  await releaseInventory(booking.eventId, allocations).catch(() => undefined);

  return { ok: true };
});

export const confirmInventoryForBooking = async (
  eventId: string,
  allocations: Array<{ tierId: string; shard: string; qty: number }>,
): Promise<void> => {
  await confirmInventory(eventId, allocations);
};
