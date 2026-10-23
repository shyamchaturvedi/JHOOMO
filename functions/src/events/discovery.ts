import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';

const PUBLIC_STATUSES = ['live', 'sold_out', 'paused', 'completed'];

function decodeCursor(cursor?: string): number | null {
  if (!cursor) return null;
  try {
    const parsed = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as { startAt?: number };
    return typeof parsed.startAt === 'number' ? parsed.startAt : null;
  } catch {
    return null;
  }
}

function encodeCursor(startAt: number): string {
  return Buffer.from(JSON.stringify({ startAt }), 'utf8').toString('base64url');
}

const listSchema = z.object({
  cityId: z.string().trim().max(40).optional(),
  categoryIds: z.array(z.string().trim().max(40)).max(12).optional(),
  fromAt: z.number().int().positive().optional(),
  toAt: z.number().int().positive().optional(),
  query: z.string().trim().max(80).optional(),
  sort: z.enum(['startAt', 'popularity', 'trending']).default('startAt'),
  limit: z.number().int().min(1).max(50).default(20),
  cursor: z.string().max(512).optional(),
});

export const listEvents = miloOnCall({}, async (req) => {
  requireAuth(req);
  const input = listSchema.parse(req.data ?? {});

  let query = db().collection('events').where('status', 'in', PUBLIC_STATUSES);

  if (input.cityId) query = query.where('cityId', '==', input.cityId);
  if (input.categoryIds && input.categoryIds.length === 1) {
    query = query.where('categoryId', '==', input.categoryIds[0]);
  }
  if (input.fromAt) {
    query = query.where('schedule.startAt', '>=', Timestamp.fromMillis(input.fromAt));
  }
  if (input.toAt) {
    query = query.where('schedule.startAt', '<=', Timestamp.fromMillis(input.toAt));
  }

  if (input.sort === 'popularity') query = query.orderBy('soldPct', 'desc').orderBy('schedule.startAt', 'asc');
  else if (input.sort === 'trending') query = query.orderBy('trendScore', 'desc').orderBy('schedule.startAt', 'asc');
  else query = query.orderBy('schedule.startAt', 'asc');

  const cursorAt = decodeCursor(input.cursor);
  if (cursorAt !== null) query = query.startAfter(Timestamp.fromMillis(cursorAt));

  const snap = await query.limit(input.limit + 1).get();
  const docs = snap.docs.slice(0, input.limit);

  let events = docs.map((d) => d.data());
  if (input.categoryIds && input.categoryIds.length > 1) {
    events = events.filter((e) => input.categoryIds!.includes(String(e.categoryId)));
  }
  if (input.query) {
    const tokens = input.query
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((t) => t.length >= 2);
    events = events.filter((e) => {
      const keywords = (e.searchKeywords as string[] | undefined) ?? [];
      return tokens.every((t) => keywords.some((k) => k.includes(t)));
    });
  }

  const last = docs[docs.length - 1];
  const nextCursor =
    snap.docs.length > input.limit && last
      ? encodeCursor((last.data().schedule?.startAt as Timestamp).toMillis())
      : null;

  return {
    events: events.map((e) => summarise(e)),
    nextCursor,
  };
});

export const searchEvents = miloOnCall({}, async (req) => {
  requireAuth(req);
  const input = z
    .object({
      query: z.string().trim().min(2).max(80),
      cityId: z.string().trim().max(40).optional(),
      limit: z.number().int().min(1).max(50).default(20),
    })
    .parse(req.data);

  const tokens = input.query
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length >= 2);

  if (tokens.length === 0) return { events: [] };

  let query = db()
    .collection('events')
    .where('status', 'in', PUBLIC_STATUSES)
    .where('searchKeywords', 'array-contains', tokens[0]!)
    .orderBy('schedule.startAt', 'asc')
    .limit(input.limit * 3);

  if (input.cityId) query = query.where('cityId', '==', input.cityId);

  const snap = await query.get();
  const matches = snap.docs
    .map((d) => d.data())
    .filter((e) => {
      const keywords = (e.searchKeywords as string[] | undefined) ?? [];
      return tokens.every((t) => keywords.some((k) => k.includes(t)));
    })
    .slice(0, input.limit);

  return { events: matches.map(summarise) };
});

