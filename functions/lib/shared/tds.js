"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.computeTds = computeTds;
const money_1 = require("./money");
const time_1 = require("./time");
/**
 * TDS on promoter commission / brokerage.
 *
 * Decision recorded for PRD v4 §16 OPEN-9:
 *   - Default rate 2% (Sec. 194H commission/brokerage; renumbered as Sec. 393
 *     of the Income-tax Act, 2025) — CA to confirm.
 *   - ₹20,000 per financial year threshold; only the excess is taxable.
 *   - PAN is mandatory. Without PAN, Sec. 206AA applies at the configured
 *     higher rate (default 20%) on the full amount.
 *   - Rate and threshold are config-driven so Finance can change them without
 *     a code deploy.
 */
function computeTds(input) {
    const now = input.now ?? new Date();
    const fy = (0, time_1.indianFinancialYear)(now);
    const amount = Math.max(0, input.amountPaise);
    if (amount === 0) {
        return {
            tdsPaise: 0,
            taxablePaise: 0,
            ratePct: 0,
            thresholdApplied: false,
            panMissing: !input.panPresent,
            financialYear: fy.key,
            reason: 'No commission payable.',
        };
    }
    if (!input.panPresent) {
        const tdsPaise = (0, money_1.applyBps)(amount, (0, money_1.pctToBps)(input.rateWithoutPanPct));
        return {
            tdsPaise,
            taxablePaise: amount,
            ratePct: input.rateWithoutPanPct,
            thresholdApplied: false,
            panMissing: true,
            financialYear: fy.key,
            reason: 'PAN not on file — higher Sec. 206AA rate applied on the full commission; TDS deducted at payout.',
        };
    }
    const thresholdRoom = Math.max(0, input.thresholdPaise - input.fyAlreadyPaidPaise);
    const taxablePaise = Math.max(0, amount - thresholdRoom);
    const thresholdApplied = taxablePaise < amount;
    const tdsPaise = (0, money_1.applyBps)(taxablePaise, (0, money_1.pctToBps)(input.tdsPct));
    return {
        tdsPaise,
        taxablePaise,
        ratePct: input.tdsPct,
        thresholdApplied,
        panMissing: false,
        financialYear: fy.key,
        reason: thresholdApplied
            ? `₹20,000 FY threshold applied; TDS on the excess only.`
            : `TDS deducted on the full commission at ${input.tdsPct}%.`,
    };
}
//# sourceMappingURL=tds.js.map