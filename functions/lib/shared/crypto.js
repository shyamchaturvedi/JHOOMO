"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.QR_TOKEN_TTL_SECONDS = void 0;
exports.b64url = b64url;
exports.signQrToken = signQrToken;
exports.verifyQrToken = verifyQrToken;
exports.generatePasscode = generatePasscode;
exports.hashPasscode = hashPasscode;
exports.verifyPasscode = verifyPasscode;
exports.newSalt = newSalt;
exports.randomToken = randomToken;
exports.sha256Hex = sha256Hex;
exports.maskPan = maskPan;
exports.maskAccount = maskAccount;
exports.maskPhone = maskPhone;
const node_crypto_1 = require("node:crypto");
exports.QR_TOKEN_TTL_SECONDS = 60;
function b64url(buf) {
    return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function signQrToken(secretB64, ticketId, userId, tsSeconds) {
    const secret = Buffer.from(secretB64, 'base64');
    const mac = (0, node_crypto_1.createHmac)('sha256', secret).update(`${ticketId}|${userId}|${tsSeconds}`).digest();
    return b64url(mac.subarray(0, 16));
}
function verifyQrToken(secretB64, ticketId, userId, tsSeconds, signature) {
    const expected = signQrToken(secretB64, ticketId, userId, tsSeconds);
    const a = Buffer.from(expected);
    const b = Buffer.from(signature);
    if (a.length !== b.length)
        return false;
    return (0, node_crypto_1.timingSafeEqual)(a, b);
}
function generatePasscode() {
    return String((0, node_crypto_1.randomInt)(0, 1000000)).padStart(6, '0');
}
function hashPasscode(passcode, salt) {
    return (0, node_crypto_1.scryptSync)(passcode, salt, 32).toString('base64');
}
function verifyPasscode(passcode, salt, expectedHash) {
    const actual = Buffer.from(hashPasscode(passcode, salt));
    const expected = Buffer.from(expectedHash);
    if (actual.length !== expected.length)
        return false;
    return (0, node_crypto_1.timingSafeEqual)(actual, expected);
}
function newSalt() {
    return (0, node_crypto_1.randomBytes)(16).toString('base64');
}
function randomToken(bytes = 32) {
    return b64url((0, node_crypto_1.randomBytes)(bytes));
}
function sha256Hex(input) {
    return (0, node_crypto_1.createHash)('sha256').update(input).digest('hex');
}
function maskPan(pan) {
    if (pan.length < 5)
        return '****';
    return `${pan.slice(0, 5)}****${pan.slice(-1)}`;
}
function maskAccount(account) {
    if (account.length < 4)
        return '****';
    return `****${account.slice(-4)}`;
}
function maskPhone(phone) {
    if (phone.length < 4)
        return 'XXXX';
    return `XXXXXX ${phone.slice(-3)}`;
}
//# sourceMappingURL=crypto.js.map