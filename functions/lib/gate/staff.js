"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifyStaffRevoked = exports.endGateSession = exports.staffLogin = exports.listStaff = exports.revokeStaff = exports.createStaffPasscode = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const crypto_1 = require("../shared/crypto");
const claims_1 = require("../shared/claims");
const ratelimit_1 = require("../shared/ratelimit");
const audit_1 = require("../shared/audit");
const notify_1 = require("../shared/notify");
const auth_2 = require("../shared/auth");
const callable_2 = require("../shared/callable");
const node_crypto_1 = require("node:crypto");
const staffCreateSchema = zod_1.z.object({
    eventId: zod_1.z.string().min(1).max(64),
    name: zod_1.z.string().trim().min(2).max(80),
    phone: zod_1.z.string().trim().regex(/^\+91[6-9]\d{9}$/, 'Enter a valid 10-digit Indian mobile number'),
    gate: zod_1.z.string().trim().min(1).max(40),
    role: zod_1.z.enum(['scanner', 'gate_lead']).default('scanner'),
    validFrom: zod_1.z.number().int().positive(),
    validTo: zod_1.z.number().int().positive(),
});
exports.createStaffPasscode = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = staffCreateSchema.parse(req.data);
    const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const event = eventSnap.data();
    if (event.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
    const gates = (event.gates ?? []);
    if (!gates.some((g) => g.id === input.gate)) {
        (0, errors_1.fail)('INVALID_INPUT', 'That gate is not defined for this event.');
    }
    if (input.validTo <= input.validFrom)
        (0, errors_1.fail)('INVALID_INPUT', 'The validity window is invalid.');
    const existingStaff = await (0, admin_1.db)()
        .collection('events')
        .doc(input.eventId)
        .collection('staff')
        .get();
    if (existingStaff.size >= 20)
        (0, errors_1.fail)('LIMIT_EXCEEDED', 'This event already has the maximum staff members.');
    const staffId = `st_${(0, node_crypto_1.randomBytes)(5).toString('hex')}`;
    const passcode = (0, crypto_1.generatePasscode)();
    const salt = (0, crypto_1.newSalt)();
    await (0, admin_1.db)()
        .collection('events')
        .doc(input.eventId)
        .collection('staff')
        .doc(staffId)
        .set({
        schemaVersion: 1,
        name: input.name,
        phone: input.phone,
        gate: input.gate,
        role: input.role,
        status: 'active',
        validFrom: firestore_1.Timestamp.fromMillis(input.validFrom),
        validTo: firestore_1.Timestamp.fromMillis(input.validTo),
        scanCount: 0,
        createdBy: ctx.uid,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, admin_1.db)()
        .collection('staffSecrets')
        .doc(`${input.eventId}_${staffId}`)
        .set({
        schemaVersion: 1,
        passcodeHash: (0, crypto_1.hashPasscode)(passcode, salt),
        salt,
        failedAttempts: 0,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'staff.created',
        targetType: 'event_staff',
        targetId: `${input.eventId}_${staffId}`,
        after: { gate: input.gate, role: input.role },
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true, staffId, passcode, gate: input.gate, role: input.role };
});
exports.revokeStaff = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ eventId: zod_1.z.string().min(1).max(64), staffId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const staffRef = (0, admin_1.db)().collection('events').doc(input.eventId).collection('staff').doc(input.staffId);
    const snap = await staffRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Staff member not found.');
    if (snap.data()?.createdBy !== ctx.uid && snap.data()?.organizerId !== ctx.uid) {
        (0, errors_1.fail)('FORBIDDEN', 'This staff member belongs to another organiser.');
    }
    await staffRef.set({ status: 'revoked', revokedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    const sessions = await (0, admin_1.db)()
        .collection('gateSessions')
        .where('eventId', '==', input.eventId)
        .where('staffId', '==', input.staffId)
        .where('status', '==', 'active')
        .get();
    for (const session of sessions.docs) {
        await session.ref.set({ status: 'revoked', endedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'staff.revoked',
        targetType: 'event_staff',
        targetId: `${input.eventId}_${input.staffId}`,
        requestId: (0, callable_2.requestIdOf)(req),
    });
    return { ok: true, sessionsRevoked: sessions.size };
});
exports.listStaff = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ eventId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    if (eventSnap.data()?.organizerId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This event belongs to another organiser.');
    const snap = await (0, admin_1.db)().collection('events').doc(input.eventId).collection('staff').get();
    return {
        staff: snap.docs.map((d) => {
            const data = d.data();
            return {
                staffId: d.id,
                name: data.name,
                phone: data.phone,
                gate: data.gate,
                role: data.role,
                status: data.status,
                validFrom: data.validFrom,
                validTo: data.validTo,
                scanCount: data.scanCount ?? 0,
                lastLoginAt: data.lastLoginAt ?? null,
            };
        }),
    };
});
const staffLoginSchema = zod_1.z.object({
    eventId: zod_1.z.string().min(1).max(64),
    staffId: zod_1.z.string().min(1).max(64),
    passcode: zod_1.z.string().regex(/^\d{6}$/, 'Passcode must be 6 digits'),
    deviceId: zod_1.z.string().trim().min(8).max(120),
    appVersion: zod_1.z.string().trim().max(40).optional(),
});
exports.staffLogin = (0, callable_1.miloOnCall)({ enforceAppCheck: true }, async (req) => {
    const input = staffLoginSchema.parse(req.data);
    const ip = (0, auth_2.clientIp)(req);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('staff_login_ip', ip), 30, 60 * 1000);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('staff_login', input.eventId, input.staffId), 10, 60 * 1000);
    const staffRef = (0, admin_1.db)().collection('events').doc(input.eventId).collection('staff').doc(input.staffId);
    const staffSnap = await staffRef.get();
    if (!staffSnap.exists)
        (0, errors_1.fail)('INVALID_STAFF_CREDENTIALS', 'Invalid passcode.');
    const staff = staffSnap.data();
    if (staff.status !== 'active')
        (0, errors_1.fail)('INVALID_STAFF_CREDENTIALS', 'This staff pass has been revoked.');
    const now = Date.now();
    const validFrom = staff.validFrom?.toMillis() ?? 0;
    const validTo = staff.validTo?.toMillis() ?? Number.MAX_SAFE_INTEGER;
    if (now < validFrom || now > validTo) {
        (0, errors_1.fail)('INVALID_STAFF_CREDENTIALS', 'This staff pass is not valid for this event window.');
    }
    const secretRef = (0, admin_1.db)().collection('staffSecrets').doc(`${input.eventId}_${input.staffId}`);
    const secretSnap = await secretRef.get();
    const secret = secretSnap.data();
    if (!secret)
        (0, errors_1.fail)('INVALID_STAFF_CREDENTIALS', 'Invalid passcode.');
    const lockedUntil = secret.lockedUntil?.toMillis() ?? 0;
    if (lockedUntil > now) {
        (0, errors_1.fail)('RATE_LIMITED', 'Too many failed attempts. Try again in a few minutes.', {
            retryAfterSeconds: Math.ceil((lockedUntil - now) / 1000),
        });
    }
    const expected = (0, crypto_1.hashPasscode)(input.passcode, String(secret.salt));
    if (expected !== secret.passcodeHash) {
        const attempts = Number(secret.failedAttempts ?? 0) + 1;
        const patch = { failedAttempts: attempts };
        if (attempts >= 5)
            patch.lockedUntil = firestore_1.Timestamp.fromMillis(now + 5 * 60 * 1000);
        await secretRef.set(patch, { merge: true });
        (0, errors_1.fail)('INVALID_STAFF_CREDENTIALS', 'Invalid passcode.');
    }
    await secretRef.set({ failedAttempts: 0, lockedUntil: null, lastUsedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    const staffUid = `staff_${input.eventId}_${input.staffId}`;
    try {
        await (0, admin_1.authAdmin)().createUser({ uid: staffUid, displayName: `Gate staff ${staff.name}` });
    }
    catch (err) {
        const code = err;
        if (!String(code?.code ?? '').includes('already-exists'))
            throw err;
    }
    const claims = {
        role: 'gate_staff',
        eventId: input.eventId,
        gate: String(staff.gate),
        staffId: input.staffId,
    };
    await (0, claims_1.mergeCustomClaims)(staffUid, claims);
    const sessionRef = (0, admin_1.db)().collection('gateSessions').doc();
    const sessionId = sessionRef.id;
    await sessionRef.set({
        schemaVersion: 1,
        staffUid,
        staffId: input.staffId,
        eventId: input.eventId,
        gate: String(staff.gate),
        deviceId: input.deviceId,
        status: 'active',
        startedAt: firestore_1.FieldValue.serverTimestamp(),
        lastSeenAt: firestore_1.FieldValue.serverTimestamp(),
        appVersion: input.appVersion ?? null,
    });
    await staffRef.set({ lastLoginAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    const customToken = await (0, admin_1.authAdmin)().createCustomToken(staffUid, claims);
    return {
        ok: true,
        customToken,
        sessionId,
        staffUid,
        gate: String(staff.gate),
        role: String(staff.role),
        displayName: String(staff.name),
    };
});
exports.endGateSession = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ sessionId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const sessionRef = (0, admin_1.db)().collection('gateSessions').doc(input.sessionId);
    const snap = await sessionRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Session not found.');
    if (snap.data()?.staffUid !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This session belongs to another device.');
    await sessionRef.set({ status: 'ended', endedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
});
const notifyStaffRevoked = async (staffUid) => {
    await (0, notify_1.notifyUser)(staffUid, 'staff_revoked', 'Gate access revoked', 'Your gate session has been ended.', {
        deepLink: '/staff/login',
        channel: 'bookings',
    }).catch(() => undefined);
};
exports.notifyStaffRevoked = notifyStaffRevoked;
//# sourceMappingURL=staff.js.map