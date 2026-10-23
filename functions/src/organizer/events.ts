import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { randomBytes } from 'node:crypto';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { getLimitsConfig } from '../shared/config';
import { newId } from '../shared/ids';
import { ensureShards } from '../booking/inventory';
import { generateEventGateKeyPair } from '../shared/gatekeys';
import { notifyUser } from '../shared/notify';
import { writeAuditLog } from '../shared/audit';
import { requestIdOf } from '../shared/callable';

const tierSchema = z.object({
  tierId: z.string().min(1).max(64).optional(),
  name: z.string().trim().min(1).max(60),
  type: z
    .enum(['single_general', 'single_female', 'single_male', 'couple', 'vip_table', 'season'])
    .default('single_general'),
  pricePaise: z.number().int().min(0),
  capacity: z.number().int().min(1).max(1_000_000),
  admits: z.number().int().min(1).max(50).default(1),
  perOrderMax: z.number().int().min(1).max(50).default(10),
  perks: z.array(z.string().trim().min(1).max(120)).max(20).default([]),
  validDays: z.array(z.number().int().min(0).max(60)).max(60).optional(),
  saleStartAt: z.number().int().positive().optional(),
  saleEndAt: z.number().int().positive().optional(),
  sortOrder: z.number().int().min(0).max(100).default(0),
  status: z.enum(['active', 'hidden']).default('active'),
});

const eventSchema = z.object({
  eventId: z.string().min(1).max(64).optional(),
  title: z.string().trim().min(3).max(80),
  description: z.string().trim().max(2000).default(''),
  categoryId: z.string().trim().min(1).max(40),
  tags: z.array(z.string().trim().min(1).max(30)).max(8).default([]),
  language: z.string().trim().max(20).optional(),
  ageLimit: z.union([z.literal(0), z.literal(18), z.literal(21)]).default(0),
  cityId: z.string().trim().min(1).max(40),
  venue: z.object({
    name: z.string().trim().min(2).max(120),
    address: z.string().trim().min(2).max(240),
    location: z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) }),
    placeId: z.string().trim().max(120).optional(),
    landmarks: z.array(z.string().trim().min(1).max(80)).max(10).default([]),
  }),
  schedule: z.object({
    startAt: z.number().int().positive(),
    endAt: z.number().int().positive(),
    doorsOpenAt: z.number().int().positive(),
    days: z
      .array(
        z.object({
          dayIndex: z.number().int().min(0).max(60),
          startAt: z.number().int().positive(),
          endAt: z.number().int().positive(),
        }),
      )
      .max(60)
      .optional(),
  }),
  media: z.object({
    posterUrl: z.string().trim().max(500).default(''),
    coverUrl: z.string().trim().max(500).optional(),
    gallery: z.array(z.string().trim().max(500)).max(6).default([]),
    trailerUrl: z.string().trim().max(500).optional(),
  }),
  lineup: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(80),
        role: z.string().trim().max(60).optional(),
        imageUrl: z.string().trim().max(500).optional(),
      }),
    )
    .max(20)
    .default([]),
  rules: z.array(z.string().trim().min(1).max(300)).max(20).default([]),
  refundPolicy: z
    .object({
      type: z.enum(['none', 'full_until', 'tiered']),
      hoursBefore: z.number().int().min(0).max(720).optional(),
      tiers: z
        .array(z.object({ hoursBefore: z.number().int().min(0).max(720), refundPct: z.number().int().min(0).max(100) }))
        .max(10)
        .optional(),
    })
    .default({ type: 'full_until', hoursBefore: 24 }),
  sale: z.object({ startAt: z.number().int().positive(), endAt: z.number().int().positive() }),
  perUserLimit: z.number().int().min(1).max(20).default(4),
  namedTickets: z.boolean().default(false),
  allowPdfTickets: z.boolean().default(true),
  radarEnabled: z.boolean().default(true),
  groupChatEnabled: z.boolean().default(true),
  securityDesk: z.object({ phone: z.string().trim().max(20).optional(), name: z.string().trim().max(80).optional() }).optional(),
  gates: z
    .array(z.object({ id: z.string().trim().min(1).max(40), name: z.string().trim().min(1).max(80) }))
    .min(1)
    .max(10),
  promoter: z
    .object({ enabled: z.boolean().default(false), commissionPct: z.number().min(0).max(30).default(5) })
    .default({ enabled: false, commissionPct: 5 }),
  tiers: z.array(tierSchema).min(1).max(12),
});

