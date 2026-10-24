"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CONSENT_TYPES = exports.confirmFaceVerification = exports.cancelAccountDeletion = exports.requestAccountDeletion = exports.exportMyData = exports.linkEmail = exports.completeProfile = exports.bootstrapUser = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const age_1 = require("../shared/age");
const consent_1 = require("../shared/consent");
Object.defineProperty(exports, "CONSENT_TYPES", { enumerable: true, get: function () { return consent_1.CONSENT_TYPES; } });
const schemas_1 = require("../shared/schemas");
const crypto_1 = require("../shared/crypto");
const emailcode_1 = require("../shared/emailcode");
const time_1 = require("../shared/time");
const notify_1 = require("../shared/notify");
const firebase_functions_1 = require("firebase-functions");
const uniqueness_1 = require("../shared/uniqueness");
const CONSENT_VERSION = '1.0';
function toPublicDisplayName(displayName) {
    const parts = displayName.trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0)
        return 'Milo User';
    const first = parts[0];
    if (parts.length === 1)
        return first;
    const last = parts[parts.length - 1];
    return `${first} ${last.charAt(0).toUpperCase()}.`;
}
function parseDob(value) {
    if (typeof value === 'number')
        return new Date(value);
    const parsed = new Date(`${value}T00:00:00.000+05:30`);
    if (Number.isNaN(parsed.getTime()))
        (0, errors_1.fail)('INVALID_INPUT', 'Invalid date of birth.');
    return parsed;
}
async function ensurePhoneUnique(uid, rawPhone) {
    const normalized = (0, uniqueness_1.normalizeIndianPhone)(rawPhone);
    if (!normalized)
        return '';
    const pHash = (0, uniqueness_1.phoneHash)(normalized);
    const [userByHash, usersByField] = await Promise.all([
        (0, admin_1.db)().collection('users').where('phoneHash', '==', pHash).limit(5).get(),
        (0, admin_1.db)().collection('users').where('normalizedPhone', '==', normalized).limit(5).get(),
    ]);
    for (const doc of [...userByHash.docs, ...usersByField.docs]) {
        if (doc.id !== uid) {
            (0, errors_1.fail)('ALREADY_REGISTERED', 'This mobile number is already registered with another account.');
        }
    }
    return normalized;
}
exports.bootstrapUser = (0, callable_1.miloOnCall)({ enforceAppCheck: false }, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const ref = (0, admin_1.db)().collection('users').doc(ctx.uid);
    const snap = await ref.get();
    const rawPhone = ctx.token.phone_number ?? null;
    const normalizedPhone = await ensurePhoneUnique(ctx.uid, rawPhone);
    const pHash = normalizedPhone ? (0, uniqueness_1.phoneHash)(normalizedPhone) : '';
    if (!snap.exists) {
        await ref.set({
            schemaVersion: 1,
            phone: rawPhone,
            normalizedPhone: normalizedPhone || null,
            phoneHash: pHash || null,
            phoneVerified: Boolean(rawPhone),
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
            lastActiveAt: firestore_1.FieldValue.serverTimestamp(),
            appVersion: null,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        return { isNewUser: true, roles: { organizer: false, promoter: false } };
    }
    const data = snap.data() ?? {};
    const roles = {
        organizer: data.roles?.organizer === true,
        promoter: data.roles?.promoter === true,
    };
    if (data.status === 'banned') {
        (0, errors_1.fail)('FORBIDDEN', 'This account has been permanently closed.');
    }
    await ref.set({
        phone: rawPhone ?? data.phone ?? null,
        normalizedPhone: normalizedPhone || data.normalizedPhone || null,
        phoneHash: pHash || data.phoneHash || null,
        lastActiveAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { isNewUser: false, roles };
});
const completeProfileSchema = zod_1.z.object({
    displayName: zod_1.z.string().trim().min(2).max(40),
    dob: schemas_1.dobSchema,
    gender: schemas_1.genderSchema,
    cityId: zod_1.z.string().min(1).max(64),
    avatarUrl: zod_1.z.string().url().max(1024).nullable().optional(),
    bio: zod_1.z.string().trim().max(160).optional().nullable(),
    interests: zod_1.z.array(zod_1.z.string().max(40)).max(20).default([]),
    consents: zod_1.z
        .array(zod_1.z.object({
        type: schemas_1.consentTypeSchema,
        granted: zod_1.z.boolean(),
    }))
        .min(1),
});
exports.completeProfile = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = completeProfileSchema.parse(req.data);
    const granted = new Map();
    for (const c of input.consents)
        granted.set(c.type, c.granted);
    if (!granted.get('terms') || !granted.get('privacy')) {
        (0, errors_1.fail)('CONSENT_REQUIRED', 'Accept the Terms and Privacy Policy to continue.');
    }
    const dob = parseDob(input.dob);
    const now = new Date();
    if (!(0, age_1.isAtLeastAge)(dob, age_1.MIN_AGE, now)) {
        await deleteUnderageAccount(ctx.uid);
        (0, errors_1.fail)('AGE_RESTRICTED', 'Milo is for users aged 18 and above.');
    }
    const userRef = (0, admin_1.db)().collection('users').doc(ctx.uid);
    const nowTs = firestore_1.Timestamp.fromDate(now);
    const existingSnap = await userRef.get();
    const existing = existingSnap.data() ?? {};
    const existingConsents = Array.isArray(existing.consents) ? existing.consents : [];
    const merged = (0, consent_1.mergeConsents)(existingConsents, input.consents.map((c) => ({ type: c.type, granted: c.granted })), nowTs);
    const userPayload = {
        schemaVersion: 1,
        displayName: input.displayName,
        avatarUrl: input.avatarUrl ?? existing.avatarUrl ?? null,
        bio: input.bio ?? null,
        dob: firestore_1.Timestamp.fromDate(dob),
        gender: input.gender,
        cityId: input.cityId,
        interests: input.interests,
        consents: merged,
        consentVersion: CONSENT_VERSION,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    await userRef.set(userPayload, { merge: true });
    const publicRef = (0, admin_1.db)().collection('publicProfiles').doc(ctx.uid);
    await publicRef.set({
        schemaVersion: 1,
        displayName: toPublicDisplayName(input.displayName),
        avatarUrl: input.avatarUrl ?? existing.avatarUrl ?? null,
        ageBand: (0, age_1.ageBand)(dob),
        interests: input.interests,
        bio: input.bio ?? null,
        faceVerified: existing.faceVerified === true,
        cityId: input.cityId,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true, ageBand: (0, age_1.ageBand)(dob) };
});
async function deleteUnderageAccount(uid) {
    try {
        const userRef = (0, admin_1.db)().collection('users').doc(uid);
        await userRef.set({
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
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        await (0, admin_1.db)().collection('publicProfiles').doc(uid).delete();
        await (0, admin_1.authAdmin)().deleteUser(uid);
        firebase_functions_1.logger.info('milo.underage.account_deleted', { uid });
    }
    catch (err) {
        firebase_functions_1.logger.error('milo.underage.cleanup_failed', { uid, error: String(err) });
    }
}
const linkEmailSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    code: zod_1.z.string().regex(/^\d{6}$/),
});
exports.linkEmail = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = linkEmailSchema.parse(req.data);
    const ok = await (0, emailcode_1.verifyEmailCode)(input.email, input.code, 'link_email');
    if (!ok)
        (0, errors_1.fail)('INVALID_INPUT', 'That code is invalid or has expired.');
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .set({ email: input.email, emailVerified: true, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
exports.exportMyData = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const userRef = (0, admin_1.db)().collection('users').doc(ctx.uid);
    const snap = await userRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'No profile data found for this account.');
    const [bookings, tickets, notifications, blocks, contacts, devices] = await Promise.all([
        (0, admin_1.db)().collection('bookings').where('userId', '==', ctx.uid).get(),
        (0, admin_1.db)().collection('tickets').where('userId', '==', ctx.uid).get(),
        (0, admin_1.db)().collection('users').doc(ctx.uid).collection('notifications').get(),
        (0, admin_1.db)().collection('users').doc(ctx.uid).collection('blocks').get(),
        (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').get(),
        (0, admin_1.db)().collection('users').doc(ctx.uid).collection('devices').get(),
    ]);
    const toPlain = (docs) => docs.map((d) => serialise(d.data()));
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
        notice: 'This export is provided under the Digital Personal Data Protection Act, 2023 (right of access and correction).',
    };
    const token = (0, crypto_1.randomToken)(24);
    const fileName = `user-export-${Date.now()}.json`;
    const path = `user-exports/${ctx.uid}/${fileName}`;
    const bucket = (0, admin_1.storageAdmin)().bucket();
    await bucket.file(path).save(JSON.stringify(payload, null, 2), {
        contentType: 'application/json',
        metadata: { metadata: { expiresAt: (0, time_1.addDays)(new Date(), 1).toISOString() } },
    });
    const [url] = await bucket.file(path).getSignedUrl({
        action: 'read',
        expires: (0, time_1.addDays)(new Date(), 1),
    });
    await (0, notify_1.notifyUser)(ctx.uid, 'data_export_ready', 'Your Milo data export is ready', 'Your personal data export is ready for download. The link expires in 24 hours.', { deepLink: '/settings', data: { exportToken: (0, crypto_1.sha256Hex)(token).slice(0, 12) } });
    return { url, expiresAt: (0, time_1.addDays)(new Date(), 1).toISOString() };
});
function serialise(data) {
    const out = {};
    for (const [key, value] of Object.entries(data)) {
        if (value instanceof firestore_1.Timestamp)
            out[key] = value.toDate().toISOString();
        else if (value && typeof value === 'object' && 'latitude' in value) {
            const geo = value;
            out[key] = { lat: geo.latitude, lng: geo.longitude };
        }
        else
            out[key] = value;
    }
    return out;
}
const deleteAccountSchema = zod_1.z.object({
    confirm: zod_1.z.literal(true),
});
exports.requestAccountDeletion = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    deleteAccountSchema.parse(req.data);
    const now = new Date();
    const upcoming = await (0, admin_1.db)()
        .collection('bookings')
        .where('userId', '==', ctx.uid)
        .where('status', 'in', ['pending_payment', 'confirmed'])
        .get();
    const upcomingCount = upcoming.docs.filter((d) => {
        const endAt = d.data().eventSnapshot?.startAt;
        return !endAt || endAt.toMillis() > now.getTime();
    }).length;
    if (upcomingCount > 0) {
        (0, errors_1.fail)('CONFLICT', 'You have upcoming tickets. Cancel or attend them before deleting your account.');
    }
    const settlements = await (0, admin_1.db)()
        .collection('settlements')
        .where('organizerId', '==', ctx.uid)
        .where('status', 'in', ['scheduled', 'processing', 'on_hold'])
        .get();
    if (!settlements.empty) {
        (0, errors_1.fail)('CONFLICT', 'You have unsettled payouts. Clear them before deleting your account.');
    }
    const scheduledFor = (0, time_1.addDays)(now, 30);
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .set({
        schemaVersion: 1,
        status: 'pending_deletion',
        deletionScheduledAt: firestore_1.Timestamp.fromDate(scheduledFor),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, notify_1.notifyUser)(ctx.uid, 'account_deletion_scheduled', 'Account deletion scheduled', 'Your account will be permanently deleted after 30 days. Log in again to cancel.', { deepLink: '/settings' });
    return { ok: true, deletionScheduledAt: scheduledFor.toISOString(), graceDays: 30 };
});
exports.cancelAccountDeletion = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .set({
        schemaVersion: 1,
        status: 'active',
        deletionScheduledAt: null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.confirmFaceVerification = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ vendorReference: schemas_1.idSchema, verified: zod_1.z.boolean() }).parse(req.data);
    if (!input.verified)
        return { ok: false };
    await (0, admin_1.db)()
        .collection('publicProfiles')
        .doc(ctx.uid)
        .set({ schemaVersion: 1, faceVerified: true, faceVerifiedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    await (0, admin_1.db)()
        .collection('users')
        .doc(ctx.uid)
        .set({ schemaVersion: 1, faceVerified: true, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
//# sourceMappingURL=account.js.map