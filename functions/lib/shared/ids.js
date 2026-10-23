"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.newId = newId;
exports.nextBookingRef = nextBookingRef;
exports.bindBookingRef = bindBookingRef;
exports.dateKey = dateKey;
const admin_1 = require("./admin");
const node_crypto_1 = require("node:crypto");
function newId(prefix) {
    return `${prefix}_${(0, node_crypto_1.randomBytes)(9).toString('hex')}`;
}
async function nextBookingRef() {
    const refColl = (0, admin_1.db)().collection('bookingRefs');
    for (let attempt = 0; attempt < 8; attempt += 1) {
        const digits = String(Math.floor(Math.random() * 1_000_000)).padStart(6, '0');
        const ref = `MILO-${digits}`;
        const docRef = refColl.doc(ref);
        try {
            await docRef.create({ bookingId: '', createdAt: new Date() });
            return ref;
        }
        catch {
            // Reference already taken, retry with a new random suffix.
        }
    }
    throw new Error('Unable to allocate a unique booking reference');
}
async function bindBookingRef(ref, bookingId) {
    await (0, admin_1.db)().collection('bookingRefs').doc(ref).set({ bookingId }, { merge: true });
}
function dateKey(d) {
    const shifted = new Date(d.getTime() + 5.5 * 60 * 60 * 1000);
    const y = shifted.getUTCFullYear();
    const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
    const day = String(shifted.getUTCDate()).padStart(2, '0');
    return `${y}${m}${day}`;
}
//# sourceMappingURL=ids.js.map