function slugify(title: string): string {
  const base = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
  return `${base}-${randomBytes(3).toString('hex')}`;
}

function searchTokens(input: {
  title: string;
  description: string;
  tags: string[];
  categoryId: string;
  venueName: string;
  cityId: string;
}): string[] {
  const raw = [input.title, input.description, input.venueName, input.cityId, input.categoryId, ...input.tags]
    .join(' ')
    .toLowerCase();
  const tokens = raw
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length >= 2)
    .slice(0, 120);
  return [...new Set(tokens)];
}

function refundPolicyShape(policy: z.infer<typeof eventSchema>['refundPolicy']): Record<string, unknown> {
  if (policy.type === 'full_until') return { type: 'full_until', hoursBefore: policy.hoursBefore ?? 24 };
  if (policy.type === 'tiered') return { type: 'tiered', tiers: policy.tiers ?? [] };
  return { type: 'none' };
}

export const saveEventDraft = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = eventSchema.parse(req.data);

  const organizerSnap = await db().collection('organizers').doc(ctx.uid).get();
  const organizer = organizerSnap.data() ?? {};
  const kycStatus = String(organizer.kycStatus ?? 'none');
  if (kycStatus !== 'auto_verified' && kycStatus !== 'approved') {
    fail('FORBIDDEN', 'Complete organiser verification before creating events.');
  }

  const eventId = input.eventId ?? newId('ev');
  const eventRef = db().collection('events').doc(eventId);
  const existingSnap = await eventRef.get();

  if (existingSnap.exists) {
    const existing = existingSnap.data()!;
    if (existing.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');
    const status = String(existing.status);
    if (status !== 'draft' && status !== 'changes_requested') {
      fail('CONFLICT', 'Only draft events can be edited this way.');
    }
  }

  if (input.schedule.doorsOpenAt > input.schedule.startAt) {
    fail('INVALID_INPUT', 'Doors open time must be before the event start time.');
  }
  if (input.schedule.endAt <= input.schedule.startAt) {
    fail('INVALID_INPUT', 'The event end time must be after the start time.');
  }
  if (input.sale.endAt <= input.sale.startAt) {
    fail('INVALID_INPUT', 'The sale end time must be after the sale start time.');
  }
  if (input.media.posterUrl.length === 0) {
    fail('INVALID_INPUT', 'A poster image is required.');
  }

  const capacityTotal = input.tiers.reduce((sum, t) => sum + t.capacity, 0);
  const minPricePaise = Math.min(...input.tiers.map((t) => t.pricePaise));

  const doc: Record<string, unknown> = {
    schemaVersion: 1,
    organizerId: ctx.uid,
    status: existingSnap.exists ? existingSnap.data()!.status : 'draft',
    title: input.title,
    slug: existingSnap.exists ? existingSnap.data()!.slug : slugify(input.title),
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
      startAt: Timestamp.fromMillis(input.schedule.startAt),
      endAt: Timestamp.fromMillis(input.schedule.endAt),
      doorsOpenAt: Timestamp.fromMillis(input.schedule.doorsOpenAt),
      days: (input.schedule.days ?? []).map((d) => ({
        dayIndex: d.dayIndex,
        startAt: Timestamp.fromMillis(d.startAt),
        endAt: Timestamp.fromMillis(d.endAt),
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
      startAt: Timestamp.fromMillis(input.sale.startAt),
      endAt: Timestamp.fromMillis(input.sale.endAt),
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
    soldPct: existingSnap.exists ? existingSnap.data()!.soldPct ?? 0 : 0,
    trendScore: existingSnap.exists ? existingSnap.data()!.trendScore ?? 0 : 0,
    featured: existingSnap.exists ? existingSnap.data()!.featured ?? false : false,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: existingSnap.exists ? existingSnap.data()!.createdAt : FieldValue.serverTimestamp(),
  };

  await eventRef.set(doc, { merge: true });

  for (const tier of input.tiers) {
    const tierId = tier.tierId ?? newId('tr');
    const tierRef = eventRef.collection('ticketTiers').doc(tierId);
    const tierSnap = await tierRef.get();
    await tierRef.set(
      {
        schemaVersion: 1,
        name: tier.name,
        type: tier.type,
        pricePaise: tier.pricePaise,
        capacity: tier.capacity,
        admits: tier.admits,
        perOrderMax: tier.perOrderMax,
        perks: tier.perks,
        validDays: tier.validDays ?? null,
        sale:
          tier.saleStartAt && tier.saleEndAt
            ? { startAt: Timestamp.fromMillis(tier.saleStartAt), endAt: Timestamp.fromMillis(tier.saleEndAt) }
            : null,
        sortOrder: tier.sortOrder,
        status: tier.status,
        availableApprox: tierSnap.exists ? tierSnap.data()!.availableApprox ?? tier.capacity : tier.capacity,
        soldOut: false,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await ensureShards(eventId, tierId, tier.capacity);
  }

  return { ok: true, eventId, slug: doc.slug as string, status: doc.status };
});

export const submitEventForReview = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ eventId: z.string().min(1).max(64) }).parse(req.data);

  const eventRef = db().collection('events').doc(input.eventId);
  const snap = await eventRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = snap.data()!;
  if (event.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');

  const status = String(event.status);
  if (status !== 'draft' && status !== 'changes_requested') {
    fail('CONFLICT', 'This event is not ready for review.');
  }

  const tiers = await eventRef.collection('ticketTiers').get();
  if (tiers.empty) fail('INVALID_INPUT', 'Add at least one ticket tier before submitting.');

  const limits = await getLimitsConfig();
  const organizerSnap = await db().collection('organizers').doc(ctx.uid).get();
  const organizer = organizerSnap.data() ?? {};
  const completedEvents = Number(organizer.completedEvents ?? 0);
  const trusted = organizer.trusted === true && completedEvents >= limits.trustedOrganizerMinEvents;
  const isFree = tiers.docs.every((t) => Number(t.data().pricePaise ?? 0) === 0);

  const nextStatus = trusted && !isFree ? 'live' : 'pending_review';

  const patch: Record<string, unknown> = {
    status: nextStatus,
    updatedAt: FieldValue.serverTimestamp(),
  };
    if (nextStatus === 'live') {
      patch.publishedAt = FieldValue.serverTimestamp();
      await provisionGateKeys(input.eventId);
    }

  await eventRef.set(patch, { merge: true });

  if (nextStatus === 'live') {
    await notifyUser(
      ctx.uid,
      'event_review_result',
      'Event published',
      `"${event.title}" is now live.`,
      { deepLink: `/organizer/event/${input.eventId}`, channel: 'bookings' },
    );
  }

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'event.submitted',
    targetType: 'event',
    targetId: input.eventId,
    after: { status: nextStatus },
    requestId: requestIdOf(req),
  });

  return { ok: true, status: nextStatus };
});

