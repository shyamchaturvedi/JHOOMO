import { db } from './admin';
import { randomBytes } from 'node:crypto';

export function newId(prefix: string): string {
  return `${prefix}_${randomBytes(9).toString('hex')}`;
}

export async function nextBookingRef(): Promise<string> {
  const refColl = db().collection('bookingRefs');
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const digits = String(Math.floor(Math.random() * 1_000_000)).padStart(6, '0');
    const ref = `MILO-${digits}`;
    const docRef = refColl.doc(ref);
    try {
      await docRef.create({ bookingId: '', createdAt: new Date() });
      return ref;
    } catch {
      // Reference already taken, retry with a new random suffix.
    }
  }
  throw new Error('Unable to allocate a unique booking reference');
}

export async function bindBookingRef(ref: string, bookingId: string): Promise<void> {
  await db().collection('bookingRefs').doc(ref).set({ bookingId }, { merge: true });
}

export function dateKey(d: Date): string {
  const shifted = new Date(d.getTime() + 5.5 * 60 * 60 * 1000);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const day = String(shifted.getUTCDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}
