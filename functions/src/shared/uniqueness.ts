import { sha256Hex } from './crypto';

export function normalizeIndianPhone(input: string | null | undefined): string {
  if (!input) return '';
  const digits = input.replace(/\D/g, '');
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  if (digits.length === 11 && digits.startsWith('0')) {
    const trimmed = digits.slice(1);
    return `+91${trimmed}`;
  }
  if (input.trim().startsWith('+91') && digits.length === 12) {
    return `+${digits}`;
  }
  if (digits.length >= 10 && digits.length <= 13) {
    if (digits.startsWith('91') && digits.length === 12) return `+${digits}`;
    if (digits.length === 10) return `+91${digits}`;
  }
  return input.trim();
}

export function normalizePan(input: string | null | undefined): string {
  if (!input) return '';
  return input.replace(/\s+/g, '').toUpperCase();
}

export function normalizeAccountNumber(input: string | null | undefined): string {
  if (!input) return '';
  return input.replace(/\s+/g, '');
}

export function hashValue(input: string): string {
  if (!input) return '';
  return sha256Hex(input);
}

export function panHash(input: string | null | undefined): string {
  const normalized = normalizePan(input);
  if (!normalized) return '';
  return hashValue(normalized);
}

export function accountHash(input: string | null | undefined): string {
  const normalized = normalizeAccountNumber(input);
  if (!normalized) return '';
  return hashValue(normalized);
}

export function phoneHash(input: string | null | undefined): string {
  const normalized = normalizeIndianPhone(input);
  if (!normalized) return '';
  return hashValue(normalized);
}

export function bankAccountHash(
  accountNumber: string | null | undefined,
  ifsc: string | null | undefined,
): string {
  const account = normalizeAccountNumber(accountNumber);
  const bank = (ifsc ?? '').replace(/\s+/g, '').toUpperCase();
  if (!account || !bank) return '';
  return hashValue(`${bank}|${account}`);
}