async function provisionGateKeys(eventId: string): Promise<void> {
  const secretRef = db().collection('eventSecrets').doc(eventId);
  const existing = await secretRef.get();
  if (existing.exists && existing.data()?.gatePrivateKey) return;

  const pair = generateEventGateKeyPair();
  await secretRef.set(
    {
      schemaVersion: 1,
      gatePrivateKey: pair.privateKeyPem,
      gatePublicKey: pair.publicKeyB64,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

export const updateLiveEvent = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      eventId: z.string().min(1).max(64),
      patch: z.record(z.unknown()),
      reason: z.string().trim().max(300).optional(),
    })
    .parse(req.data);

  const eventRef = db().collection('events').doc(input.eventId);
  const snap = await eventRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = snap.data()!;
  if (event.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');

  const status = String(event.status);
  if (status !== 'live' && status !== 'paused') {
    fail('CONFLICT', 'Only live events can be updated.');
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

  const patch: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input.patch)) {
    if (!allowed.has(key)) fail('INVALID_INPUT', `The field "${key}" cannot be edited directly.`);
    patch[key] = value;
  }
  if (Object.keys(patch).length === 0) fail('INVALID_INPUT', 'Nothing to update.');

  await eventRef.set(
    {
      ...patch,
      status: 'live',
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const attendees = await db().collection('eventAttendees').where('eventId', '==', input.eventId).get();
  const uids = attendees.docs.map((d) => String(d.data().uid)).filter(Boolean);
  await Promise.all(
    uids.map((uid) =>
      notifyUser(
        uid,
        'event_updated',
        'Event updated',
        `"${event.title}" has new details. Open the event page to view them.`,
        { deepLink: `/event/${input.eventId}`, channel: 'bookings' },
      ).catch(() => undefined),
    ),
  );

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'event.updated',
    targetType: 'event',
    targetId: input.eventId,
    after: { keys: Object.keys(patch) },
    reason: input.reason,
    requestId: requestIdOf(req),
  });

  return { ok: true, notified: uids.length };
});

