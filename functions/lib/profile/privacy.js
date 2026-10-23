"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.testEmergencyAlert = exports.removeEmergencyContact = exports.listEmergencyContacts = exports.confirmEmergencyContact = exports.addEmergencyContact = exports.updatePrivacy = void 0;
exports.hashContactToken = hashContactToken;
exports.normalisePhone = normalisePhone;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const node_crypto_1 = require("node:crypto");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const config_1 = require("../shared/config");
const sms_1 = require("../shared/sms");
const ratelimit_1 = require("../shared/ratelimit");
const CONTACT_TOKEN_TTL_HOURS = 72;
const WEB_BASE_URL = process.env.MILO_WEB_BASE_URL ?? 'https://milo.live';
function hashContactToken(token) {
    return (0, node_crypto_1.createHash)('sha256').update(token).digest('hex');
}
/** Normalises a phone number to 10 digits (or +<cc><digits> for non-IN numbers). */
function normalisePhone(raw) {
    const trimmed = raw.trim();
    const digits = trimmed.replace(/\D/g, '');
    if (trimmed.startsWith('+')) {
        return `+${digits}`;
    }
    if (digits.length === 12 && digits.startsWith('91'))
        return digits.slice(2);
    return digits;
}
exports.updatePrivacy = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        ghostMode: zod_1.z.boolean().optional(),
        incognitoAttendance: zod_1.z.boolean().optional(),
        mutualInterestOnly: zod_1.z.boolean().optional(),
        readReceipts: zod_1.z.boolean().optional(),
        showFaceVerifiedBadge: zod_1.z.boolean().optional(),
    })
        .parse(req.data);
    const userRef = (0, admin_1.db)().collection('users').doc(ctx.uid);
    const snap = await userRef.get();
    const privacy = (snap.data()?.privacy ?? {});
    const next = {
        ...privacy,
        ...(input.ghostMode !== undefined ? { ghostMode: input.ghostMode } : {}),
        ...(input.incognitoAttendance !== undefined ? { incognitoAttendance: input.incognitoAttendance } : {}),
        ...(input.mutualInterestOnly !== undefined ? { mutualInterestOnly: input.mutualInterestOnly } : {}),
        ...(input.readReceipts !== undefined ? { readReceipts: input.readReceipts } : {}),
        ...(input.showFaceVerifiedBadge !== undefined ? { showFaceVerifiedBadge: input.showFaceVerifiedBadge } : {}),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    await userRef.set({ privacy: next, updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    if (input.ghostMode === true) {
        await (0, admin_1.db)().collectionGroup('radarMembers').where('uid', '==', ctx.uid).get().then((snap2) => Promise.all(snap2.docs.map((d) => d.ref.delete())).catch(() => undefined));
    }
    return { ok: true, privacy: next };
});
exports.addEmergencyContact = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        name: zod_1.z.string().trim().min(2).max(60),
        phone: zod_1.z.string().trim().regex(/^[+]?[0-9\s-]{10,15}$/, 'Enter a valid phone number'),
        relationship: zod_1.z.string().trim().max(40).optional(),
    })
        .parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('emergency_contact', ctx.uid), 10, 24 * 60 * 60 * 1000);
    const limits = await (0, config_1.getLimitsConfig)();
    const contacts = await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').get();
    if (contacts.size >= limits.maxEmergencyContacts) {
        (0, errors_1.fail)('LIMIT_EXCEEDED', `You can add up to ${limits.maxEmergencyContacts} emergency contacts.`);
    }
    const user = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const displayName = String(user.data()?.displayName ?? 'Someone');
    const phone = normalisePhone(input.phone);
    const ref = (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').doc();
    const token = (0, node_crypto_1.randomBytes)(24).toString('hex');
    const tokenHash = hashContactToken(token);
    const expiresAt = firestore_1.Timestamp.fromMillis(Date.now() + CONTACT_TOKEN_TTL_HOURS * 3_600_000);
    await ref.set({
        uid: ctx.uid,
        name: input.name,
        phone,
        relationship: input.relationship ?? null,
        status: 'pending',
        confirmationTokenHash: tokenHash,
        confirmationExpiresAt: expiresAt,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, admin_1.db)().collection('emergencyContactTokens').doc(tokenHash).set({
        uid: ctx.uid,
        contactId: ref.id,
        status: 'pending',
        expiresAt,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    const confirmUrl = `${WEB_BASE_URL}/contact/confirm?t=${token}`;
    const sms = await (0, sms_1.sendSms)(phone, process.env.SMS_TEMPLATE_CONTACT_CONSENT ?? 'CONTACT_CONSENT_TEMPLATE', [
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
exports.confirmEmergencyContact = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        contactId: zod_1.z.string().min(1).max(64),
        status: zod_1.z.enum(['confirmed', 'declined']),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').doc(input.contactId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Contact not found.');
    if (input.status === 'confirmed') {
        (0, errors_1.fail)('FORBIDDEN', 'Your contact must confirm from the link we sent them before they can be alerted.');
    }
    const tokenHash = snap.data()?.confirmationTokenHash;
    if (tokenHash) {
        await (0, admin_1.db)()
            .collection('emergencyContactTokens')
            .doc(tokenHash)
            .set({ status: 'revoked', revokedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    await ref.set({
        status: 'declined',
        respondedAt: firestore_1.FieldValue.serverTimestamp(),
        confirmationTokenHash: null,
    }, { merge: true });
    return { ok: true, contactId: input.contactId, status: 'declined' };
});
exports.listEmergencyContacts = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const snap = await (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').get();
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
exports.removeEmergencyContact = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ contactId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const ref = (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').doc(input.contactId);
    const snap = await ref.get();
    const tokenHash = snap.data()?.confirmationTokenHash;
    if (tokenHash) {
        await (0, admin_1.db)()
            .collection('emergencyContactTokens')
            .doc(tokenHash)
            .set({ status: 'revoked', revokedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    await ref.delete();
    return { ok: true };
});
exports.testEmergencyAlert = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ contactId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const ref = (0, admin_1.db)().collection('users').doc(ctx.uid).collection('emergencyContacts').doc(input.contactId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Contact not found.');
    const contact = snap.data();
    if (contact.status !== 'confirmed')
        (0, errors_1.fail)('FORBIDDEN', 'Only confirmed contacts receive test alerts.');
    const sms = await (0, sms_1.sendSms)(contact.phone, process.env.SMS_TEMPLATE_SOS_TEST ?? 'SOS_TEST_TEMPLATE', [
        String(contact.name ?? 'Contact'),
    ]);
    return { ok: sms.ok, sent: sms.ok };
});
//# sourceMappingURL=privacy.js.map