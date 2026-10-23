"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RUPEES_PER_rupee = void 0;
exports.paiseToRupees = paiseToRupees;
exports.rupeesToPaise = rupeesToPaise;
exports.pctToBps = pctToBps;
exports.applyBps = applyBps;
exports.applyPct = applyPct;
exports.min0 = min0;
exports.formatInr = formatInr;
exports.assertIntegerPaise = assertIntegerPaise;
exports.RUPEES_PER_rupee = 100;
function paiseToRupees(paise) {
    return paise / 100;
}
function rupeesToPaise(rupees) {
    return Math.round(rupees * 100);
}
function pctToBps(pct) {
    return Math.round(pct * 100);
}
function applyBps(amountPaise, bps) {
    if (amountPaise <= 0 || bps === 0)
        return 0;
    const product = amountPaise * bps;
    if (!Number.isSafeInteger(product)) {
        throw new Error('Money overflow: amountPaise * bps exceeds safe integer range');
    }
    return Math.floor((product + 5000) / 10000);
}
function applyPct(amountPaise, pct) {
    return applyBps(amountPaise, pctToBps(pct));
}
function min0(n) {
    return n < 0 ? 0 : n;
}
function formatInr(paise) {
    const rupees = paise / 100;
    return `₹${rupees.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}
function assertIntegerPaise(value, field) {
    if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
        throw new Error(`${field} must be a non-negative integer number of paise`);
    }
    return value;
}
//# sourceMappingURL=money.js.map