export const cancelEvent = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({ eventId: z.string().min(1).max(64), reason: z.string().trim().min(3).max(300) })
    .parse(req.data);

  const eventRef = db().collection('events').doc(input.eventId);
  const snap = await eventRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = snap.data()!;
  if (event.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');

  const status = String(event.status);
  if (status === 'cancelled' || status === 'completed') {
    fail('CONFLICT', 'This event is already closed.');
  }

  await eventRef.set(
    {
      status: 'cancelled',
      cancelledAt: FieldValue.serverTimestamp(),
      cancelReason: input.reason,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const attendees = await db().collection('eventAttendees').where('eventId', '==', input.eventId).get();
  const uids = attendees.docs.map((d) => String(d.data().uid)).filter(Boolean);
  await Promise.all(
    uids.map((uid) =>
      notifyUser(
        uid,
        'event_cancelled',
        'Event cancelled',
        `"${event.title}" has been cancelled. Any payment will be refunded to the original method.`,
        { deepLink: `/event/${input.eventId}`, channel: 'bookings' },
      ).catch(() => undefined),
    ),
  );

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'event.cancelled',
    targetType: 'event',
    targetId: input.eventId,
    reason: input.reason,
    requestId: requestIdOf(req),
  });

  return { ok: true, notified: uids.length };
});

const promoSchema = z.object({
  eventId: z.string().min(1).max(64),
  code: z
    .string()
    .trim()
    .toUpperCase()
    .min(3)
    .max(24)
    .regex(/^[A-Z0-9_-]+$/, 'Invalid promo code'),
  type: z.enum(['percent', 'flat']),
  value: z.number().min(0),
  maxUses: z.number().int().min(0).max(1_000_000).default(0),
  perUserLimit: z.number().int().min(1).max(50).default(1),
  validFrom: z.number().int().positive(),
  validTo: z.number().int().positive(),
  tierIds: z.array(z.string().min(1).max(64)).max(12).optional(),
  minOrderPaise: z.number().int().min(0).optional(),
  fundedBy: z.enum(['organizer', 'milo']).default('organizer'),
});

export const createPromoCode = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = promoSchema.parse(req.data);

  const eventSnap = await db().collection('events').doc(input.eventId).get();
  if (!eventSnap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = eventSnap.data()!;
  if (event.organizerId !== ctx.uid) fail('FORBIDDEN', 'This event belongs to another organiser.');
  if (input.validTo <= input.validFrom) fail('INVALID_INPUT', 'The validity window is invalid.');
  if (input.type === 'percent' && input.value > 100) fail('INVALID_INPUT', 'A percentage discount cannot exceed 100%.');

  const docId = `${input.eventId}_${input.code}`;
  const ref = db().collection('promoCodes').doc(docId);
  const existing = await ref.get();
  if (existing.exists) fail('CONFLICT', 'That promo code already exists for this event.');

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
    validFrom: Timestamp.fromMillis(input.validFrom),
    validTo: Timestamp.fromMillis(input.validTo),
    tierIds: input.tierIds ?? null,
    minOrderPaise: input.minOrderPaise ?? null,
    fundedBy: input.fundedBy,
    active: true,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, code: input.code, docId };
});

export const listMyEvents = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({ status: z.string().max(20).optional(), limit: z.number().int().min(1).max(50).default(20) })
    .parse(req.data);

  let query = db().collection('events').where('organizerId', '==', ctx.uid);
  if (input.status) query = query.where('status', '==', input.status);
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
