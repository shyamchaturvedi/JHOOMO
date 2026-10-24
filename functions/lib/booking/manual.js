"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.reviewManualPayment = exports.submitManualPayment = void 0;
const firestore_1 = require("firebase-admin/firestore");
const node_crypto_1 = require("node:crypto");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const config_1 = require("../shared/config");
const pricing_1 = require("../shared/pricing");
const age_1 = require("../shared/age");
const ids_1 = require("../shared/ids");
const schemas_1 = require("../shared/schemas");
const notify_1 = require("../shared/notify");
const finance_1 = require("../settlement/finance");
const inventory_1 = require("./inventory");
const submitManualPaymentSchema = zod_1.z.object({
    eventId: schemas_1.eventIdSchema,
    tierId: schemas_1.tierIdSchema,
    quantity: zod_1.z.number().int().min(1).max(20),
    method: zod_1.z.enum(['TEST_GATEWAY']),
    utr: zod_1.z.string().trim().min(4).max(80),
    attendeeName: zod_1.z.string().trim().min(1).max(80),
    attendeePhone: zod_1.z.string().trim().min(6).max(20),
    organizerUpiId: zod_1.z.string().trim().max(120).optional(),
    proofUrl: zod_1.z.string().trim().url().max(600).optional(),
    note: zod_1.z.string().trim().max(500).optional(),
    idempotencyKey: zod_1.z.string().max(80).optional(),
});
const reviewManualPaymentSchema = zod_1.z.object({
    requestId: zod_1.z.string().min(1).max(80),
    decision: zod_1.z.enum(['approve', 'reject']),
    reason: zod_1.z.string().trim().max(300).optional(),
});
const HOLD_HOURS = 72;
exports.submitManualPayment = (0, callable_1.miloOnCall)({ rateLimit: { key: 'manualPayment', limit: 20, windowMs: 60 * 60 * 1000 } }, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = submitManualPaymentSchema.parse(req.data);
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
            return {
                bookingId: doc.id,
                requestId: doc.data().manualRequestId ?? '',
                refCode: doc.data().refCode ?? '',
                pricing: doc.data().pricing,
                replayed: true,
            };
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
    if (!user?.dob)
        (0, errors_1.fail)('INVALID_INPUT', 'Complete your profile before booking tickets.');
    const dob = user.dob;
    const eventAgeLimit = Number(event.ageLimit ?? 0);
    const requiredAge = Math.max(age_1.MIN_AGE, eventAgeLimit);
    if (!(0, age_1.isAtLeastAge)(dob.toDate(), requiredAge, now)) {
        (0, errors_1.fail)('AGE_RESTRICTED', eventAgeLimit > 0
            ? `This event is ${eventAgeLimit}+ only.`
            : 'Milo is for users aged 18 and above.');
    }
    const tierSnap = await (0, admin_1.db)()
        .collection('events')
        .doc(input.eventId)
        .collection('ticketTiers')
        .doc(input.tierId)
        .get();
    if (!tierSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'This ticket is no longer available.');
    const tier = tierSnap.data();
    if (tier.status !== 'active')
        (0, errors_1.fail)('NOT_FOUND', 'This ticket is no longer available.');
    if (tier.sale?.startAt && tier.sale.startAt.toMillis() > now.getTime()) {
        (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Sales for this ticket have not started.');
    }
    if (tier.sale?.endAt && tier.sale.endAt.toMillis() < now.getTime()) {
        (0, errors_1.fail)('EVENT_NOT_ON_SALE', 'Sales for this ticket have closed.');
    }
    const alreadyBought = await (0, admin_1.db)()
        .collection('bookings')
        .where('userId', '==', ctx.uid)
        .where('eventId', '==', input.eventId)
        .where('status', 'in', ['confirmed', 'pending_payment', 'pending_approval', 'completed'])
        .get();
    const alreadyQty = alreadyBought.docs.reduce((sum, doc) => {
        const items = (doc.data().items ?? []);
        return sum + items.reduce((s, item) => s + item.qty, 0);
    }, 0);
    const remainingUserAllowance = Math.max(0, (event.perUserLimit ?? 4) - alreadyQty);
    if (input.quantity > remainingUserAllowance) {
        (0, errors_1.fail)('LIMIT_EXCEEDED', `You can book up to ${event.perUserLimit ?? 4} tickets per event.`);
    }
    const maxQty = Math.min(tier.perOrderMax ?? 10, remainingUserAllowance);
    if (input.quantity > maxQty) {
        (0, errors_1.fail)('LIMIT_EXCEEDED', `You can buy up to ${maxQty} of "${tier.name}" per order.`);
    }
    const lines = [
        {
            tierId: input.tierId,
            tierName: tier.name,
            qty: input.quantity,
            unitPaise: tier.pricePaise,
            admits: tier.admits ?? 1,
        },
    ];
    const pricing = (0, pricing_1.computePricing)({
        lines,
        promoDiscountPaise: 0,
        platformFeePct: feesConfig.platformFeePct,
        gstPct: feesConfig.gstPct,
        feeBearer: feesConfig.feeBearer,
        freeTicketFeePaise: feesConfig.freeTicketFeePaise,
    });
    await (0, inventory_1.ensureShards)(input.eventId, input.tierId, tier.capacity);
    const allocations = await (0, inventory_1.reserveInventory)(input.eventId, input.tierId, input.quantity);
    try {
        const bookingId = (0, ids_1.newId)('bk');
        const requestId = (0, ids_1.newId)('prq');
        const refCode = await (0, ids_1.nextBookingRef)();
        await (0, ids_1.bindBookingRef)(refCode, bookingId);
        const reservationExpiresAt = firestore_1.Timestamp.fromMillis(now.getTime() + HOLD_HOURS * 60 * 60 * 1000);
        const bookingRef = (0, admin_1.db)().collection('bookings').doc(bookingId);
        const requestRef = (0, admin_1.db)().collection('payment_requests').doc(requestId);
        const batch = (0, admin_1.db)().batch();
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
                provider: 'manual',
                method: input.method,
                utr: input.utr,
                organizerUpiId: input.organizerUpiId ?? null,
                proofUrl: input.proofUrl ?? null,
                note: input.note ?? null,
                status: 'pending_approval',
            },
            status: 'pending_approval',
            reservationExpiresAt,
            reservation: { shards: allocations },
            ticketIds: [],
            contactEmail: user.email ?? null,
            idempotencyKey: input.idempotencyKey ?? null,
            manualRequestId: requestId,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
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
            organizer_upi_id: input.organizerUpiId ?? '',
            proof_image_url: input.proofUrl ?? '',
            note: input.note ?? '',
            payment_method: input.method,
            status: 'PENDING',
            reservation_expires_at: reservationExpiresAt,
            created_at: firestore_1.FieldValue.serverTimestamp(),
            updated_at: firestore_1.FieldValue.serverTimestamp(),
        });
        await batch.commit();
        return {
            bookingId,
            requestId,
            refCode,
            pricing,
            reservationExpiresAt: reservationExpiresAt.toDate().toISOString(),
        };
    }
    catch (err) {
        await (0, inventory_1.releaseInventory)(input.eventId, allocations).catch(() => undefined);
        throw err;
    }
});
exports.reviewManualPayment = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = reviewManualPaymentSchema.parse(req.data);
    const isAdmin = ctx.token.admin === true;
    const requestRef = (0, admin_1.db)().collection('payment_requests').doc(input.requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Payment request not found.');
    const request = requestSnap.data();
    if (!isAdmin && request.organizer_id !== ctx.uid) {
        (0, errors_1.fail)('FORBIDDEN', 'Only the event organizer can review this payment.');
    }
    if (request.status !== 'PENDING') {
        (0, errors_1.fail)('CONFLICT', 'This payment request has already been reviewed.');
    }
    const bookingRef = (0, admin_1.db)().collection('bookings').doc(request.booking_id);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Booking not found.');
    const booking = bookingSnap.data();
    const allocations = (booking.reservation?.shards ?? []);
    if (input.decision === 'reject') {
        await (0, admin_1.db)()
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
                reviewed_at: firestore_1.FieldValue.serverTimestamp(),
                updated_at: firestore_1.FieldValue.serverTimestamp(),
            });
            tx.update(bookingRef, {
                status: 'rejected',
                payment: { ...(freshBooking.data()?.payment ?? {}), status: 'rejected' },
                rejectionReason: input.reason ?? 'Payment could not be verified.',
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        })
            .catch((err) => {
            if (err instanceof Error && err.message === 'ALREADY_REVIEWED') {
                (0, errors_1.fail)('CONFLICT', 'This payment request has already been reviewed.');
            }
            if (err instanceof Error && err.message === 'BOOKING_NOT_PENDING') {
                (0, errors_1.fail)('CONFLICT', 'This booking can no longer be rejected.');
            }
            throw err;
        });
        await (0, inventory_1.releaseInventory)(String(booking.eventId), allocations).catch(() => undefined);
        await (0, notify_1.notifyUser)(String(booking.userId), 'payment_rejected', 'Payment not verified', input.reason ?? 'The organizer could not verify your payment. Please contact support.', { deepLink: `/booking/${request.booking_id}`, channel: 'bookings' }).catch(() => undefined);
        return { ok: true, status: 'REJECTED' };
    }
    const reservationExpiresAt = booking.reservationExpiresAt;
    if (reservationExpiresAt && reservationExpiresAt.toMillis() < Date.now()) {
        (0, errors_1.fail)('HOLD_EXPIRED', 'This payment hold has expired. Please ask the attendee to book again.');
    }
    const items = (booking.items ?? []);
    const userSnap = await (0, admin_1.db)().collection('users').doc(String(booking.userId)).get();
    const user = userSnap.data() ?? {};
    const ticketIds = [];
    const ticketDocs = [];
    const secretDocs = [];
    let seq = 1;
    for (const item of items) {
        for (let i = 0; i < item.qty; i += 1) {
            const ticketId = `tk_${(0, node_crypto_1.randomBytes)(9).toString('hex')}`;
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
                    issuedAt: firestore_1.FieldValue.serverTimestamp(),
                },
            });
            secretDocs.push({
                id: ticketId,
                data: {
                    schemaVersion: 1,
                    secret: (0, node_crypto_1.randomBytes)(32).toString('base64'),
                    version: 1,
                    createdAt: firestore_1.FieldValue.serverTimestamp(),
                },
            });
            seq += 1;
        }
    }
    const attendeeRef = (0, admin_1.db)().collection('eventAttendees').doc(`${booking.eventId}_${booking.userId}`);
    await (0, admin_1.db)().runTransaction(async (tx) => {
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
            reviewed_at: firestore_1.FieldValue.serverTimestamp(),
            updated_at: firestore_1.FieldValue.serverTimestamp(),
        });
        tx.update(bookingRef, {
            status: 'confirmed',
            payment: {
                ...(freshBooking.data()?.payment ?? {}),
                status: 'captured',
                reviewedBy: ctx.uid,
            },
            confirmedAt: firestore_1.FieldValue.serverTimestamp(),
            ticketIds,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        for (const doc of ticketDocs)
            tx.set((0, admin_1.db)().collection('tickets').doc(doc.id), doc.data);
        for (const doc of secretDocs)
            tx.set((0, admin_1.db)().collection('ticketSecrets').doc(doc.id), doc.data);
        const existingAttendee = freshAttendee.data();
        tx.set(attendeeRef, {
            schemaVersion: 1,
            eventId: booking.eventId,
            uid: booking.userId,
            ticketCount: firestore_1.FieldValue.increment(ticketIds.length),
            firstTicketAt: existingAttendee?.firstTicketAt ?? firestore_1.FieldValue.serverTimestamp(),
            radarOptIn: existingAttendee?.radarOptIn ?? false,
            incognito: user.privacy?.incognito === true,
        }, { merge: true });
    }).catch((err) => {
        if (err instanceof Error && err.message === 'ALREADY_REVIEWED') {
            (0, errors_1.fail)('CONFLICT', 'This payment request has already been reviewed.');
        }
        if (err instanceof Error && err.message === 'BOOKING_NOT_PENDING') {
            (0, errors_1.fail)('CONFLICT', 'This booking can no longer be approved.');
        }
        throw err;
    });
    await (0, inventory_1.confirmInventory)(String(booking.eventId), allocations).catch(() => undefined);
    const pricing = (booking.pricing ?? {});
    await (0, finance_1.recordConfirmedBooking)({
        eventId: String(booking.eventId),
        bookingId: request.booking_id,
        lines: items.map((item) => ({ tierId: item.tierId, qty: item.qty, unitPaise: item.unitPaise })),
        grossPaise: Number(pricing.subtotalPaise ?? 0),
        discountPaise: Number(pricing.discountPaise ?? 0),
        platformFeePaise: Number(pricing.platformFeePaise ?? 0),
        gstOnFeePaise: Number(pricing.gstOnFeePaise ?? 0),
        feeBearer: pricing.feeBearer === 'buyer' ? 'buyer' : 'organizer',
    }).catch(() => undefined);
    await (0, notify_1.notifyUser)(String(booking.userId), 'booking_confirmed', 'Booking confirmed', `Your tickets for ${booking.eventSnapshot?.title ?? 'your event'} are confirmed.`, { deepLink: `/ticket/${ticketIds[0] ?? ''}`, channel: 'bookings' }).catch(() => undefined);
    return { ok: true, status: 'APPROVED', ticketIds };
});
//# sourceMappingURL=manual.js.map