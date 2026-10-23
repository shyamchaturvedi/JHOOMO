"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateEventGateKeyPair = generateEventGateKeyPair;
exports.signOfflineQr = signOfflineQr;
exports.verifyOfflineQr = verifyOfflineQr;
exports.buildOfflinePayload = buildOfflinePayload;
exports.buildStaticOfflinePayload = buildStaticOfflinePayload;
exports.parseQrPayload = parseQrPayload;
const node_crypto_1 = require("node:crypto");
const crypto_1 = require("./crypto");
/** Per-event Ed25519 keypair used to sign offline gate QR payloads. */
function generateEventGateKeyPair() {
    const { publicKey, privateKey } = (0, node_crypto_1.generateKeyPairSync)('ed25519');
    return {
        publicKeyB64: publicKey.export({ type: 'spki', format: 'der' }).toString('base64'),
        privateKeyPem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
    };
}
function signOfflineQr(privateKeyPem, ticketId, eventId, ts) {
    const key = (0, node_crypto_1.createPrivateKey)(privateKeyPem);
    return (0, crypto_1.b64url)((0, node_crypto_1.sign)(null, Buffer.from(`${ticketId}|${eventId}|${ts}`), key));
}
function verifyOfflineQr(publicKeyB64, ticketId, eventId, ts, signature) {
    try {
        const key = (0, node_crypto_1.createPublicKey)({
            key: Buffer.from(publicKeyB64, 'base64'),
            format: 'der',
            type: 'spki',
        });
        return (0, node_crypto_1.verify)(null, Buffer.from(`${ticketId}|${eventId}|${ts}`), key, Buffer.from(signature, 'base64url'));
    }
    catch {
        return false;
    }
}
function buildOfflinePayload(ticketId, eventId, ts, signature) {
    return `MILO1S.${eventId}.${ticketId}.${ts}.${signature}`;
}
function buildStaticOfflinePayload(ticketId, eventId, signature) {
    return `MILO1S.${eventId}.${ticketId}.${signature}`;
}
function parseQrPayload(payload) {
    const parts = payload.trim().split('.');
    if (parts[0] === 'MILO1' && parts.length === 4) {
        return { kind: 'dynamic', ticketId: parts[1], ts: Number(parts[2]), signature: parts[3] };
    }
    if (parts[0] === 'MILO1S' && parts.length === 5) {
        return {
            kind: 'static',
            eventId: parts[1],
            ticketId: parts[2],
            ts: Number(parts[3]),
            signature: parts[4],
        };
    }
    if (parts[0] === 'MILO1S' && parts.length === 4) {
        return { kind: 'static', eventId: parts[1], ticketId: parts[2], signature: parts[3] };
    }
    return null;
}
//# sourceMappingURL=gatekeys.js.map