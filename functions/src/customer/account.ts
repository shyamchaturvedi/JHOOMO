import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { authAdmin, db, storageAdmin } from '../shared/admin';
import { fail } from '../shared/errors';
import { ageBand, isAtLeastAge, MIN_AGE } from '../shared/age';
import {
  CONSENT_TYPES,
  ConsentType,
  mergeConsents,
} from '../shared/consent';
import { consentTypeSchema, dobSchema, genderSchema, idSchema } from '../shared/schemas';
import { randomToken, sha256Hex } from '../shared/crypto';
import { verifyEmailCode } from '../shared/emailcode';
import { addDays } from '../shared/time';
import { notifyUser } from '../shared/notify';
import { logger } from 'firebase-functions';

const CONSENT_VERSION = '1.0';

export interface UserRoles {
  organizer: boolean;
  promoter: boolean;
}

function toPublicDisplayName(displayName: string): string {
  const parts = displayName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'Milo User';
  const first = parts[0]!;
  if (parts.length === 1) return first;
  const last = parts[parts.length - 1]!;
  return `${first} ${last.charAt(0).toUpperCase()}.`;
}

function parseDob(value: string | number): Date {
  if (typeof value === 'number') return new Date(value);
  const parsed = new Date(`${value}T00:00:00.000+05:30`);
  if (Number.isNaN(parsed.getTime())) fail('INVALID_INPUT', 'Invalid date of birth.');
  return parsed;
}

export const bootstrapUser = miloOnCall(
  { enforceAppCheck: false },
  async (req) => {
    const ctx = requireAuth(req);
    const ref = db().collection('users').doc(ctx.uid);
    const snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        schemaVersion: 1,
        phone: ctx.token.phone_number ?? null,
        phoneVerified: Boolean(ctx.token.phone_number),
        displayName: '',
        avatarUrl: null,
        bio: null,
        dob: null,
        gender: 'undisclosed',
        cityId: null,
        interests: [],
        email: ctx.token.email ?? null,
        emailVerified: Boolean(ctx.token.email_verified),
        privacy: {
          ghostMode: false,
          incognito: false,
          mutualInterestOnly: true,
          readReceipts: true,
          showFaceBadge: true,
        },
        notificationPrefs: {
          bookings: true,
          reminders: true,
          social: true,
          marketing: false,
          promoter: false,
        },
        consents: [],
        roles: { organizer: false, promoter: false },
        status: 'active',
        faceVerified: false,
        locale: 'en',
        lastActiveAt: FieldValue.serverTimestamp(),
        appVersion: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { isNewUser: true, roles: { organizer: false, promoter: false } };
    }

    const data = snap.data() ?? {};
    const roles: UserRoles = {
      organizer: data.roles?.organizer === true,
      promoter: data.roles?.promoter === true,
    };
    if (data.status === 'banned') {
      fail('FORBIDDEN', 'This account has been permanently closed.');
    }
    await ref.set({ lastActiveAt: FieldValue.serverTimestamp() }, { merge: true });
    return { isNewUser: false, roles };
  },
);

const completeProfileSchema = z.object({
  displayName: z.string().trim().min(2).max(40),
  dob: dobSchema,
  gender: genderSchema,
  cityId: z.string().min(1).max(64),
  avatarUrl: z.string().url().max(1024).nullable().optional(),
  bio: z.string().trim().max(160).optional().nullable(),
  interests: z.array(z.string().max(40)).max(20).default([]),
  consents: z
    .array(
      z.object({
        type: consentTypeSchema,
        granted: z.boolean(),
      }),
    )
    .min(1),
});

