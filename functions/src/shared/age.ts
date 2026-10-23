const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

function istParts(d: Date): { year: number; month: number; day: number } {
  const shifted = new Date(d.getTime() + IST_OFFSET_MS);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  };
}

export function ageYears(dob: Date, at: Date = new Date()): number {
  const b = istParts(dob);
  const n = istParts(at);
  let age = n.year - b.year;
  if (n.month < b.month || (n.month === b.month && n.day < b.day)) age -= 1;
  return age;
}

export function isAtLeastAge(dob: Date, minAge: number, at: Date = new Date()): boolean {
  if (Number.isNaN(dob.getTime())) return false;
  return ageYears(dob, at) >= minAge;
}

export function ageBand(dob: Date): '18-24' | '25-34' | '35-44' | '45+' {
  const age = ageYears(dob);
  if (age < 25) return '18-24';
  if (age < 35) return '25-34';
  if (age < 45) return '35-44';
  return '45+';
}

export const MIN_AGE = 18;

export function assertAdult(dob: Date, at: Date = new Date()): void {
  if (!isAtLeastAge(dob, MIN_AGE, at)) {
    throw new Error('AGE_RESTRICTED');
  }
}
