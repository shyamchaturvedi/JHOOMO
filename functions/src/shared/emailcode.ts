import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { randomInt } from 'node:crypto';
import { db } from './admin';
import { sha256Hex } from './crypto';
import { sendSms } from './vendors';

export type EmailCodePurpose = 'link_email' | 'organizer_email';

interface EmailCodeRecord {
  hash: string;
  purpose: EmailCodePurpose;
  expiresAt: Timestamp;
  attempts: number;
}

function codeKey(email: string, purpose: EmailCodePurpose): string {
  return `${purpose}_${sha256Hex(email.toLowerCase()).slice(0, 32)}`;
}

export function generateEmailCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

export async function issueEmailCode(
  email: string,
  purpose: EmailCodePurpose,
  ttlMinutes = 15,
): Promise<string> {
  const code = generateEmailCode();
  const ref = db().collection('emailCodes').doc(codeKey(email, purpose));
  await ref.set(
    {
      hash: sha256Hex(`${code}:${purpose}`),
      purpose,
      attempts: 0,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + ttlMinutes * 60 * 1000),
    },
    { merge: true },
  );
  return code;
}

export async function verifyEmailCode(
  email: string,
  code: string,
  purpose: EmailCodePurpose,
): Promise<boolean> {
  const ref = db().collection('emailCodes').doc(codeKey(email, purpose));
  const snap = await ref.get();
  if (!snap.exists) return false;
  const data = snap.data() as EmailCodeRecord;
  const expired = data.expiresAt.toMillis() < Date.now();
  const expected = sha256Hex(`${code}:${purpose}`);
  const ok = !expired && data.hash === expected;
  if (!ok) {
    const attempts = Number(data.attempts ?? 0) + 1;
    await ref.set({ attempts }, { merge: true });
    if (attempts >= 5) await ref.delete();
    return false;
  }
  await ref.delete();
  return true;
}

export async function deliverEmailCode(email: string, code: string): Promise<void> {
  const result = await sendSms({ to: email, body: code });
  if (!result.sent) {
    console.warn('Email code delivery skipped (no DLT provider configured).');
  }
}