export const getEventDetails = miloOnCall({}, async (req) => {
  requireAuth(req);
  const input = z.object({ eventId: z.string().min(1).max(64) }).parse(req.data);

  const snap = await db().collection('events').doc(input.eventId).get();
  if (!snap.exists) fail('NOT_FOUND', 'Event not found.');
  const event = snap.data()!;
  const status = String(event.status);
  if (!PUBLIC_STATUSES.includes(status) && !['pending_review', 'draft', 'changes_requested'].includes(status)) {
    fail('NOT_FOUND', 'Event not found.');
  }

  const [tiers, stats] = await Promise.all([
    db().collection('events').doc(input.eventId).collection('ticketTiers').get(),
    db().collection('eventStats').doc(input.eventId).get(),
  ]);

  return {
    event: {
      ...summarise(event),
      description: event.description,
      lineup: event.lineup ?? [],
      rules: event.rules ?? [],
      refundPolicy: event.refundPolicy ?? null,
      namedTickets: event.namedTickets === true,
      perUserLimit: event.perUserLimit ?? 4,
      allowPdfTickets: event.allowPdfTickets !== false,
      radarEnabled: event.radarEnabled === true,
      groupChatEnabled: event.groupChatEnabled === true,
      securityDesk: event.securityDesk ?? null,
      gates: event.gates ?? [],
      promoter: event.promoter ?? { enabled: false, commissionPct: 0 },
      media: event.media ?? {},
    },
    tiers: tiers.docs
      .map((d) => {
        const t = d.data();
        return {
          tierId: d.id,
          name: t.name,
          type: t.type,
          pricePaise: t.pricePaise,
          capacity: t.capacity,
          admits: t.admits,
          perOrderMax: t.perOrderMax,
          perks: t.perks ?? [],
          validDays: t.validDays ?? null,
          sortOrder: t.sortOrder ?? 0,
          status: t.status,
          availableApprox: t.availableApprox ?? t.capacity,
          soldOut: t.soldOut === true,
          sale: t.sale ?? null,
        };
      })
      .sort((a, b) => a.sortOrder - b.sortOrder),
    stats: stats.exists
      ? { radarCount: stats.data()?.radarCount ?? 0, wishlistCount: stats.data()?.wishlistCount ?? 0 }
      : { radarCount: 0, wishlistCount: 0 },
  };
});

export const toggleWishlist = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ eventId: z.string().min(1).max(64) }).parse(req.data);

  const ref = db().collection('users').doc(ctx.uid).collection('wishlist').doc(input.eventId);
  const snap = await ref.get();

  if (snap.exists) {
    await ref.delete();
    await db()
      .collection('eventStats')
      .doc(input.eventId)
      .set({ wishlistCount: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return { wishlisted: false };
  }

  const eventSnap = await db().collection('events').doc(input.eventId).get();
  if (!eventSnap.exists) fail('NOT_FOUND', 'Event not found.');

  await ref.set({
    eventId: input.eventId,
    title: eventSnap.data()?.title ?? '',
    cityId: eventSnap.data()?.cityId ?? '',
    startAt: eventSnap.data()?.schedule?.startAt ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
  await db()
    .collection('eventStats')
    .doc(input.eventId)
    .set({ wishlistCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });

  return { wishlisted: true };
});

export const listWishlist = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const snap = await db().collection('users').doc(ctx.uid).collection('wishlist').get();
  return {
    items: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
});

function summarise(event: Record<string, unknown>): Record<string, unknown> {
  const schedule = event.schedule as { startAt?: Timestamp; endAt?: Timestamp } | undefined;
  const venue = event.venue as { name?: string; address?: string } | undefined;
  const media = event.media as { posterUrl?: string; coverUrl?: string } | undefined;
  return {
    eventId: event.id ?? null,
    title: event.title,
    slug: event.slug,
    status: event.status,
    categoryId: event.categoryId,
    tags: event.tags ?? [],
    cityId: event.cityId,
    venueName: venue?.name ?? '',
    venueAddress: venue?.address ?? '',
    startAt: schedule?.startAt ? schedule.startAt.toDate().toISOString() : null,
    endAt: schedule?.endAt ? schedule.endAt.toDate().toISOString() : null,
    posterUrl: media?.posterUrl ?? '',
    coverUrl: media?.coverUrl ?? '',
    minPricePaise: event.minPricePaise ?? 0,
    soldPct: event.soldPct ?? 0,
    trendScore: event.trendScore ?? 0,
    featured: event.featured === true,
    ageLimit: event.ageLimit ?? 0,
    organizerPublic: event.organizerPublic ?? null,
  };
}
