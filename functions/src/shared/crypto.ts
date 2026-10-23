import {
  createHmac,
  randomBytes,
  randomInt,
  scryptSync,
  timingSafeEqual,
  createHash,
} from 'node:crypto';

export const QR_TOKEN_TTL_SECONDS = 60;

export function b64url(buf: Buffer): string {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function signQrToken(secretB64: string, ticketId: string, userId: string, tsSeconds: number): string {
  const secret = Buffer.from(secretB64, 'base64');
  const mac = createHmac('sha256', secret).update(`${ticketId}|${userId}|${tsSeconds}`).digest();
  return b64url(mac.subarray(0, 16));
}

export function verifyQrToken(
  secretB64: string,
  ticketId: string,
  userId: string,
  tsSeconds: number,
  signature: string,
): boolean {
  const expected = signQrToken(secretB64, ticketId, userId, tsSeconds);
  const a = Buffer.from(expected);
  const b = Buffer.from(signature);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

export function generatePasscode(): string {
  return String(randomInt(0, 1000000)).padStart(6, '0');
}

export function hashPasscode(passcode: string, salt: string): string {
  return scryptSync(passcode, salt, 32).toString('base64');
}

export function verifyPasscode(passcode: string, salt: string, expectedHash: string): boolean {
  const actual = Buffer.from(hashPasscode(passcode, salt));
  const expected = Buffer.from(expectedHash);
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}

export function newSalt(): string {
  return randomBytes(16).toString('base64');
}

export function randomToken(bytes = 32): string {
  return b64url(randomBytes(bytes));
}

export function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

export function maskPan(pan: string): string {
  if (pan.length < 5) return '****';
  return `${pan.slice(0, 5)}****${pan.slice(-1)}`;
}

export function maskAccount(account: string): string {
  if (account.length < 4) return '****';
  return `****${account.slice(-4)}`;
}

export function maskPhone(phone: string): string {
  if (phone.length < 4) return 'XXXX';
  return `XXXXXX ${phone.slice(-3)}`;
}
