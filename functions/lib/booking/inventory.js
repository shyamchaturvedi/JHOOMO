"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SHARD_COUNT = void 0;
exports.readTierInventory = readTierInventory;
exports.ensureShards = ensureShards;
exports.reserveInventory = reserveInventory;
exports.releaseInventory = releaseInventory;
exports.confirmInventory = confirmInventory;
const firestore_1 = require("firebase-admin/firestore");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
exports.SHARD_COUNT = 10;
function tierShardRefs(eventId, tierId) {
    const base = (0, admin_1.db)().collection('events').doc(eventId).collection('ticketTiers').doc(tierId).collection('shards');
    return Array.from({ length: exports.SHARD_COUNT }, (_, i) => base.doc(String(i)));
}
async function readTierInventory(eventId, tierId) {
    const refs = tierShardRefs(eventId, tierId);
    const snaps = await (0, admin_1.db)().getAll(...refs);
    let capacity = 0;
    let held = 0;
    let sold = 0;
    for (const snap of snaps) {
        const data = snap.data();
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
async function ensureShards(eventId, tierId, capacity) {
    const refs = tierShardRefs(eventId, tierId);
    const snaps = await (0, admin_1.db)().getAll(...refs);
    const missing = snaps.map((snap, i) => (snap.exists ? null : i)).filter((i) => i !== null);
    if (missing.length === 0)
        return;
    const existingCapacity = snaps.reduce((sum, snap) => sum + Number(snap.data()?.capacity ?? 0), 0);
    const remaining = Math.max(0, capacity - existingCapacity);
    if (remaining === 0)
        return;
    const batch = (0, admin_1.db)().batch();
    const perShard = Math.floor(remaining / missing.length);
    let leftover = remaining - perShard * missing.length;
    for (const index of missing) {
        const extra = leftover > 0 ? 1 : 0;
        leftover -= extra;
        batch.set(refs[index], { capacity: perShard + extra, held: 0, sold: 0, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    await batch.commit();
}
async function reserveInventory(eventId, tierId, qty) {
    const refs = tierShardRefs(eventId, tierId);
    const allocation = [];
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
        const shards = snaps.map((snap, index) => {
            const data = (snap.data() ?? {});
            return {
                index,
                ref: refs[index],
                capacity: Number(data.capacity ?? 0),
                held: Number(data.held ?? 0),
                sold: Number(data.sold ?? 0),
            };
        });
        const totalAvailable = shards.reduce((sum, s) => sum + Math.max(0, s.capacity - s.held - s.sold), 0);
        if (totalAvailable < qty) {
            throw new errors_1.MiloError('SOLD_OUT', 'Those tickets are no longer available.', {
                tierId,
                available: totalAvailable,
            });
        }
        let remaining = qty;
        for (const shard of shards) {
            if (remaining <= 0)
                break;
            const available = Math.max(0, shard.capacity - shard.held - shard.sold);
            const take = Math.min(available, remaining);
            if (take <= 0)
                continue;
            tx.update(shard.ref, {
                held: shard.held + take,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            allocation.push({ tierId, shard: String(shard.index), qty: take });
            remaining -= take;
        }
    });
    return allocation;
}
async function releaseInventory(eventId, allocations) {
    if (allocations.length === 0)
        return;
    await (0, admin_1.db)().runTransaction(async (tx) => {
        for (const alloc of allocations) {
            const ref = (0, admin_1.db)()
                .collection('events')
                .doc(eventId)
                .collection('ticketTiers')
                .doc(alloc.tierId)
                .collection('shards')
                .doc(alloc.shard);
            const snap = await tx.get(ref);
            if (!snap.exists)
                continue;
            const data = snap.data();
            const held = Math.max(0, Number(data.held ?? 0) - alloc.qty);
            tx.update(ref, { held, updatedAt: firestore_1.FieldValue.serverTimestamp() });
        }
    });
}
async function confirmInventory(eventId, allocations) {
    if (allocations.length === 0)
        return;
    await (0, admin_1.db)().runTransaction(async (tx) => {
        for (const alloc of allocations) {
            const ref = (0, admin_1.db)()
                .collection('events')
                .doc(eventId)
                .collection('ticketTiers')
                .doc(alloc.tierId)
                .collection('shards')
                .doc(alloc.shard);
            const snap = await tx.get(ref);
            if (!snap.exists)
                continue;
            const data = snap.data();
            const held = Math.max(0, Number(data.held ?? 0) - alloc.qty);
            const sold = Number(data.sold ?? 0) + alloc.qty;
            tx.update(ref, { held, sold, updatedAt: firestore_1.FieldValue.serverTimestamp() });
        }
    });
}
//# sourceMappingURL=inventory.js.map