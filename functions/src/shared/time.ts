const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

export function istShifted(d: Date): Date {
  return new Date(d.getTime() + IST_OFFSET_MS);
}

export function istDateKey(d: Date): string {
  const s = istShifted(d);
  return `${s.getUTCFullYear()}${String(s.getUTCMonth() + 1).padStart(2, '0')}${String(s.getUTCDate()).padStart(2, '0')}`;
}

export function istHour(d: Date): number {
  return istShifted(d).getUTCHours();
}

export function istDayStartUtc(d: Date): Date {
  const s = istShifted(d);
  return new Date(Date.UTC(s.getUTCFullYear(), s.getUTCMonth(), s.getUTCDate()) - IST_OFFSET_MS);
}

export function istDayEndUtc(d: Date): Date {
  return new Date(istDayStartUtc(d).getTime() + 24 * 60 * 60 * 1000 - 1);
}

export function istHourUtc(dateKey: string, hour: number): Date {
  const y = Number(dateKey.slice(0, 4));
  const m = Number(dateKey.slice(4, 6)) - 1;
  const day = Number(dateKey.slice(6, 8));
  return new Date(Date.UTC(y, m, day, hour, 0, 0) - IST_OFFSET_MS);
}

/** Indian financial year (1 April – 31 March) in IST. */
export function indianFinancialYear(d: Date): { key: string; start: Date; end: Date } {
  const s = istShifted(d);
  const year = s.getUTCFullYear();
  const fyStartYear = s.getUTCMonth() >= 3 ? year : year - 1;
  const startUtc = new Date(Date.UTC(fyStartYear, 3, 1) - IST_OFFSET_MS);
  const endUtc = new Date(Date.UTC(fyStartYear + 1, 2, 31, 23, 59, 59) - IST_OFFSET_MS);
  return { key: `${fyStartYear}-${String((fyStartYear + 1) % 100).padStart(2, '0')}`, start: startUtc, end: endUtc };
}

/** Settlement is scheduled for 11:00 IST on the day after the event's last day (PRD §8.3). */
export function settlementScheduledFor(eventEndAt: Date): Date {
  const nextDay = new Date(istDayStartUtc(eventEndAt).getTime() + 24 * 60 * 60 * 1000);
  const nextDayKey = istDateKey(nextDay);
  return istHourUtc(nextDayKey, 11);
}

export function hoursBetween(from: Date, to: Date): number {
  return (to.getTime() - from.getTime()) / (60 * 60 * 1000);
}

export function addMinutes(d: Date, minutes: number): Date {
  return new Date(d.getTime() + minutes * 60 * 1000);
}

export function addDays(d: Date, days: number): Date {
  return new Date(d.getTime() + days * 24 * 60 * 60 * 1000);
}
