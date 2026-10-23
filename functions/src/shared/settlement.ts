import { applyBps, min0, pctToBps } from './money';

export interface SettlementInputs {
  grossPaise: number;
  refundsPaise: number;
  platformFeePaise: number;
  gstOnFeePaise: number;
  promoterCommissionPaise: number;
  organizerFundedDiscountPaise: number;
  feeBearer: 'buyer' | 'organizer';
}

export interface SettlementResult {
  grossPaise: number;
  refundsPaise: number;
  platformFeePaise: number;
  gstOnFeePaise: number;
  promoterCommissionPaise: number;
  netPaise: number;
}

export function computeSettlement(input: SettlementInputs): SettlementResult {
  const gross = input.grossPaise;
  const refunds = min0(input.refundsPaise);
  const discounts = min0(input.organizerFundedDiscountPaise);
  const commission = min0(input.promoterCommissionPaise);

  const feeDeducted = input.feeBearer === 'organizer';
  const platformFee = feeDeducted ? min0(input.platformFeePaise) : 0;
  const gstOnFee = feeDeducted ? min0(input.gstOnFeePaise) : 0;

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

export type SettlementHoldReason =
  | 'KYC_NOT_APPROVED'
  | 'OPEN_DISPUTE'
  | 'FRAUD_FLAG'
  | 'BANK_CHANGED_RECENTLY'
  | 'EVENT_UNDER_INVESTIGATION'
  | 'FOUR_EYES_REQUIRED';

export interface SettlementHoldInput {
  kycStatus: string;
  hasOpenDispute: boolean;
  hasFraudFlag: boolean;
  bankChangedAt?: Date | null;
  now?: Date;
  underInvestigation: boolean;
  netPaise: number;
  fourEyesThresholdPaise: number;
  approvals: Array<{ by: string }>;
}

export interface SettlementHoldResult {
  holdReasons: SettlementHoldReason[];
  needsFourEyes: boolean;
  eligible: boolean;
}

export function evaluateSettlementHolds(input: SettlementHoldInput): SettlementHoldResult {
  const now = input.now ?? new Date();
  const holdReasons: SettlementHoldReason[] = [];

  if (input.kycStatus !== 'approved') holdReasons.push('KYC_NOT_APPROVED');
  if (input.hasOpenDispute) holdReasons.push('OPEN_DISPUTE');
  if (input.hasFraudFlag) holdReasons.push('FRAUD_FLAG');
  if (input.underInvestigation) holdReasons.push('EVENT_UNDER_INVESTIGATION');
  if (input.bankChangedAt && now.getTime() - input.bankChangedAt.getTime() < 48 * 60 * 60 * 1000) {
    holdReasons.push('BANK_CHANGED_RECENTLY');
  }

  const needsFourEyes =
    input.netPaise > input.fourEyesThresholdPaise && input.approvals.length < 2;
  if (needsFourEyes) holdReasons.push('FOUR_EYES_REQUIRED');

  return {
    holdReasons,
    needsFourEyes,
    eligible: holdReasons.length === 0,
  };
}

export interface CommissionCalc {
  basePaise: number;
  pct: number;
  amountPaise: number;
}

export function computeCommission(taxableBasePaise: number, commissionPct: number): CommissionCalc {
  const amountPaise = applyBps(taxableBasePaise, pctToBps(commissionPct));
  return { basePaise: taxableBasePaise, pct: commissionPct, amountPaise };
}
