"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MILO_KYC_DATA_KEY = void 0;
exports.encryptField = encryptField;
exports.decryptField = decryptField;
const params_1 = require("firebase-functions/params");
const node_crypto_1 = require("node:crypto");
exports.MILO_KYC_DATA_KEY = (0, params_1.defineSecret)('MILO_KYC_DATA_KEY');
const ALGO = 'aes-256-gcm';
const VERSION = 1;
function dataKey() {
    const raw = exports.MILO_KYC_DATA_KEY.value();
    if (!raw)
        throw new Error('MILO_KYC_DATA_KEY is not configured.');
    const key = Buffer.from(raw, 'base64');
    if (key.length !== 32)
        throw new Error('MILO_KYC_DATA_KEY must be 32 bytes (base64).');
    return key;
}
/**
 * Envelope-encrypts sensitive organiser fields (PAN, bank account) before they
 * are written to the server-only `organizerPrivate` collection.
 */
function encryptField(plaintext) {
    const iv = (0, node_crypto_1.randomBytes)(12);
    const cipher = (0, node_crypto_1.createCipheriv)(ALGO, dataKey(), iv);
    const enc = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    return {
        v: VERSION,
        iv: iv.toString('base64'),
        tag: cipher.getAuthTag().toString('base64'),
        data: enc.toString('base64'),
    };
}
function decryptField(envelope) {
    if (!envelope)
        return null;
    try {
        const decipher = (0, node_crypto_1.createDecipheriv)(ALGO, dataKey(), Buffer.from(envelope.iv, 'base64'));
        decipher.setAuthTag(Buffer.from(envelope.tag, 'base64'));
        const dec = Buffer.concat([decipher.update(Buffer.from(envelope.data, 'base64')), decipher.final()]);
        return dec.toString('utf8');
    }
    catch {
        return null;
    }
}
//# sourceMappingURL=envelope.js.map