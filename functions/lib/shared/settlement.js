"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.computeSettlement = computeSettlement;
exports.evaluateSettlementHolds = evaluateSettlementHolds;
exports.computeCommission = computeCommission;
const money_1 = require("./money");
function computeSettlement(input) {
    const gross = input.grossPaise;
    const refunds = (0, money_1.min0)(input.refundsPaise);
    const discounts = (0, money_1.min0)(input.organizerFundedDiscountPaise);
    const commission = (0, money_1.min0)(input.promoterCommissionPaise);
    const feeDeducted = input.feeBearer === 'organizer';
    const platformFee = feeDeducted ? (0, money_1.min0)(input.platformFeePaise) : 0;
    const gstOnFee = feeDeducted ? (0, money_1.min0)(input.gstOnFeePaise) : 0;
    const net = gross - discounts - refunds - platformFee - gstOnFee - commission;
    return {
        grossPaise: gross,
        refundsPaise: refunds,
        platformFeePaise: platformFee,
        gstOnFeePaise: gstOnFee,
        promoterCommissionPaise: commission,
        netPaise: Math.max(0, net),
    };
}
function evaluateSettlementHolds(input) {
    const now = input.now ?? new Date();
    const holdReasons = [];
    if (input.kycStatus !== 'approved')
        holdReasons.push('KYC_NOT_APPROVED');
    if (input.hasOpenDispute)
        holdReasons.push('OPEN_DISPUTE');
    if (input.hasFraudFlag)
        holdReasons.push('FRAUD_FLAG');
    if (input.underInvestigation)
        holdReasons.push('EVENT_UNDER_INVESTIGATION');
    if (input.bankChangedAt && now.getTime() - input.bankChangedAt.getTime() < 48 * 60 * 60 * 1000) {
        holdReasons.push('BANK_CHANGED_RECENTLY');
    }
    const needsFourEyes = input.netPaise > input.fourEyesThresholdPaise && input.approvals.length < 2;
    if (needsFourEyes)
        holdReasons.push('FOUR_EYES_REQUIRED');
    return {
        holdReasons,
        needsFourEyes,
        eligible: holdReasons.length === 0,
    };
}
function computeCommission(taxableBasePaise, commissionPct) {
    const amountPaise = (0, money_1.applyBps)(taxableBasePaise, (0, money_1.pctToBps)(commissionPct));
    return { basePaise: taxableBasePaise, pct: commissionPct, amountPaise };
}
//# sourceMappingURL=settlement.js.map