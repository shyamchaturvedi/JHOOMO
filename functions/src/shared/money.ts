export const RUPEES_PER_rupee = 100;

export function paiseToRupees(paise: number): number {
  return paise / 100;
}

export function rupeesToPaise(rupees: number): number {
  return Math.round(rupees * 100);
}

export function pctToBps(pct: number): number {
  return Math.round(pct * 100);
}

export function applyBps(amountPaise: number, bps: number): number {
  if (amountPaise <= 0 || bps === 0) return 0;
  const product = amountPaise * bps;
  if (!Number.isSafeInteger(product)) {
    throw new Error('Money overflow: amountPaise * bps exceeds safe integer range');
  }
  return Math.floor((product + 5000) / 10000);
}

export function applyPct(amountPaise: number, pct: number): number {
  return applyBps(amountPaise, pctToBps(pct));
}

export function min0(n: number): number {
  return n < 0 ? 0 : n;
}

export function formatInr(paise: number): string {
  const rupees = paise / 100;
  return `₹${rupees.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function assertIntegerPaise(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${field} must be a non-negative integer number of paise`);
  }
  return value;
}
