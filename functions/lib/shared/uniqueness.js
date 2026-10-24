"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeIndianPhone = normalizeIndianPhone;
exports.normalizePan = normalizePan;
exports.normalizeAccountNumber = normalizeAccountNumber;
exports.hashValue = hashValue;
exports.panHash = panHash;
exports.accountHash = accountHash;
exports.phoneHash = phoneHash;
exports.bankAccountHash = bankAccountHash;
const crypto_1 = require("./crypto");
function normalizeIndianPhone(input) {
    if (!input)
        return '';
    const digits = input.replace(/\D/g, '');
    if (digits.length === 10)
        return `+91${digits}`;
    if (digits.length === 12 && digits.startsWith('91'))
        return `+${digits}`;
    if (digits.length === 11 && digits.startsWith('0')) {
        const trimmed = digits.slice(1);
        return `+91${trimmed}`;
    }
    if (input.trim().startsWith('+91') && digits.length === 12) {
        return `+${digits}`;
    }
    if (digits.length >= 10 && digits.length <= 13) {
        if (digits.startsWith('91') && digits.length === 12)
            return `+${digits}`;
        if (digits.length === 10)
            return `+91${digits}`;
    }
    return input.trim();
}
function normalizePan(input) {
    if (!input)
        return '';
    return input.replace(/\s+/g, '').toUpperCase();
}
function normalizeAccountNumber(input) {
    if (!input)
        return '';
    return input.replace(/\s+/g, '');
}
function hashValue(input) {
    if (!input)
        return '';
    return (0, crypto_1.sha256Hex)(input);
}
function panHash(input) {
    const normalized = normalizePan(input);
    if (!normalized)
        return '';
    return hashValue(normalized);
}
function accountHash(input) {
    const normalized = normalizeAccountNumber(input);
    if (!normalized)
        return '';
    return hashValue(normalized);
}
function phoneHash(input) {
    const normalized = normalizeIndianPhone(input);
    if (!normalized)
        return '';
    return hashValue(normalized);
}
function bankAccountHash(accountNumber, ifsc) {
    const account = normalizeAccountNumber(accountNumber);
    const bank = (ifsc ?? '').replace(/\s+/g, '').toUpperCase();
    if (!account || !bank)
        return '';
    return hashValue(`${bank}|${account}`);
}
//# sourceMappingURL=uniqueness.js.map