import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../shared/admin';
import { MiloError } from '../shared/errors';
import { applyBps, min0, pctToBps } from '../shared/money';
import { PricingLine } from '../shared/pricing';

export interface PromoCodeDoc {
  code: string;
  eventId: string | null;
  organizerId: string | null;
  createdBy: 'organizer' | 'admin';
  type: 'percent' | 'flat';
  value: number;
  maxUses: number;
  usedCount: number;
  perUserLimit: number;
  validFrom: Timestamp;
  validTo: Timestamp;
  tierIds?: string[];
  minOrderPaise?: number;
  fundedBy: 'organizer' | 'milo';
  active: boolean;
}

export interface PromoEvaluation {
  doc: PromoCodeDoc;
  docId: string;
  discountPaise: number;
  fundedBy: 'organizer' | 'milo';
}

export async function loadPromo(
  code: string,
  eventId: string,
): Promise<{ doc: PromoCodeDoc; docId: string } | null> {
  const normalised = code.trim().toUpperCase();
  const eventScoped = await db().collection('promoCodes').doc(`${eventId}_${normalised}`).get();
  if (eventScoped.exists) {
    return { doc: eventScoped.data() as PromoCodeDoc, docId: eventScoped.id };
  }
  const platform = await db().collection('promoCodes').doc(`PLATFORM_${normalised}`).get();
  if (platform.exists) {
    return { doc: platform.data() as PromoCodeDoc, docId: platform.id };
  }
  return null;
}

export async function evaluatePromo(params: {
  code: string;
  eventId: string;
  userId: string;
  lines: PricingLine[];
  subtotalPaise: number;
  now?: Date;
}): Promise<PromoEvaluation> {
  const now = params.now ?? new Date();
  const loaded = await loadPromo(params.code, params.eventId);
  if (!loaded) throw new MiloError('INVALID_INPUT', 'That promo code is not valid.', { reason: 'NOT_FOUND' });

  const promo = loaded.doc;
  if (!promo.active) throw new MiloError('INVALID_INPUT', 'That promo code is not active.', { reason: 'INACTIVE' });
  if (promo.validFrom && promo.validFrom.toMillis() > now.getTime()) {
    throw new MiloError('INVALID_INPUT', 'That promo code is not active yet.', { reason: 'NOT_STARTED' });
  }
  if (promo.validTo && promo.validTo.toMillis() < now.getTime()) {
    throw new MiloError('INVALID_INPUT', 'That promo code has expired.', { reason: 'EXPIRED' });
  }
  if (promo.maxUses > 0 && Number(promo.usedCount ?? 0) >= promo.maxUses) {
    throw new MiloError('INVALID_INPUT', 'That promo code has reached its usage limit.', { reason: 'MAX_USES' });
  }
  if (promo.minOrderPaise && params.subtotalPaise < promo.minOrderPaise) {
    throw new MiloError('INVALID_INPUT', 'Your order does not meet the minimum value for this code.', {
      reason: 'MIN_ORDER',
    });
  }
  if (promo.tierIds && promo.tierIds.length > 0) {
    const applicable = params.lines.some((l) => promo.tierIds!.includes(l.tierId));
    if (!applicable) {
      throw new MiloError('INVALID_INPUT', 'That promo code does not apply to the selected tickets.', {
        reason: 'TIER_MISMATCH',
      });
    }
  }

  const userUsage = await db()
    .collection('bookings')
    .where('userId', '==', params.userId)
    .where('promo.code', '==', promo.code)
    .where('status', 'in', ['confirmed', 'pending_payment', 'completed', 'refunded_partial'])
    .get();

  const nowMs = now.getTime();
  const usedCount = userUsage.docs.filter((d) => {
    const data = d.data();
    if (data.status === 'pending_payment') {
      // Only an abandoned hold should not burn the user's promo quota.
      const expiresAt = data.reservationExpiresAt as Timestamp | undefined;
      return !expiresAt || expiresAt.toMillis() > nowMs;
    }
    return data.status !== 'cancelled_by_user';
  }).length;

  if (promo.perUserLimit > 0 && usedCount >= promo.perUserLimit) {
    throw new MiloError('INVALID_INPUT', 'You have already used this promo code.', { reason: 'PER_USER_LIMIT' });
  }

  const discountPaise =
    promo.type === 'percent'
      ? applyBps(params.subtotalPaise, pctToBps(promo.value))
      : min0(promo.value);

  return {
    doc: promo,
    docId: loaded.docId,
    discountPaise: min0(discountPaise),
    fundedBy: promo.fundedBy,
  };
}

export async function incrementPromoUsage(docId: string): Promise<void> {
  await db()
    .collection('promoCodes')
    .doc(docId)
    .set({ usedCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
}
