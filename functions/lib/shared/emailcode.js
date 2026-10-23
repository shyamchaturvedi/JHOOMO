"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateEmailCode = generateEmailCode;
exports.issueEmailCode = issueEmailCode;
exports.verifyEmailCode = verifyEmailCode;
exports.deliverEmailCode = deliverEmailCode;
const firestore_1 = require("firebase-admin/firestore");
const node_crypto_1 = require("node:crypto");
const admin_1 = require("./admin");
const crypto_1 = require("./crypto");
const vendors_1 = require("./vendors");
function codeKey(email, purpose) {
    return `${purpose}_${(0, crypto_1.sha256Hex)(email.toLowerCase()).slice(0, 32)}`;
}
function generateEmailCode() {
    return String((0, node_crypto_1.randomInt)(0, 1_000_000)).padStart(6, '0');
}
async function issueEmailCode(email, purpose, ttlMinutes = 15) {
    const code = generateEmailCode();
    const ref = (0, admin_1.db)().collection('emailCodes').doc(codeKey(email, purpose));
    await ref.set({
        hash: (0, crypto_1.sha256Hex)(`${code}:${purpose}`),
        purpose,
        attempts: 0,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        expiresAt: firestore_1.Timestamp.fromMillis(Date.now() + ttlMinutes * 60 * 1000),
    }, { merge: true });
    return code;
}
async function verifyEmailCode(email, code, purpose) {
    const ref = (0, admin_1.db)().collection('emailCodes').doc(codeKey(email, purpose));
    const snap = await ref.get();
    if (!snap.exists)
        return false;
    const data = snap.data();
    const expired = data.expiresAt.toMillis() < Date.now();
    const expected = (0, crypto_1.sha256Hex)(`${code}:${purpose}`);
    const ok = !expired && data.hash === expected;
    if (!ok) {
        const attempts = Number(data.attempts ?? 0) + 1;
        await ref.set({ attempts }, { merge: true });
        if (attempts >= 5)
            await ref.delete();
        return false;
    }
    await ref.delete();
    return true;
}
async function deliverEmailCode(email, code) {
    const result = await (0, vendors_1.sendSms)({ to: email, body: code });
    if (!result.sent) {
        console.warn('Email code delivery skipped (no DLT provider configured).');
    }
}
//# sourceMappingURL=emailcode.js.map