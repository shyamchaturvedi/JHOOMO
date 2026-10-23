"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmInventoryForBooking = exports.cancelPendingBooking = exports.applyPromo = exports.createBooking = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const config_1 = require("../shared/config");
const pricing_1 = require("../shared/pricing");
const age_1 = require("../shared/age");
const ids_1 = require("../shared/ids");
const razorpay_1 = require("../shared/razorpay");
const schemas_1 = require("../shared/schemas");
const inventory_1 = require("./inventory");
const promo_1 = require("./promo");
const createBookingSchema = zod_1.z.object({
    eventId: schemas_1.eventIdSchema,
    items: zod_1.z
        .array(zod_1.z.object({
        tierId: schemas_1.tierIdSchema,
        qty: zod_1.z.number().int().min(1).max(20),
        holderNames: zod_1.z.array(zod_1.z.string().trim().min(1).max(60)).max(20).optional(),
    }))
        .min(1)
        .max(10),
    promoCode: schemas_1.promoCodeSchema.optional(),
    referralCode: zod_1.z.string().trim().toUpperCase().min(3).max(24).optional(),
    contactEmail: zod_1.z.string().email().max(160).optional(),
    idempotencyKey: zod_1.z.string().max(80).optional(),
});
exports.createBooking = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = createBookingSchema.parse(req.data);
    const now = new Date();
    const [publicConfig, feesConfig] = await Promise.all([(0, config_1.getPublicConfig)(), (0, config_1.getFeesConfig)()]);
    if (publicConfig.featureFlags.bookings === false) {
        (0, errors_1.fail)('FEATURE_DISABLED', 'Bookings are temporarily paused. Please try again shortly.');
    }
    if (input.idempotencyKey) {
        const existing = await (0, admin_1.db)()
            .collection('bookings')
            .where('userId', '==', ctx.uid)
            .where('idempotencyKey', '==', input.idempotencyKey)
            .limit(1)
            .get();
        if (!existing.empty) {
            const doc = existing.docs[0];
            return { bookingId: doc.id, orderId: doc.data().payment?.orderId, pricing: doc.data().pricing, replayed: true };
        }
    }
    const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'This event is no longer available.');
    const event = eventSnap.data();
    if (event.status !== 'live') {
        if (event.status === 'sold_out')
            (0, errors_1.fail)('SOLD_OUT', 'This event is sold out.');
        if (event.status === 'completed')
            (0, errors_1.fail)('EVENT_ENDED', 'This event has already ended.');
        if (event.status === 'cancelled')
            (0, errors_1.fail)('EVENT_ENDED', 'This event was cancelled.');
        (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Tickets are not on sale for this event.');
    }
    if (event.sale?.startAt && event.sale.startAt.toMillis() > now.getTime()) {
        (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Ticket sales have not started yet.');
    }
    if (event.sale?.endAt && event.sale.endAt.toMillis() < now.getTime()) {
        (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Ticket sales have closed for this event.');
    }
    const userSnap = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const user = userSnap.data();
    if (!user?.dob) {
        (0, errors_1.fail)('INVALID_INPUT', 'Complete your profile before booking tickets.');
    }
    const dob = user.dob;
    if (event.ageLimit > 0 && !(0, age_1.isAtLeastAge)(dob.toDate(), event.ageLimit, now)) {
        (0, errors_1.fail)('AGE_RESTRICTED', `This event is ${event.ageLimit}+ only.`);
    }
    if (event.ageLimit === 0 && !(0, age_1.isAtLeastAge)(dob.toDate(), 18, now)) {
        (0, errors_1.fail)('AGE_RESTRICTED', 'Milo is for users aged 18 and above.');
    }
    const tierDocs = await Promise.all(input.items.map(async (item) => {
        const snap = await (0, admin_1.db)()
            .collection('events')
            .doc(input.eventId)
            .collection('ticketTiers')
            .doc(item.tierId)
            .get();
        return { item, snap };
    }));
    for (const { snap } of tierDocs) {
        if (!snap.exists)
            (0, errors_1.fail)('NOT_FOUND', 'One of the selected tickets no longer exists.');
        const tier = snap.data();
        if (tier.status !== 'active')
            (0, errors_1.fail)('NOT_FOUND', 'One of the selected tickets is unavailable.');
        if (tier.sale?.startAt && tier.sale.startAt.toMillis() > now.getTime()) {
            (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Sales for one of the selected tickets have not started.');
        }
        if (tier.sale?.endAt && tier.sale.endAt.toMillis() < now.getTime()) {
            (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Sales for one of the selected tickets have closed.');
        }
    }
    const alreadyBought = await (0, admin_1.db)()
        .collection('bookings')
        .where('userId', '==', ctx.uid)
        .where('eventId', '==', input.eventId)
        .where('status', 'in', ['confirmed', 'pending_payment', 'completed'])
        .get();
    const alreadyQty = alreadyBought.docs.reduce((sum, d) => {
        const items = (d.data().items ?? []);
        return sum + items.reduce((s, i) => s + i.qty, 0);
    }, 0);
    const requestedQty = input.items.reduce((sum, i) => sum + i.qty, 0);
    const remainingUserAllowance = Math.max(0, (event.perUserLimit ?? 4) - alreadyQty);
    if (requestedQty > remainingUserAllowance) {
        (0, errors_1.fail)('LIMIT_EXCEEDED', `You can book up to ${event.perUserLimit ?? 4} tickets per event.`);
    }
    const lines = [];
    for (const { item, snap } of tierDocs) {
        const tier = snap.data();
        const maxQty = Math.min(tier.perOrderMax ?? 10, remainingUserAllowance);
        if (item.qty > maxQty) {
            (0, errors_1.fail)('LIMIT_EXCEEDED', `You can buy up to ${maxQty} of "${tier.name}" per order.`);
        }
        if (event.namedTickets && item.holderNames && item.holderNames.length !== item.qty) {
            (0, errors_1.fail)('INVALID_INPUT', 'Enter a name for each ticket holder.');
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
    let promoRef;
    let discountPaise = 0;
    if (input.promoCode) {
        const promo = await (0, promo_1.evaluatePromo)({
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
    const pricing = (0, pricing_1.computePricing)({
        lines,
        promoDiscountPaise: discountPaise,
        platformFeePct: feesConfig.platformFeePct,
        gstPct: feesConfig.gstPct,
        feeBearer: feesConfig.feeBearer,
        freeTicketFeePaise: feesConfig.freeTicketFeePaise,
    });
    let referral = null;
    if (input.referralCode) {
        const referralSnap = await (0, admin_1.db)().collection('referralCodes').doc(input.referralCode).get();
        const promoterId = referralSnap.data()?.promoterId;
        if (promoterId && promoterId !== ctx.uid) {
            referral = { code: input.referralCode, promoterId };
        }
    }
    const allocations = [];
    for (const line of lines) {
        const tierSnap = tierDocs.find((t) => t.item.tierId === line.tierId).snap;
        const tier = tierSnap.data();
        await (0, inventory_1.ensureShards)(input.eventId, line.tierId, tier.capacity);
        const alloc = await (0, inventory_1.reserveInventory)(input.eventId, line.tierId, line.qty);
        allocations.push(...alloc);
    }
    try {
        const bookingId = (0, ids_1.newId)('bk');
        const refCode = await (0, ids_1.nextBookingRef)();
        await (0, ids_1.bindBookingRef)(refCode, bookingId);
        const order = await (0, razorpay_1.createOrder)({
            amountPaise: pricing.totalPaise,
            receipt: bookingId,
            notes: { bookingId, eventId: input.eventId, userId: ctx.uid },
        });
        const holdMinutes = publicConfig.holdMinutes ?? 10;
        const reservationExpiresAt = firestore_1.Timestamp.fromMillis(now.getTime() + holdMinutes * 60 * 1000);
        const bookingRef = (0, admin_1.db)().collection('bookings').doc(bookingId);
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
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return {
            bookingId,
            refCode,
            orderId: order.id,
            pricing,
            reservationExpiresAt: reservationExpiresAt.toDate().toISOString(),
            holdMinutes,
        };
    }
    catch (err) {
        await (0, inventory_1.releaseInventory)(input.eventId, allocations).catch(() => undefined);
        throw err;
    }
});
const applyPromoSchema = zod_1.z.object({
    bookingId: zod_1.z.string().min(1).max(64),
    promoCode: schemas_1.promoCodeSchema,
});
exports.applyPromo = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = applyPromoSchema.parse(req.data);
    const bookingRef = (0, admin_1.db)().collection('bookings').doc(input.bookingId);
    const snap = await bookingRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Booking not found.');
    const booking = snap.data();
    if (booking.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This booking belongs to another account.');
    if (booking.status !== 'pending_payment') {
        (0, errors_1.fail)('CONFLICT', 'Promo codes can only be applied before payment.');
    }
    const reservationExpiresAt = booking.reservationExpiresAt;
    if (reservationExpiresAt && reservationExpiresAt.toMillis() < Date.now()) {
        (0, errors_1.fail)('HOLD_EXPIRED', 'Your booking hold has expired. Please start again.');
    }
    const lines = (booking.items ?? []);
    const subtotalPaise = lines.reduce((sum, l) => sum + l.unitPaise * l.qty, 0);
    const feesConfig = await (0, config_1.getFeesConfig)();
    const promo = await (0, promo_1.evaluatePromo)({
        code: input.promoCode,
        eventId: booking.eventId,
        userId: ctx.uid,
        lines,
        subtotalPaise,
    });
    const pricing = (0, pricing_1.computePricing)({
        lines,
        promoDiscountPaise: promo.discountPaise,
        platformFeePct: feesConfig.platformFeePct,
        gstPct: feesConfig.gstPct,
        feeBearer: feesConfig.feeBearer,
        freeTicketFeePaise: feesConfig.freeTicketFeePaise,
    });
    const previousOrderId = booking.payment?.orderId;
    const order = await (0, razorpay_1.createOrder)({
        amountPaise: pricing.totalPaise,
        receipt: booking.id,
        notes: { bookingId: booking.id, eventId: booking.eventId, userId: ctx.uid },
    });
    if (previousOrderId && previousOrderId !== order.id) {
        await (0, razorpay_1.cancelOrder)(previousOrderId).catch(() => undefined);
    }
    await bookingRef.set({
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
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { pricing, orderId: order.id };
});
exports.cancelPendingBooking = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ bookingId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const bookingRef = (0, admin_1.db)().collection('bookings').doc(input.bookingId);
    const snap = await bookingRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Booking not found.');
    const booking = snap.data();
    if (booking.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This booking belongs to another account.');
    if (booking.status !== 'pending_payment') {
        (0, errors_1.fail)('CONFLICT', 'This booking can no longer be cancelled.');
    }
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const fresh = await tx.get(bookingRef);
        if (fresh.data()?.status !== 'pending_payment') {
            throw new errors_1.MiloError('CONFLICT', 'This booking can no longer be cancelled.');
        }
        tx.update(bookingRef, {
            status: 'cancelled_by_user',
            cancelledAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
    });
    const allocations = (booking.reservation?.shards ?? []);
    await (0, inventory_1.releaseInventory)(booking.eventId, allocations).catch(() => undefined);
    return { ok: true };
});
const confirmInventoryForBooking = async (eventId, allocations) => {
    await (0, inventory_1.confirmInventory)(eventId, allocations);
};
exports.confirmInventoryForBooking = confirmInventoryForBooking;
//# sourceMappingURL=booking.js.map