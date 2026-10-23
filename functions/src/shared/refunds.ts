import { hoursBetween } from './time';

export type RefundPolicyType = 'none' | 'full_until' | 'tiered';

export interface RefundPolicy {
  type: RefundPolicyType;
  hoursBefore?: number;
  tiers?: Array<{ hoursBefore: number; refundPct: number }>;
}

export type RefundInitiator = 'user' | 'organizer_cancel' | 'admin' | 'system';

export interface RefundDecision {
  eligible: boolean;
  autoApprove: boolean;
  refundPct: number;
  ticketAmountRefundablePaise: number;
  feeRefundablePaise: number;
  needsReview: boolean;
  reason: string;
}

export interface RefundContext {
  policy: RefundPolicy;
  eventStartAt: Date;
  tierId?: string;
  now?: Date;
  initiator: RefundInitiator;
  ticketAmountPaise: number;
  platformFeePaise: number;
  gstOnFeePaise: number;
  refundPlatformFee: boolean;
  alreadyCheckedIn: boolean;
  technicalFailure?: boolean;
  duplicatePayment?: boolean;
}

/**
 * PRD v4 §8.2 — refund matrix.
 * Organiser/admin cancellation always refunds 100% of ticket value and fees.
 */
export function evaluateRefund(ctx: RefundContext): RefundDecision {
  const now = ctx.now ?? new Date();
  const feeTotal = ctx.platformFeePaise + ctx.gstOnFeePaise;

  if (ctx.alreadyCheckedIn) {
    return {
      eligible: false,
      autoApprove: false,
      refundPct: 0,
      ticketAmountRefundablePaise: 0,
      feeRefundablePaise: 0,
      needsReview: false,
      reason: 'Ticket already checked in — not refundable.',
    };
  }

  if (ctx.initiator === 'organizer_cancel' || ctx.initiator === 'admin') {
    return {
      eligible: true,
      autoApprove: true,
      refundPct: 100,
      ticketAmountRefundablePaise: ctx.ticketAmountPaise,
      feeRefundablePaise: feeTotal,
      needsReview: false,
      reason: 'Event cancelled — 100% refund including platform fee and GST.',
    };
  }

  const hoursUntilEvent = hoursBetween(now, ctx.eventStartAt);
  let refundPct = 0;
  let reason = 'Outside the refund policy window.';

  if (ctx.policy.type === 'full_until') {
    const cutOff = ctx.policy.hoursBefore ?? 0;
    if (hoursUntilEvent >= cutOff) {
      refundPct = 100;
      reason = `Inside the full-refund window (≥ ${cutOff}h before start).`;
    }
  } else if (ctx.policy.type === 'tiered') {
    const rows = [...(ctx.policy.tiers ?? [])].sort((a, b) => b.hoursBefore - a.hoursBefore);
    const match = rows.find((row) => hoursUntilEvent >= row.hoursBefore);
    if (match) {
      refundPct = match.refundPct;
      reason = `Tiered policy: ${match.refundPct}% refund for requests ≥ ${match.hoursBefore}h before start.`;
    }
  } else {
    reason = 'This event has a no-refund policy.';
  }

  if (refundPct > 0) {
    const ticketRefund = Math.floor((ctx.ticketAmountPaise * refundPct) / 100);
    const feeRefund = ctx.refundPlatformFee ? feeTotal : 0;
    return {
      eligible: true,
      autoApprove: true,
      refundPct,
      ticketAmountRefundablePaise: ticketRefund,
      feeRefundablePaise: feeRefund,
      needsReview: false,
      reason,
    };
  }

  if (ctx.technicalFailure || ctx.duplicatePayment) {
    return {
      eligible: true,
      autoApprove: false,
      refundPct: 100,
      ticketAmountRefundablePaise: ctx.ticketAmountPaise,
      feeRefundablePaise: feeTotal,
      needsReview: true,
      reason: ctx.technicalFailure
        ? 'Technical failure — needs admin approval.'
        : 'Duplicate payment — needs admin approval.',
    };
  }

  return {
    eligible: false,
    autoApprove: false,
    refundPct: 0,
    ticketAmountRefundablePaise: 0,
    feeRefundablePaise: 0,
    needsReview: false,
    reason,
  };
}
