import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../shared/admin';
import { computeCommission } from '../shared/settlement';

export interface FinanceLine {
  tierId: string;
  qty: number;
  unitPaise: number;
}

/**
 * Applies a confirmed booking to the event finance ledger.
 * Called from the Razorpay capture path so ticket counts, gross, discounts,
 * fees and promoter commission always move together.
 */
export async function recordConfirmedBooking(params: {
  eventId: string;
  bookingId: string;
  lines: FinanceLine[];
  grossPaise: number;
  discountPaise: number;
  platformFeePaise: number;
  gstOnFeePaise: number;
  feeBearer: 'buyer' | 'organizer';
  promoterId?: string | null;
  commissionPct?: number;
  organizerFundedDiscountPaise?: number;
}): Promise<{ commissionPaise: number }> {
  const financeRef = db().collection('eventFinance').doc(params.eventId);

  let commissionPaise = 0;
  if (params.promoterId && (params.commissionPct ?? 0) > 0) {
    const taxableBase = params.grossPaise - params.discountPaise;
    const commission = computeCommission(taxableBase, params.commissionPct!);
    commissionPaise = commission.amountPaise;

    await db()
      .collection('commissions')
      .add({
        schemaVersion: 1,
        promoterId: params.promoterId,
        bookingId: params.bookingId,
        eventId: params.eventId,
        basePaise: commission.basePaise,
        pct: commission.pct,
        amountPaise: commission.amountPaise,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      })
      .catch(() => undefined);
  }

  const byTier: Record<string, { sold: number; grossPaise: number }> = {};
  for (const line of params.lines) {
    const current = byTier[line.tierId] ?? { sold: 0, grossPaise: 0 };
    current.sold += line.qty;
    current.grossPaise += line.unitPaise * line.qty;
    byTier[line.tierId] = current;
  }

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(financeRef);
    const data = snap.data() ?? {};
    const existingByTier = (data.byTier ?? {}) as Record<string, { sold: number; grossPaise: number }>;
    const merged: Record<string, { sold: number; grossPaise: number }> = { ...existingByTier };
    for (const [tierId, value] of Object.entries(byTier)) {
      const prev = merged[tierId] ?? { sold: 0, grossPaise: 0 };
      merged[tierId] = { sold: prev.sold + value.sold, grossPaise: prev.grossPaise + value.grossPaise };
    }

    tx.set(
      financeRef,
      {
        schemaVersion: 1,
        eventId: params.eventId,
        ticketsSold: Number(data.ticketsSold ?? 0) + params.lines.reduce((s, l) => s + l.qty, 0),
        grossPaise: Number(data.grossPaise ?? 0) + params.grossPaise,
        discountPaise: Number(data.discountPaise ?? 0) + params.discountPaise,
        refundsPaise: Number(data.refundsPaise ?? 0),
        platformFeePaise: Number(data.platformFeePaise ?? 0) + params.platformFeePaise,
        gstOnFeePaise: Number(data.gstOnFeePaise ?? 0) + params.gstOnFeePaise,
        promoterCommissionPaise: Number(data.promoterCommissionPaise ?? 0) + commissionPaise,
        netPayablePaise:
          Number(data.netPayablePaise ?? 0) +
          params.grossPaise -
          params.discountPaise -
          params.platformFeePaise -
          params.gstOnFeePaise -
          commissionPaise,
        byTier: merged,
        feeBearer: params.feeBearer,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  return { commissionPaise };
}

/** Applies a settled refund to the event finance ledger. */
export async function recordRefund(params: {
  eventId: string;
  amountPaise: number;
}): Promise<void> {
  const financeRef = db().collection('eventFinance').doc(params.eventId);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(financeRef);
    const data = snap.data() ?? {};
    tx.set(
      financeRef,
      {
        refundsPaise: Number(data.refundsPaise ?? 0) + params.amountPaise,
        netPayablePaise: Math.max(0, Number(data.netPayablePaise ?? 0) - params.amountPaise),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

/** Daily ledger row used by the organiser sales report (PRD §11.2). */
export async function recordDailyLedger(params: {
  eventId: string;
  dateKey: string;
  tickets: number;
  grossPaise: number;
  refundsPaise: number;
}): Promise<void> {
  const ref = db().collection('eventFinance').doc(params.eventId).collection('daily').doc(params.dateKey);
  await ref.set(
    {
      schemaVersion: 1,
      dateKey: params.dateKey,
      tickets: FieldValue.increment(params.tickets),
      grossPaise: FieldValue.increment(params.grossPaise),
      refundsPaise: FieldValue.increment(params.refundsPaise),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

export async function markEventCompleted(eventId: string): Promise<void> {
  const ref = db().collection('events').doc(eventId);
  await ref.set({ status: 'completed', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
}