export const completeProfile = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = completeProfileSchema.parse(req.data);

  const granted = new Map<ConsentType, boolean>();
  for (const c of input.consents) granted.set(c.type, c.granted);

  if (!granted.get('terms') || !granted.get('privacy')) {
    fail('CONSENT_REQUIRED', 'Accept the Terms and Privacy Policy to continue.');
  }

  const dob = parseDob(input.dob);
  const now = new Date();

  if (!isAtLeastAge(dob, MIN_AGE, now)) {
    await deleteUnderageAccount(ctx.uid);
    fail('AGE_RESTRICTED', 'Milo is for users aged 18 and above.');
  }

  const userRef = db().collection('users').doc(ctx.uid);
  const nowTs = Timestamp.fromDate(now);
  const existingSnap = await userRef.get();
  const existing = existingSnap.data() ?? {};
  const existingConsents = Array.isArray(existing.consents) ? existing.consents : [];

  const merged = mergeConsents(existingConsents, input.consents.map((c) => ({ type: c.type, granted: c.granted })), nowTs);

  const userPayload = {
    schemaVersion: 1,
    displayName: input.displayName,
    avatarUrl: input.avatarUrl ?? existing.avatarUrl ?? null,
    bio: input.bio ?? null,
    dob: Timestamp.fromDate(dob),
    gender: input.gender,
    cityId: input.cityId,
    interests: input.interests,
    consents: merged,
    consentVersion: CONSENT_VERSION,
    updatedAt: FieldValue.serverTimestamp(),
  };

  await userRef.set(userPayload, { merge: true });

  const publicRef = db().collection('publicProfiles').doc(ctx.uid);
  await publicRef.set(
    {
      schemaVersion: 1,
      displayName: toPublicDisplayName(input.displayName),
      avatarUrl: input.avatarUrl ?? existing.avatarUrl ?? null,
      ageBand: ageBand(dob),
      interests: input.interests,
      bio: input.bio ?? null,
      faceVerified: existing.faceVerified === true,
      cityId: input.cityId,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true, ageBand: ageBand(dob) };
});

async function deleteUnderageAccount(uid: string): Promise<void> {
  try {
    const userRef = db().collection('users').doc(uid);
    await userRef.set(
      {
        schemaVersion: 1,
        status: 'deleted_underage',
        displayName: '',
        dob: null,
        phone: null,
        email: null,
        interests: [],
        consents: [],
        avatarUrl: null,
        bio: null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await db().collection('publicProfiles').doc(uid).delete();
    await authAdmin().deleteUser(uid);
    logger.info('milo.underage.account_deleted', { uid });
  } catch (err) {
    logger.error('milo.underage.cleanup_failed', { uid, error: String(err) });
  }
}

const linkEmailSchema = z.object({
  email: z.string().email(),
  code: z.string().regex(/^\d{6}$/),
});

export const linkEmail = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = linkEmailSchema.parse(req.data);
  const ok = await verifyEmailCode(input.email, input.code, 'link_email');
  if (!ok) fail('INVALID_INPUT', 'That code is invalid or has expired.');
  await db()
    .collection('users')
    .doc(ctx.uid)
    .set({ email: input.email, emailVerified: true, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true };
});

export const exportMyData = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const userRef = db().collection('users').doc(ctx.uid);
  const snap = await userRef.get();
  if (!snap.exists) fail('NOT_FOUND', 'No profile data found for this account.');

  const [bookings, tickets, notifications, blocks, contacts, devices] = await Promise.all([
    db().collection('bookings').where('userId', '==', ctx.uid).get(),
    db().collection('tickets').where('userId', '==', ctx.uid).get(),
    db().collection('users').doc(ctx.uid).collection('notifications').get(),
    db().collection('users').doc(ctx.uid).collection('blocks').get(),
    db().collection('users').doc(ctx.uid).collection('emergencyContacts').get(),
    db().collection('users').doc(ctx.uid).collection('devices').get(),
  ]);

  const toPlain = (docs: { data: () => Record<string, unknown> }[]) =>
    docs.map((d) => serialise(d.data()));

  const payload = {
    generatedAt: new Date().toISOString(),
    subjectUid: ctx.uid,
    profile: serialise(snap.data() ?? {}),
    bookings: toPlain(bookings.docs),
    tickets: toPlain(tickets.docs),
    notifications: toPlain(notifications.docs),
    blockedUsers: toPlain(blocks.docs),
    emergencyContacts: toPlain(contacts.docs),
    devices: toPlain(devices.docs),
    notice:
      'This export is provided under the Digital Personal Data Protection Act, 2023 (right of access and correction).',
  };

  const token = randomToken(24);
  const fileName = `user-export-${Date.now()}.json`;
  const path = `user-exports/${ctx.uid}/${fileName}`;
  const bucket = storageAdmin().bucket();
  await bucket.file(path).save(JSON.stringify(payload, null, 2), {
    contentType: 'application/json',
    metadata: { metadata: { expiresAt: addDays(new Date(), 1).toISOString() } },
  });

  const [url] = await bucket.file(path).getSignedUrl({
    action: 'read',
    expires: addDays(new Date(), 1),
  });

  await notifyUser(
    ctx.uid,
    'data_export_ready',
    'Your Milo data export is ready',
    'Your personal data export is ready for download. The link expires in 24 hours.',
    { deepLink: '/settings', data: { exportToken: sha256Hex(token).slice(0, 12) } },
  );

  return { url, expiresAt: addDays(new Date(), 1).toISOString() };
});

