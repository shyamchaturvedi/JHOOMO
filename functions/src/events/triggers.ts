import { FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { db } from '../shared/admin';

function tokenise(input: {
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
  return [
    ...new Set(
      raw
        .split(/[^a-z0-9]+/)
        .filter((t) => t.length >= 2)
        .slice(0, 120),
    ),
  ];
}

/**
 * Denormalises organiser branding, search tokens and price bounds onto the event
 * document so the discovery feed never needs a join (§13.2 `onEventWrite`).
 */
export const onEventWrite = onDocumentWritten(
  { document: 'events/{eventId}', region: 'asia-south1' },
  async (event) => {
    const after = event.data?.after;
    if (!after) return;

    const data = after.data() ?? {};
    const eventId = after.id;

    const [organizerSnap, tiers] = await Promise.all([
      db().collection('organizers').doc(String(data.organizerId ?? '')).get(),
      db().collection('events').doc(eventId).collection('ticketTiers').get(),
    ]);

    const brand = (organizerSnap.data()?.brand ?? {}) as { name?: string; logoUrl?: string };
    const organizerPublic = {
      name: String(brand.name ?? organizerSnap.data()?.legalName ?? 'Organiser'),
      logoUrl: brand.logoUrl ?? null,
      verified: organizerSnap.data()?.kycStatus === 'approved' || organizerSnap.data()?.trusted === true,
    };

    const prices = tiers.docs.map((t) => Number(t.data().pricePaise ?? 0)).filter((p) => Number.isFinite(p));
    const minPricePaise = prices.length > 0 ? Math.min(...prices) : Number(data.minPricePaise ?? 0);
    const capacityTotal = tiers.docs.reduce((sum, t) => sum + Number(t.data().capacity ?? 0), 0);

    const searchKeywords = tokenise({
      title: String(data.title ?? ''),
      description: String(data.description ?? ''),
      tags: (data.tags ?? []) as string[],
      categoryId: String(data.categoryId ?? ''),
      venueName: String((data.venue as { name?: string } | undefined)?.name ?? ''),
      cityId: String(data.cityId ?? ''),
    });

    const patch: Record<string, unknown> = {
      organizerPublic,
      minPricePaise,
      capacityTotal,
      searchKeywords,
    };

    const current = data as Record<string, unknown>;
    const unchanged =
      JSON.stringify(current.organizerPublic ?? null) === JSON.stringify(organizerPublic) &&
      Number(current.minPricePaise ?? 0) === minPricePaise &&
      Number(current.capacityTotal ?? 0) === capacityTotal &&
      JSON.stringify(current.searchKeywords ?? []) === JSON.stringify(searchKeywords);
    if (unchanged) return;

    await db()
      .collection('events')
      .doc(eventId)
      .set(patch, { merge: true })
      .catch((err) => logger.error('onEventWrite.update_failed', { eventId, error: String(err) }));
  },
);

const pendingRefresh = new Map<string, NodeJS.Timeout>();

/**
 * Recomputes a tier's `availableApprox` / `soldOut` flags from its shards.
 * Writes are debounced so a burst of reservations only triggers one refresh.
 */
export const onTierShardWrite = onDocumentWritten(
  { document: 'events/{eventId}/ticketTiers/{tierId}/shards/{shard}', region: 'asia-south1' },
  async (change) => {
    const eventId = change.params.eventId;
    const tierId = change.params.tierId;
    const key = `${eventId}_${tierId}`;

    const existing = pendingRefresh.get(key);
    if (existing) clearTimeout(existing);
    pendingRefresh.set(
      key,
      setTimeout(() => {
        pendingRefresh.delete(key);
        void refreshTierAvailability(eventId, tierId);
      }, 4000),
    );
  },
);

async function refreshTierAvailability(eventId: string, tierId: string): Promise<void> {
  try {
    const shardSnap = await db()
      .collection('events')
      .doc(eventId)
      .collection('ticketTiers')
      .doc(tierId)
      .collection('shards')
      .get();

    let capacity = 0;
    let held = 0;
    let sold = 0;
    for (const doc of shardSnap.docs) {
      capacity += Number(doc.data().capacity ?? 0);
      held += Number(doc.data().held ?? 0);
      sold += Number(doc.data().sold ?? 0);
    }
    if (shardSnap.size === 0) return;

    const available = Math.max(0, capacity - held - sold);
    const tierRef = db().collection('events').doc(eventId).collection('ticketTiers').doc(tierId);
    const tierSnap = await tierRef.get();
    if (!tierSnap.exists) return;

    const currentAvailable = Number(tierSnap.data()?.availableApprox ?? -1);
    const currentSoldOut = tierSnap.data()?.soldOut === true;
    if (currentAvailable === available && currentSoldOut === (available === 0)) return;

    await tierRef.set(
      { availableApprox: available, soldOut: available === 0, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

    const eventRef = db().collection('events').doc(eventId);
    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) return;
    const capacityTotal = Number(eventSnap.data()?.capacityTotal ?? 0);
    const soldTotal = await soldCount(eventId, tierId);
    const soldPct = capacityTotal > 0 ? Math.min(100, Math.round((soldTotal / capacityTotal) * 100)) : 0;
    if (Number(eventSnap.data()?.soldPct ?? 0) !== soldPct) {
      await eventRef.set({ soldPct, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
  } catch (err) {
    logger.error('onTierShardWrite.refresh_failed', { eventId, tierId, error: String(err) });
  }
}

async function soldCount(eventId: string, tierId: string): Promise<number> {
  const shards = await db()
    .collection('events')
    .doc(eventId)
    .collection('ticketTiers')
    .doc(tierId)
    .collection('shards')
    .get();
  return shards.docs.reduce((sum, d) => sum + Number(d.data().sold ?? 0), 0);
}
