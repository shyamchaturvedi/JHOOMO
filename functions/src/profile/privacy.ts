import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { createHash, randomBytes } from 'node:crypto';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { getLimitsConfig } from '../shared/config';
import { sendSms } from '../shared/sms';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';

const CONTACT_TOKEN_TTL_HOURS = 72;
const WEB_BASE_URL = process.env.MILO_WEB_BASE_URL ?? 'https://milo.live';

export function hashContactToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Normalises a phone number to 10 digits (or +<cc><digits> for non-IN numbers). */
export function normalisePhone(raw: string): string {
  const trimmed = raw.trim();
  const digits = trimmed.replace(/\D/g, '');
  if (trimmed.startsWith('+')) {
    return `+${digits}`;
  }
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);
  return digits;
}

export const updatePrivacy = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      ghostMode: z.boolean().optional(),
      incognitoAttendance: z.boolean().optional(),
      mutualInterestOnly: z.boolean().optional(),
      readReceipts: z.boolean().optional(),
      showFaceVerifiedBadge: z.boolean().optional(),
    })
    .parse(req.data);

  const userRef = db().collection('users').doc(ctx.uid);
  const snap = await userRef.get();
  const privacy = (snap.data()?.privacy ?? {}) as Record<string, unknown>;

  const next = {
    ...privacy,
    ...(input.ghostMode !== undefined ? { ghostMode: input.ghostMode } : {}),
    ...(input.incognitoAttendance !== undefined ? { incognitoAttendance: input.incognitoAttendance } : {}),
    ...(input.mutualInterestOnly !== undefined ? { mutualInterestOnly: input.mutualInterestOnly } : {}),
    ...(input.readReceipts !== undefined ? { readReceipts: input.readReceipts } : {}),
    ...(input.showFaceVerifiedBadge !== undefined ? { showFaceVerifiedBadge: input.showFaceVerifiedBadge } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await userRef.set({ privacy: next, updatedAt: FieldValue.serverTimestamp() }, { merge: true });

  if (input.ghostMode === true) {
    await db().collectionGroup('radarMembers').where('uid', '==', ctx.uid).get().then((snap2) =>
      Promise.all(snap2.docs.map((d) => d.ref.delete())).catch(() => undefined),
    );
  }

  return { ok: true, privacy: next };
});

export const addEmergencyContact = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      name: z.string().trim().min(2).max(60),
      phone: z.string().trim().regex(/^[+]?[0-9\s-]{10,15}$/, 'Enter a valid phone number'),
      relationship: z.string().trim().max(40).optional(),
    })
    .parse(req.data);

  await consumeRateLimit(rateLimitKey('emergency_contact', ctx.uid), 10, 24 * 60 * 60 * 1000);

  const limits = await getLimitsConfig();
  const contacts = await db().collection('users').doc(ctx.uid).collection('emergencyContacts').get();
  if (contacts.size >= limits.maxEmergencyContacts) {
    fail('LIMIT_EXCEEDED', `You can add up to ${limits.maxEmergencyContacts} emergency contacts.`);
  }

  const user = await db().collection('users').doc(ctx.uid).get();
  const displayName = String(user.data()?.displayName ?? 'Someone');
  const phone = normalisePhone(input.phone);

  const ref = db().collection('users').doc(ctx.uid).collection('emergencyContacts').doc();
  const token = randomBytes(24).toString('hex');
  const tokenHash = hashContactToken(token);
  const expiresAt = Timestamp.fromMillis(Date.now() + CONTACT_TOKEN_TTL_HOURS * 3_600_000);

  await ref.set({
    uid: ctx.uid,
    name: input.name,
    phone,
    relationship: input.relationship ?? null,
    status: 'pending',
    confirmationTokenHash: tokenHash,
    confirmationExpiresAt: expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });

  await db().collection('emergencyContactTokens').doc(tokenHash).set({
    uid: ctx.uid,
    contactId: ref.id,
    status: 'pending',
    expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });

  const confirmUrl = `${WEB_BASE_URL}/contact/confirm?t=${token}`;
  const sms = await sendSms(phone, process.env.SMS_TEMPLATE_CONTACT_CONSENT ?? 'CONTACT_CONSENT_TEMPLATE', [
    displayName,
    confirmUrl,
  ]);

  return {
    ok: true,
    contactId: ref.id,
    status: 'pending',
    consentRequestSent: sms.ok,
    confirmationExpiresAt: expiresAt.toDate().toISOString(),
  };
});

export const confirmEmergencyContact = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      contactId: z.string().min(1).max(64),
      status: z.enum(['confirmed', 'declined']),
    })
    .parse(req.data);

  const ref = db().collection('users').doc(ctx.uid).collection('emergencyContacts').doc(input.contactId);
  const snap = await ref.get();
  if (!snap.exists) fail('NOT_FOUND', 'Contact not found.');

  if (input.status === 'confirmed') {
    fail(
      'FORBIDDEN',
      'Your contact must confirm from the link we sent them before they can be alerted.',
    );
  }

  const tokenHash = snap.data()?.confirmationTokenHash as string | undefined;
  if (tokenHash) {
    await db()
      .collection('emergencyContactTokens')
      .doc(tokenHash)
      .set({ status: 'revoked', revokedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  await ref.set(
    {
      status: 'declined',
      respondedAt: FieldValue.serverTimestamp(),
      confirmationTokenHash: null,
    },
    { merge: true },
  );

  return { ok: true, contactId: input.contactId, status: 'declined' };
});

export const listEmergencyContacts = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const snap = await db().collection('users').doc(ctx.uid).collection('emergencyContacts').get();
  return {
    contacts: snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        name: data.name,
        phoneMasked: `+91 XXXXX X${String(data.phone ?? '').replace(/\D/g, '').slice(-3)}`,
        relationship: data.relationship ?? null,
        status: data.status,
      };
    }),
  };
});

export const removeEmergencyContact = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ contactId: z.string().min(1).max(64) }).parse(req.data);
  const ref = db().collection('users').doc(ctx.uid).collection('emergencyContacts').doc(input.contactId);
  const snap = await ref.get();
  const tokenHash = snap.data()?.confirmationTokenHash as string | undefined;
  if (tokenHash) {
    await db()
      .collection('emergencyContactTokens')
      .doc(tokenHash)
      .set({ status: 'revoked', revokedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  await ref.delete();
  return { ok: true };
});

export const testEmergencyAlert = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ contactId: z.string().min(1).max(64) }).parse(req.data);

  const ref = db().collection('users').doc(ctx.uid).collection('emergencyContacts').doc(input.contactId);
  const snap = await ref.get();
  if (!snap.exists) fail('NOT_FOUND', 'Contact not found.');
  const contact = snap.data()!;
  if (contact.status !== 'confirmed') fail('FORBIDDEN', 'Only confirmed contacts receive test alerts.');

  const sms = await sendSms(contact.phone, process.env.SMS_TEMPLATE_SOS_TEST ?? 'SOS_TEST_TEMPLATE', [
    String(contact.name ?? 'Contact'),
  ]);

  return { ok: sms.ok, sent: sms.ok };
});