function serialise(data: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value instanceof Timestamp) out[key] = value.toDate().toISOString();
    else if (value && typeof value === 'object' && 'latitude' in (value as Record<string, unknown>)) {
      const geo = value as { latitude: number; longitude: number };
      out[key] = { lat: geo.latitude, lng: geo.longitude };
    } else out[key] = value;
  }
  return out;
}

const deleteAccountSchema = z.object({
  confirm: z.literal(true),
});

export const requestAccountDeletion = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  deleteAccountSchema.parse(req.data);

  const now = new Date();
  const upcoming = await db()
    .collection('bookings')
    .where('userId', '==', ctx.uid)
    .where('status', 'in', ['pending_payment', 'confirmed'])
    .get();

  const upcomingCount = upcoming.docs.filter((d) => {
    const endAt = (d.data().eventSnapshot as { startAt?: Timestamp } | undefined)?.startAt;
    return !endAt || endAt.toMillis() > now.getTime();
  }).length;

  if (upcomingCount > 0) {
    fail('CONFLICT', 'You have upcoming tickets. Cancel or attend them before deleting your account.');
  }

  const settlements = await db()
    .collection('settlements')
    .where('organizerId', '==', ctx.uid)
    .where('status', 'in', ['scheduled', 'processing', 'on_hold'])
    .get();
  if (!settlements.empty) {
    fail('CONFLICT', 'You have unsettled payouts. Clear them before deleting your account.');
  }

  const scheduledFor = addDays(now, 30);
  await db()
    .collection('users')
    .doc(ctx.uid)
    .set(
      {
        schemaVersion: 1,
        status: 'pending_deletion',
        deletionScheduledAt: Timestamp.fromDate(scheduledFor),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await notifyUser(
    ctx.uid,
    'account_deletion_scheduled',
    'Account deletion scheduled',
    'Your account will be permanently deleted after 30 days. Log in again to cancel.',
    { deepLink: '/settings' },
  );

  return { ok: true, deletionScheduledAt: scheduledFor.toISOString(), graceDays: 30 };
});

export const cancelAccountDeletion = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  await db()
    .collection('users')
    .doc(ctx.uid)
    .set(
      {
        schemaVersion: 1,
        status: 'active',
        deletionScheduledAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  return { ok: true };
});

export const confirmFaceVerification = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ vendorReference: idSchema, verified: z.boolean() }).parse(req.data);
  if (!input.verified) return { ok: false };

  await db()
    .collection('publicProfiles')
    .doc(ctx.uid)
    .set(
      { schemaVersion: 1, faceVerified: true, faceVerifiedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  await db()
    .collection('users')
    .doc(ctx.uid)
    .set({ schemaVersion: 1, faceVerified: true, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true };
});

export { CONSENT_TYPES };
