"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listMyEvents = exports.createPromoCode = exports.cancelEvent = exports.updateLiveEvent = exports.submitEventForReview = exports.saveEventDraft = void 0;
const firestore_1 = require("firebase-admin/firestore");
const node_crypto_1 = require("node:crypto");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const config_1 = require("../shared/config");
const ids_1 = require("../shared/ids");
const inventory_1 = require("../booking/inventory");
const gatekeys_1 = require("../shared/gatekeys");
const notify_1 = require("../shared/notify");
const audit_1 = require("../shared/audit");
const callable_2 = require("../shared/callable");
const tierSchema = zod_1.z.object({
    tierId: zod_1.z.string().min(1).max(64).optional(),
    name: zod_1.z.string().trim().min(1).max(60),
    type: zod_1.z
        .enum(['single_general', 'single_female', 'single_male', 'couple', 'vip_table', 'season'])
        .default('single_general'),
    pricePaise: zod_1.z.number().int().min(0),
    capacity: zod_1.z.number().int().min(1).max(1_000_000),
    admits: zod_1.z.number().int().min(1).max(50).default(1),
    perOrderMax: zod_1.z.number().int().min(1).max(50).default(10),
    perks: zod_1.z.array(zod_1.z.string().trim().min(1).max(120)).max(20).default([]),
    validDays: zod_1.z.array(zod_1.z.number().int().min(0).max(60)).max(60).optional(),
    saleStartAt: zod_1.z.number().int().positive().optional(),
    saleEndAt: zod_1.z.number().int().positive().optional(),
    sortOrder: zod_1.z.number().int().min(0).max(100).default(0),
    status: zod_1.z.enum(['active', 'hidden']).default('active'),
});
const eventSchema = zod_1.z.object({
    eventId: zod_1.z.string().min(1).max(64).optional(),
    title: zod_1.z.string().trim().min(3).max(80),
    description: zod_1.z.string().trim().max(2000).default(''),
    categoryId: zod_1.z.string().trim().min(1).max(40),
    tags: zod_1.z.array(zod_1.z.string().trim().min(1).max(30)).max(8).default([]),
    language: zod_1.z.string().trim().max(20).optional(),
    ageLimit: zod_1.z.union([zod_1.z.literal(0), zod_1.z.literal(18), zod_1.z.literal(21)]).default(0),
    cityId: zod_1.z.string().trim().min(1).max(40),
    venue: zod_1.z.object({
        name: zod_1.z.string().trim().min(2).max(120),
        address: zod_1.z.string().trim().min(2).max(240),
        location: zod_1.z.object({ lat: zod_1.z.number().min(-90).max(90), lng: zod_1.z.number().min(-180).max(180) }),
        placeId: zod_1.z.string().trim().max(120).optional(),
        landmarks: zod_1.z.array(zod_1.z.string().trim().min(1).max(80)).max(10).default([]),
    }),
    schedule: zod_1.z.object({
        startAt: zod_1.z.number().int().positive(),
        endAt: zod_1.z.number().int().positive(),
        doorsOpenAt: zod_1.z.number().int().positive(),
        days: zod_1.z
            .array(zod_1.z.object({
            dayIndex: zod_1.z.number().int().min(0).max(60),
            startAt: zod_1.z.number().int().positive(),
            endAt: zod_1.z.number().int().positive(),
        }))
            .max(60)
            .optional(),
    }),
    media: zod_1.z.object({
        posterUrl: zod_1.z.string().trim().max(500).default(''),
        coverUrl: zod_1.z.string().trim().max(500).optional(),
        gallery: zod_1.z.array(zod_1.z.string().trim().max(500)).max(6).default([]),
        trailerUrl: zod_1.z.string().trim().max(500).optional(),
    }),
    lineup: zod_1.z
        .array(zod_1.z.object({
        name: zod_1.z.string().trim().min(1).max(80),
        role: zod_1.z.string().trim().max(60).optional(),
        imageUrl: zod_1.z.string().trim().max(500).optional(),
    }))
        .max(20)
        .default([]),
    rules: zod_1.z.array(zod_1.z.string().trim().min(1).max(300)).max(20).default([]),
    refundPolicy: zod_1.z
        .object({
        type: zod_1.z.enum(['none', 'full_until', 'tiered']),
        hoursBefore: zod_1.z.number().int().min(0).max(720).optional(),
        tiers: zod_1.z
            .array(zod_1.z.object({ hoursBefore: zod_1.z.number().int().min(0).max(720), refundPct: zod_1.z.number().int().min(0).max(100) }))
            .max(10)
            .optional(),
    })
        .default({ type: 'full_until', hoursBefore: 24 }),
    sale: zod_1.z.object({ startAt: zod_1.z.number().int().positive(), endAt: zod_1.z.number().int().positive() }),
    perUserLimit: zod_1.z.number().int().min(1).max(20).default(4),
    namedTickets: zod_1.z.boolean().default(false),
    allowPdfTickets: zod_1.z.boolean().default(true),
    radarEnabled: zod_1.z.boolean().default(true),
    groupChatEnabled: zod_1.z.boolean().default(true),
    securityDesk: zod_1.z.object({ phone: zod_1.z.string().trim().max(20).optional(), name: zod_1.z.string().trim().max(80).optional() }).optional(),
    gates: zod_1.z
        .array(zod_1.z.object({ id: zod_1.z.string().trim().min(1).max(40), name: zod_1.z.string().trim().min(1).max(80) }))
        .min(1)
        .max(10),
    promoter: zod_1.z
        .object({ enabled: zod_1.z.boolean().default(false), commissionPct: zod_1.z.number().min(0).max(30).default(5) })
        .default({ enabled: false, commissionPct: 5 }),
    tiers: zod_1.z.array(tierSchema).min(1).max(12),
});
function slugify(title) {
    const base = title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 60);
    return `${base}-${(0, node_crypto_1.randomBytes)(3).toString('hex')}`;
}
function searchTokens(input) {
    const raw = [input.title, input.description, input.venueName, input.cityId, input.categoryId, ...input.tags]
        .join(' ')
        .toLowerCase();
    const tokens = raw
        .split(/[^a-z0-9]+/)
        .filter((t) => t.length >= 2)
        .slice(0, 120);
    return [...new Set(tokens)];
}
function refundPolicyShape(policy) {
    if (policy.type === 'full_until')
        return { type: 'full_until', hoursBefore: policy.hoursBefore ?? 24 };
    if (policy.type === 'tiered')
        return { type: 'tiered', tiers: policy.tiers ?? [] };
    return { type: 'none' };
}
exports.saveEventDraft = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = eventSchema.parse(req.data);
    const organizerSnap = await (0, admin_1.db)().collection('organizers').doc(ctx.uid).get();
    const organizer = organizerSnap.data() ?? {};
    const kycStatus = String(organizer.kycStatus ?? 'none');
    if (kycStatus !== 'auto_verified' && kycStatus !== 'approved') {
        (0, errors_1.fail)('FORBIDDEN', 'Complete organiser verification before creating events.');
    }
    const eventId = input.eventId ?? (0, ids_1.newId)('ev');
    const eventRef = (0, admin_1.db)().collection('events').doc(eventId);
    const existingSnap = await eventRef.get();
    if (existingSnap.exists) {
        const existing = existingSnap.data();
        if (existing.organizerId !== ctx.uid)
            (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
        const status = String(existing.status);
        if (status !== 'draft' && status !== 'changes_requested') {
            (0, errors_1.fail)('CONFLICT', 'Only draft events can be edited this way.');
        }
    }
    if (input.schedule.doorsOpenAt > input.schedule.startAt) {
        (0, errors_1.fail)('INVALID_INPUT', 'Doors open time must be before the event start time.');
    }
    if (input.schedule.endAt <= input.schedule.startAt) {
        (0, errors_1.fail)('INVALID_INPUT', 'The event end time must be after the start time.');
    }
    if (input.sale.endAt <= input.sale.startAt) {
        (0, errors_1.fail)('INVALID_INPUT', 'The sale end time must be after the sale start time.');
    }
    if (input.media.posterUrl.length === 0) {
        (0, errors_1.fail)('INVALID_INPUT', 'A poster image is required.');
    }
    const capacityTotal = input.tiers.reduce((sum, t) => sum + t.capacity, 0);
    const minPricePaise = Math.min(...input.tiers.map((t) => t.pricePaise));
    const doc = {
        schemaVersion: 1,
        organizerId: ctx.uid,
        status: existingSnap.exists ? existingSnap.data().status : 'draft',
        title: input.title,
        slug: existingSnap.exists ? existingSnap.data().slug : slugify(input.title),
        description: input.description,
        categoryId: input.categoryId,
        tags: input.tags,
        searchKeywords: searchTokens({
            title: input.title,
            description: input.description,
            tags: input.tags,
            categoryId: input.categoryId,
            venueName: input.venue.name,
            cityId: input.cityId,
        }),
        language: input.language ?? null,
        ageLimit: input.ageLimit,
        cityId: input.cityId,
        venue: {
            name: input.venue.name,
            address: input.venue.address,
            location: input.venue.location,
            geohash: null,
            placeId: input.venue.placeId ?? null,
            landmarks: input.venue.landmarks,
        },
        schedule: {
            startAt: firestore_1.Timestamp.fromMillis(input.schedule.startAt),
            endAt: firestore_1.Timestamp.fromMillis(input.schedule.endAt),
            doorsOpenAt: firestore_1.Timestamp.fromMillis(input.schedule.doorsOpenAt),
            days: (input.schedule.days ?? []).map((d) => ({
                dayIndex: d.dayIndex,
                startAt: firestore_1.Timestamp.fromMillis(d.startAt),
                endAt: firestore_1.Timestamp.fromMillis(d.endAt),
            })),
        },
        media: {
            posterUrl: input.media.posterUrl,
            coverUrl: input.media.coverUrl ?? null,
            gallery: input.media.gallery,
            trailerUrl: input.media.trailerUrl ?? null,
        },
        lineup: input.lineup,
        rules: input.rules,
        refundPolicy: refundPolicyShape(input.refundPolicy),
        sale: {
            startAt: firestore_1.Timestamp.fromMillis(input.sale.startAt),
            endAt: firestore_1.Timestamp.fromMillis(input.sale.endAt),
        },
        perUserLimit: input.perUserLimit,
        namedTickets: input.namedTickets,
        allowPdfTickets: input.allowPdfTickets,
        radarEnabled: input.radarEnabled,
        groupChatEnabled: input.groupChatEnabled,
        securityDesk: input.securityDesk ?? null,
        gates: input.gates,
        promoter: input.promoter,
        capacityTotal,
        minPricePaise,
        soldPct: existingSnap.exists ? existingSnap.data().soldPct ?? 0 : 0,
        trendScore: existingSnap.exists ? existingSnap.data().trendScore ?? 0 : 0,
        featured: existingSnap.exists ? existingSnap.data().featured ?? false : false,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
        createdAt: existingSnap.exists ? existingSnap.data().createdAt : firestore_1.FieldValue.serverTimestamp(),
    };
    await eventRef.set(doc, { merge: true });
    for (const tier of input.tiers) {
        const tierId = tier.tierId ?? (0, ids_1.newId)('tr');
        const tierRef = eventRef.collection('ticketTiers').doc(tierId);
        const tierSnap = await tierRef.get();
        await tierRef.set({
            schemaVersion: 1,
            name: tier.name,
            type: tier.type,
            pricePaise: tier.pricePaise,
            capacity: tier.capacity,
            admits: tier.admits,
            perOrderMax: tier.perOrderMax,
            perks: tier.perks,
            validDays: tier.validDays ?? null,
            sale: tier.saleStartAt && tier.saleEndAt
                ? { startAt: firestore_1.Timestamp.fromMillis(tier.saleStartAt), endAt: firestore_1.Timestamp.fromMillis(tier.saleEndAt) }
                : null,
            sortOrder: tier.sortOrder,
            status: tier.status,
            availableApprox: tierSnap.exists ? tierSnap.data().availableApprox ?? tier.capacity : tier.capacity,
            soldOut: false,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        await (0, inventory_1.ensureShards)(eventId, tierId, tier.capacity);
    }
    return { ok: true, eventId, slug: doc.slug, status: doc.status };
});
exports.submitEventForReview = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ eventId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const eventRef = (0, admin_1.db)().collection('events').doc(input.eventId);
    const snap = await eventRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const event = snap.data();
    if (event.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
    const status = String(event.status);
    if (status !== 'draft' && status !== 'changes_requested') {
        (0, errors_1.fail)('CONFLICT', 'This event is not ready for review.');
    }
    const tiers = await eventRef.collection('ticketTiers').get();
    if (tiers.empty)
        (0, errors_1.fail)('INVALID_INPUT', 'Add at least one ticket tier before submitting.');
    const limits = await (0, config_1.getLimitsConfig)();
    const organizerSnap = await (0, admin_1.db)().collection('organizers').doc(ctx.uid).get();
    const organizer = organizerSnap.data() ?? {};
    const completedEvents = Number(organizer.completedEvents ?? 0);
    const trusted = organizer.trusted === true && completedEvents >= limits.trustedOrganizerMinEvents;
    const isFree = tiers.docs.every((t) => Number(t.data().pricePaise ?? 0) === 0);
    const nextStatus = trusted && !isFree ? 'live' : 'pending_review';
    const patch = {
        status: nextStatus,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    if (nextStatus === 'live') {
        patch.publishedAt = firestore_1.FieldValue.serverTimestamp();
        await provisionGateKeys(input.eventId);
    }
    await eventRef.set(patch, { merge: true });
    if (nextStatus === 'live') {
        await (0, notify_1.notifyUser)(ctx.uid, 'event_review_result', 'Event published', `"${event.title}" is now live.`, { deepLink: `/organizer/event/${input.eventId}`, channel: 'bookings' });
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'event.submitted',
        targetType: 'event',
        targetId: input.eventId,
        after: { status: nextStatus },
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true, status: nextStatus };
});
async function provisionGateKeys(eventId) {
    const secretRef = (0, admin_1.db)().collection('eventSecrets').doc(eventId);
    const existing = await secretRef.get();
    if (existing.exists && existing.data()?.gatePrivateKey)
        return;
    const pair = (0, gatekeys_1.generateEventGateKeyPair)();
    await secretRef.set({
        schemaVersion: 1,
        gatePrivateKey: pair.privateKeyPem,
        gatePublicKey: pair.publicKeyB64,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
}
exports.updateLiveEvent = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        eventId: zod_1.z.string().min(1).max(64),
        patch: zod_1.z.record(zod_1.z.unknown()),
        reason: zod_1.z.string().trim().max(300).optional(),
    })
        .parse(req.data);
    const eventRef = (0, admin_1.db)().collection('events').doc(input.eventId);
    const snap = await eventRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const event = snap.data();
    if (event.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
    const status = String(event.status);
    if (status !== 'live' && status !== 'paused') {
        (0, errors_1.fail)('CONFLICT', 'Only live events can be updated.');
    }
    const allowed = new Set([
        'title',
        'description',
        'tags',
        'media',
        'lineup',
        'rules',
        'venue',
        'schedule',
        'sale',
        'perUserLimit',
        'namedTickets',
        'allowPdfTickets',
        'radarEnabled',
        'groupChatEnabled',
        'securityDesk',
        'gates',
        'promoter',
    ]);
    const patch = {};
    for (const [key, value] of Object.entries(input.patch)) {
        if (!allowed.has(key))
            (0, errors_1.fail)('INVALID_INPUT', `The field "${key}" cannot be edited directly.`);
        patch[key] = value;
    }
    if (Object.keys(patch).length === 0)
        (0, errors_1.fail)('INVALID_INPUT', 'Nothing to update.');
    await eventRef.set({
        ...patch,
        status: 'live',
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const attendees = await (0, admin_1.db)().collection('eventAttendees').where('eventId', '==', input.eventId).get();
    const uids = attendees.docs.map((d) => String(d.data().uid)).filter(Boolean);
    await Promise.all(uids.map((uid) => (0, notify_1.notifyUser)(uid, 'event_updated', 'Event updated', `"${event.title}" has new details. Open the event page to view them.`, { deepLink: `/event/${input.eventId}`, channel: 'bookings' }).catch(() => undefined)));
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'event.updated',
        targetType: 'event',
        targetId: input.eventId,
        after: { keys: Object.keys(patch) },
        reason: input.reason,
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true, notified: uids.length };
});
exports.cancelEvent = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({ eventId: zod_1.z.string().min(1).max(64), reason: zod_1.z.string().trim().min(3).max(300) })
        .parse(req.data);
    const eventRef = (0, admin_1.db)().collection('events').doc(input.eventId);
    const snap = await eventRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const event = snap.data();
    if (event.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
    const status = String(event.status);
    if (status === 'cancelled' || status === 'completed') {
        (0, errors_1.fail)('CONFLICT', 'This event is already closed.');
    }
    await eventRef.set({
        status: 'cancelled',
        cancelledAt: firestore_1.FieldValue.serverTimestamp(),
        cancelReason: input.reason,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const attendees = await (0, admin_1.db)().collection('eventAttendees').where('eventId', '==', input.eventId).get();
    const uids = attendees.docs.map((d) => String(d.data().uid)).filter(Boolean);
    await Promise.all(uids.map((uid) => (0, notify_1.notifyUser)(uid, 'event_cancelled', 'Event cancelled', `"${event.title}" has been cancelled. Any payment will be refunded to the original method.`, { deepLink: `/event/${input.eventId}`, channel: 'bookings' }).catch(() => undefined)));
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'event.cancelled',
        targetType: 'event',
        targetId: input.eventId,
        reason: input.reason,
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true, notified: uids.length };
});
const promoSchema = zod_1.z.object({
    eventId: zod_1.z.string().min(1).max(64),
    code: zod_1.z
        .string()
        .trim()
        .toUpperCase()
        .min(3)
        .max(24)
        .regex(/^[A-Z0-9_-]+$/, 'Invalid promo code'),
    type: zod_1.z.enum(['percent', 'flat']),
    value: zod_1.z.number().min(0),
    maxUses: zod_1.z.number().int().min(0).max(1_000_000).default(0),
    perUserLimit: zod_1.z.number().int().min(1).max(50).default(1),
    validFrom: zod_1.z.number().int().positive(),
    validTo: zod_1.z.number().int().positive(),
    tierIds: zod_1.z.array(zod_1.z.string().min(1).max(64)).max(12).optional(),
    minOrderPaise: zod_1.z.number().int().min(0).optional(),
    fundedBy: zod_1.z.enum(['organizer', 'milo']).default('organizer'),
});
exports.createPromoCode = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = promoSchema.parse(req.data);
    const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const event = eventSnap.data();
    if (event.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
    if (input.validTo <= input.validFrom)
        (0, errors_1.fail)('INVALID_INPUT', 'The validity window is invalid.');
    if (input.type === 'percent' && input.value > 100)
        (0, errors_1.fail)('INVALID_INPUT', 'A percentage discount cannot exceed 100%.');
    const docId = `${input.eventId}_${input.code}`;
    const ref = (0, admin_1.db)().collection('promoCodes').doc(docId);
    const existing = await ref.get();
    if (existing.exists)
        (0, errors_1.fail)('CONFLICT', 'That promo code already exists for this event.');
    await ref.set({
        schemaVersion: 1,
        code: input.code,
        eventId: input.eventId,
        organizerId: ctx.uid,
        createdBy: 'organizer',
        type: input.type,
        value: input.value,
        maxUses: input.maxUses,
        usedCount: 0,
        perUserLimit: input.perUserLimit,
        validFrom: firestore_1.Timestamp.fromMillis(input.validFrom),
        validTo: firestore_1.Timestamp.fromMillis(input.validTo),
        tierIds: input.tierIds ?? null,
        minOrderPaise: input.minOrderPaise ?? null,
        fundedBy: input.fundedBy,
        active: true,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true, code: input.code, docId };
});
exports.listMyEvents = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({ status: zod_1.z.string().max(20).optional(), limit: zod_1.z.number().int().min(1).max(50).default(20) })
        .parse(req.data);
    let query = (0, admin_1.db)().collection('events').where('organizerId', '==', ctx.uid);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.orderBy('schedule.startAt', 'desc').limit(input.limit).get();
    return {
        events: snap.docs.map((d) => {
            const data = d.data();
            return {
                eventId: d.id,
                title: data.title,
                slug: data.slug,
                status: data.status,
                schedule: data.schedule,
                venue: data.venue,
                cityId: data.cityId,
                capacityTotal: data.capacityTotal,
                minPricePaise: data.minPricePaise,
                soldPct: data.soldPct ?? 0,
                media: data.media,
                updatedAt: data.updatedAt,
            };
        }),
    };
});
//# sourceMappingURL=events.js.map