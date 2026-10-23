"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.computePricing = computePricing;
exports.buyerVisibleBreakdown = buyerVisibleBreakdown;
const money_1 = require("./money");
function computePricing(input) {
    const subtotalPaise = input.lines.reduce((sum, l) => sum + l.unitPaise * l.qty, 0);
    const discountPaise = (0, money_1.min0)(Math.min(input.promoDiscountPaise ?? 0, subtotalPaise));
    const taxableBasePaise = subtotalPaise - discountPaise;
    const feeBasePaise = taxableBasePaise === 0 ? 0 : taxableBasePaise;
    let platformFeePaise = (0, money_1.applyBps)(feeBasePaise, (0, money_1.pctToBps)(input.platformFeePct));
    const allFree = input.lines.every((l) => l.unitPaise === 0);
    if (allFree)
        platformFeePaise = input.freeTicketFeePaise ?? 0;
    const gstOnFeePaise = (0, money_1.applyBps)(platformFeePaise, (0, money_1.pctToBps)(input.gstPct));
    const totalPaise = input.feeBearer === 'buyer'
        ? taxableBasePaise + platformFeePaise + gstOnFeePaise
        : taxableBasePaise;
    return {
        subtotalPaise,
        discountPaise,
        platformFeePaise,
        gstOnFeePaise,
        totalPaise,
        currency: 'INR',
        feeBearer: input.feeBearer,
        feePct: input.platformFeePct,
        gstPct: input.gstPct,
    };
}
function buyerVisibleBreakdown(pricing, feeBearer) {
    const lines = [
        { label: 'Subtotal', amountPaise: pricing.subtotalPaise, kind: 'payable' },
    ];
    if (pricing.discountPaise > 0) {
        lines.push({ label: 'Discount', amountPaise: -pricing.discountPaise, kind: 'discount' });
    }
    if (feeBearer === 'buyer') {
        lines.push({ label: 'Platform fee', amountPaise: pricing.platformFeePaise, kind: 'fee' });
        lines.push({ label: 'GST on platform fee', amountPaise: pricing.gstOnFeePaise, kind: 'fee' });
    }
    lines.push({ label: 'Total', amountPaise: pricing.totalPaise, kind: 'payable' });
    return lines;
}
//# sourceMappingURL=pricing.js.map