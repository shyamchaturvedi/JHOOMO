import { applyBps, min0, pctToBps } from './money';

export type FeeBearer = 'buyer' | 'organizer';

export interface PricingLine {
  tierId: string;
  tierName: string;
  qty: number;
  unitPaise: number;
  admits: number;
  holderNames?: string[];
}

export interface PricingInput {
  lines: PricingLine[];
  promoDiscountPaise?: number;
  platformFeePct: number;
  gstPct: number;
  feeBearer: FeeBearer;
  freeTicketFeePaise?: number;
}

export interface Pricing {
  subtotalPaise: number;
  discountPaise: number;
  platformFeePaise: number;
  gstOnFeePaise: number;
  totalPaise: number;
  currency: 'INR';
  feeBearer: FeeBearer;
  feePct: number;
  gstPct: number;
}

export function computePricing(input: PricingInput): Pricing {
  const subtotalPaise = input.lines.reduce((sum, l) => sum + l.unitPaise * l.qty, 0);
  const discountPaise = min0(Math.min(input.promoDiscountPaise ?? 0, subtotalPaise));
  const taxableBasePaise = subtotalPaise - discountPaise;

  const feeBasePaise = taxableBasePaise === 0 ? 0 : taxableBasePaise;
  let platformFeePaise = applyBps(feeBasePaise, pctToBps(input.platformFeePct));

  const allFree = input.lines.every((l) => l.unitPaise === 0);
  if (allFree) platformFeePaise = input.freeTicketFeePaise ?? 0;

  const gstOnFeePaise = applyBps(platformFeePaise, pctToBps(input.gstPct));

  const totalPaise =
    input.feeBearer === 'buyer'
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

export interface FeeBreakdownLine {
  label: string;
  amountPaise: number;
  kind: 'payable' | 'discount' | 'fee';
}

export function buyerVisibleBreakdown(
  pricing: Pricing,
  feeBearer: FeeBearer,
): FeeBreakdownLine[] {
  const lines: FeeBreakdownLine[] = [
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
