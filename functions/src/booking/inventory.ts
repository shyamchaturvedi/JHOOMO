import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../shared/admin';
import { MiloError } from '../shared/errors';

export const SHARD_COUNT = 10;

export interface ShardAllocation {
  tierId: string;
  shard: string;
  qty: number;
}

function tierShardRefs(eventId: string, tierId: string) {
  const base = db().collection('events').doc(eventId).collection('ticketTiers').doc(tierId).collection('shards');
  return Array.from({ length: SHARD_COUNT }, (_, i) => base.doc(String(i)));
}

export interface TierInventory {
  capacity: number;
  held: number;
  sold: number;
}

export async function readTierInventory(eventId: string, tierId: string): Promise<TierInventory> {
  const refs = tierShardRefs(eventId, tierId);
  const snaps = await db().getAll(...refs);
  let capacity = 0;
  let held = 0;
  let sold = 0;
  for (const snap of snaps) {
    const data = snap.data() as Partial<TierInventory> | undefined;
    capacity += Number(data?.capacity ?? 0);
    held += Number(data?.held ?? 0);
    sold += Number(data?.sold ?? 0);
  }
  return { capacity, held, sold };
}

/**
 * Create the 10 inventory shards for a tier if they do not exist yet.
 * Capacity is distributed round-robin so no single document becomes a hotspot
 * (PRD §4 — sharded counters because a Firestore doc sustains ~1 write/sec).
 */
export async function ensureShards(eventId: string, tierId: string, capacity: number): Promise<void> {
  const refs = tierShardRefs(eventId, tierId);
  const snaps = await db().getAll(...refs);
  const missing = snaps.map((snap, i) => (snap.exists ? null : i)).filter((i): i is number => i !== null);
  if (missing.length === 0) return;

  const existingCapacity = snaps.reduce(
    (sum, snap) => sum + Number((snap.data() as Partial<TierInventory> | undefined)?.capacity ?? 0),
    0,
  );
  const remaining = Math.max(0, capacity - existingCapacity);
  if (remaining === 0) return;

  const batch = db().batch();
  const perShard = Math.floor(remaining / missing.length);
  let leftover = remaining - perShard * missing.length;
  for (const index of missing) {
    const extra = leftover > 0 ? 1 : 0;
    leftover -= extra;
    batch.set(
      refs[index]!,
      { capacity: perShard + extra, held: 0, sold: 0, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
  await batch.commit();
}

export async function reserveInventory(
  eventId: string,
  tierId: string,
  qty: number,
): Promise<ShardAllocation[]> {
  const refs = tierShardRefs(eventId, tierId);
  const allocation: ShardAllocation[] = [];

  await db().runTransaction(async (tx) => {
    const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
    const shards = snaps.map((snap, index) => {
      const data = (snap.data() ?? {}) as Partial<TierInventory>;
      return {
        index,
        ref: refs[index]!,
        capacity: Number(data.capacity ?? 0),
        held: Number(data.held ?? 0),
        sold: Number(data.sold ?? 0),
      };
    });

    const totalAvailable = shards.reduce(
      (sum, s) => sum + Math.max(0, s.capacity - s.held - s.sold),
      0,
    );
    if (totalAvailable < qty) {
      throw new MiloError('SOLD_OUT', 'Those tickets are no longer available.', {
        tierId,
        available: totalAvailable,
      });
    }

    let remaining = qty;
    for (const shard of shards) {
      if (remaining <= 0) break;
      const available = Math.max(0, shard.capacity - shard.held - shard.sold);
      const take = Math.min(available, remaining);
      if (take <= 0) continue;
      tx.update(shard.ref, {
        held: shard.held + take,
        updatedAt: FieldValue.serverTimestamp(),
      });
      allocation.push({ tierId, shard: String(shard.index), qty: take });
      remaining -= take;
    }
  });

  return allocation;
}

export async function releaseInventory(
  eventId: string,
  allocations: ShardAllocation[],
): Promise<void> {
  if (allocations.length === 0) return;
  await db().runTransaction(async (tx) => {
    for (const alloc of allocations) {
      const ref = db()
        .collection('events')
        .doc(eventId)
        .collection('ticketTiers')
        .doc(alloc.tierId)
        .collection('shards')
        .doc(alloc.shard);
      const snap = await tx.get(ref);
      if (!snap.exists) continue;
      const data = snap.data() as Partial<TierInventory>;
      const held = Math.max(0, Number(data.held ?? 0) - alloc.qty);
      tx.update(ref, { held, updatedAt: FieldValue.serverTimestamp() });
    }
  });
}

export async function confirmInventory(
  eventId: string,
  allocations: ShardAllocation[],
): Promise<void> {
  if (allocations.length === 0) return;
  await db().runTransaction(async (tx) => {
    for (const alloc of allocations) {
      const ref = db()
        .collection('events')
        .doc(eventId)
        .collection('ticketTiers')
        .doc(alloc.tierId)
        .collection('shards')
        .doc(alloc.shard);
      const snap = await tx.get(ref);
      if (!snap.exists) continue;
      const data = snap.data() as Partial<TierInventory>;
      const held = Math.max(0, Number(data.held ?? 0) - alloc.qty);
      const sold = Number(data.sold ?? 0) + alloc.qty;
      tx.update(ref, { held, sold, updatedAt: FieldValue.serverTimestamp() });
    }
  });
}
