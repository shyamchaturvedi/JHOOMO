"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.istDateKey = exports.syncOfflineCheckins = exports.getGateManifest = exports.admitManualLookup = exports.manualLookup = exports.gateCheckIn = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const crypto_1 = require("../shared/crypto");
const gatekeys_1 = require("../shared/gatekeys");
const ratelimit_1 = require("../shared/ratelimit");
const crypto_2 = require("../shared/crypto");
const time_1 = require("../shared/time");
Object.defineProperty(exports, "istDateKey", { enumerable: true, get: function () { return time_1.istDateKey; } });
const firebase_functions_1 = require("firebase-functions");
const GATE_STATS_SHARDS = 10;
async function requireActiveSession(staff, sessionId, deviceId) {
    if (!sessionId)
        (0, errors_1.fail)('FORBIDDEN', 'Start a gate session before scanning.');
    const snap = await (0, admin_1.db)().collection('gateSessions').doc(sessionId).get();
    if (!snap.exists)
        (0, errors_1.fail)('FORBIDDEN', 'Gate session not found.');
    const session = snap.data();
    if (session.staffUid !== staff.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This gate session belongs to another device.');
    if (session.status !== 'active')
        (0, errors_1.fail)('FORBIDDEN', 'This gate session has ended.');
    if (session.deviceId !== deviceId)
        (0, errors_1.fail)('FORBIDDEN', 'This gate session is bound to another device.');
    if (session.eventId !== staff.eventId)
        (0, errors_1.fail)('FORBIDDEN', 'This gate session belongs to another event.');
    return {
        id: sessionId,
        staffUid: String(session.staffUid),
        staffId: String(session.staffId),
        eventId: String(session.eventId),
        gate: String(session.gate),
        deviceId: String(session.deviceId),
        status: String(session.status),
    };
}
function dayIndexFor(eventStartAt, at) {
    const start = (0, time_1.istDayStartUtc)(eventStartAt.toDate()).getTime();
    const current = (0, time_1.istDayStartUtc)(at).getTime();
    return Math.floor((current - start) / 86_400_000);
}
const checkInSchema = zod_1.z.object({
    payload: zod_1.z.string().trim().min(10).max(600),
    deviceId: zod_1.z.string().trim().min(8).max(120),
    sessionId: zod_1.z.string().trim().min(1).max(64),
});
exports.gateCheckIn = (0, callable_1.miloOnCall)({}, async (req) => {
    const staff = (0, auth_1.requireStaff)(req);
    const input = checkInSchema.parse(req.data);
    const session = await requireActiveSession(staff, input.sessionId, input.deviceId);
    const parsed = (0, gatekeys_1.parseQrPayload)(input.payload);
    if (!parsed || parsed.kind === 'unknown')
        (0, errors_1.fail)('TICKET_INVALID', 'That QR code could not be read.');
    const ticketId = parsed.ticketId;
    const ts = parsed.ts ?? 0;
    const nowSec = Math.floor(Date.now() / 1000);
    if (Math.abs(nowSec - ts) > 60) {
        (0, errors_1.fail)('QR_EXPIRED', 'This QR code has expired. Ask the guest to refresh their ticket.');
    }
    const ticketSnap = await (0, admin_1.db)().collection('tickets').doc(ticketId).get();
    if (!ticketSnap.exists)
        (0, errors_1.fail)('TICKET_INVALID', 'This ticket does not exist.');
    const ticket = ticketSnap.data();
    if (ticket.eventId !== staff.eventId)
        (0, errors_1.fail)('TICKET_WRONG_EVENT', 'This ticket is for another event.');
    const secretSnap = await (0, admin_1.db)().collection('ticketSecrets').doc(ticketId).get();
    const secret = secretSnap.data()?.secret;
    if (!secret)
        (0, errors_1.fail)('TICKET_INVALID', 'This ticket could not be verified.');
    if (!(0, crypto_1.verifyQrToken)(secret, ticketId, String(ticket.userId), ts, parsed.signature)) {
        (0, errors_1.fail)('TICKET_INVALID', 'Signature verification failed.');
    }
    return runCheckIn({
        eventId: staff.eventId,
        ticketId,
        gate: session.gate,
        staffId: session.staffId,
        sessionId: session.id,
        mode: 'online',
    });
});
async function runCheckIn(input) {
    const ticketRef = (0, admin_1.db)().collection('tickets').doc(input.ticketId);
    const checkinRef = (0, admin_1.db)().collection('events').doc(input.eventId).collection('checkins').doc(input.ticketId);
    const tierId = (await ticketRef.get()).data()?.tierId;
    try {
        const result = await (0, admin_1.db)().runTransaction(async (tx) => {
            const ticketSnap = await tx.get(ticketRef);
            if (!ticketSnap.exists)
                (0, errors_1.fail)('TICKET_INVALID', 'This ticket does not exist.');
            const ticket = ticketSnap.data();
            const status = String(ticket.status);
            if (status === 'void' || status === 'refunded') {
                (0, errors_1.fail)('TICKET_REFUNDED_OR_VOID', 'This ticket was refunded or voided.');
            }
            if (tierId) {
                const tierSnap = await tx.get((0, admin_1.db)().collection('events').doc(input.eventId).collection('ticketTiers').doc(tierId));
                const validDays = tierSnap.data()?.validDays;
                if (validDays && validDays.length > 0) {
                    const eventStartAt = ticket.eventStartAt;
                    if (!eventStartAt)
                        (0, errors_1.fail)('TICKET_INVALID', 'This ticket could not be verified.');
                    const index = dayIndexFor(eventStartAt, new Date());
                    if (!validDays.includes(index)) {
                        (0, errors_1.fail)('NOT_VALID_TODAY', 'This ticket is not valid for today.');
                    }
                }
            }
            await tx.create(checkinRef, {
                schemaVersion: 1,
                ticketId: input.ticketId,
                bookingId: ticket.bookingId,
                tierId,
                gate: input.gate,
                staffId: input.staffId,
                sessionId: input.sessionId,
                at: firestore_1.FieldValue.serverTimestamp(),
                mode: input.mode,
                offlineAt: input.offlineAt ?? null,
                attendeeFirstName: firstNameOf(ticket.userId),
                seq: ticket.seq ?? 0,
            });
            tx.update(ticketRef, {
                status: 'checked_in',
                checkedInAt: firestore_1.FieldValue.serverTimestamp(),
                checkedInGate: input.gate,
            });
            const shard = Math.floor(Math.random() * GATE_STATS_SHARDS);
            const statsRef = (0, admin_1.db)().collection('gateStats').doc(input.eventId).collection('shards').doc(String(shard));
            const statsSnap = await tx.get(statsRef);
            const byGate = (statsSnap.data()?.byGate ?? {});
            tx.set(statsRef, {
                total: Number(statsSnap.data()?.total ?? 0) + 1,
                byGate: { ...byGate, [input.gate]: Number(byGate[input.gate] ?? 0) + 1 },
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            const tierName = tierId
                ? (await (0, admin_1.db)().collection('events').doc(input.eventId).collection('ticketTiers').doc(tierId).get()).data()?.name ?? ''
                : String(ticket.tierName ?? '');
            return {
                result: 'APPROVED',
                firstName: firstNameOf(ticket.userId),
                tierName,
                admits: Number(ticket.admits ?? 1),
                seq: Number(ticket.seq ?? 0),
                gate: input.gate,
                at: new Date().toISOString(),
                mode: input.mode,
            };
        });
        await (0, admin_1.db)()
            .collection('events')
            .doc(input.eventId)
            .collection('staff')
            .doc(input.staffId)
            .set({ scanCount: firestore_1.FieldValue.increment(1) }, { merge: true });
        return result;
    }
    catch (err) {
        if (isAlreadyExists(err)) {
            const existing = await checkinRef.get();
            const data = existing.data() ?? {};
            return {
                result: 'ALREADY_CHECKED_IN',
                firstName: data.attendeeFirstName ?? '',
                at: data.at?.toDate().toISOString() ?? null,
                gate: data.gate ?? '',
                scannedBy: data.staffId ?? '',
            };
        }
        throw err;
    }
}
function isAlreadyExists(err) {
    const code = err?.code;
    if (code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS')
        return true;
    const message = err instanceof Error ? err.message : String(err);
    return message.includes('ALREADY_EXISTS') || message.includes('already exists');
}
let nameCache = new Map();
async function firstNameOf(userId) {
    const cached = nameCache.get(userId);
    if (cached && Date.now() - cached.at < 60_000)
        return cached.name;
    const snap = await (0, admin_1.db)().collection('users').doc(userId).get();
    const displayName = String(snap.data()?.displayName ?? '').trim();
    const name = displayName.split(/\s+/)[0] || 'Guest';
    nameCache.set(userId, { name, at: Date.now() });
    return name;
}
const manualLookupSchema = zod_1.z.object({
    bookingRef: zod_1.z.string().trim().toUpperCase().regex(/^MILO-\d{6}$/, 'Enter a booking reference like MILO-123456'),
    phoneLast4: zod_1.z.string().regex(/^\d{4}$/, 'Enter the last 4 digits of the guest phone number'),
    sessionId: zod_1.z.string().trim().min(1).max(64),
    deviceId: zod_1.z.string().trim().min(8).max(120),
});
exports.manualLookup = (0, callable_1.miloOnCall)({}, async (req) => {
    const staff = (0, auth_1.requireStaff)(req);
    const input = manualLookupSchema.parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('manual_lookup', staff.uid), 5, 60 * 1000);
    await requireActiveSession(staff, input.sessionId, input.deviceId);
    const refSnap = await (0, admin_1.db)().collection('bookingRefs').doc(input.bookingRef).get();
    const bookingId = refSnap.data()?.bookingId;
    if (!bookingId)
        (0, errors_1.fail)('NOT_FOUND', 'No booking matches that reference.');
    const bookingSnap = await (0, admin_1.db)().collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'No booking matches that reference.');
    const booking = bookingSnap.data();
    if (booking.eventId !== staff.eventId)
        (0, errors_1.fail)('TICKET_WRONG_EVENT', 'This ticket is for another event.');
    const userSnap = await (0, admin_1.db)().collection('users').doc(String(booking.userId)).get();
    const user = userSnap.data() ?? {};
    const phone = String(user.phone ?? '');
    if (!phone.endsWith(input.phoneLast4))
        (0, errors_1.fail)('NOT_FOUND', 'The phone number does not match this booking.');
    const tickets = await (0, admin_1.db)().collection('tickets').where('bookingId', '==', bookingId).get();
    const ticket = tickets.docs.find((t) => t.data().status === 'valid') ?? tickets.docs[0];
    if (!ticket)
        (0, errors_1.fail)('NOT_FOUND', 'No ticket found for this booking.');
    const tierId = ticket.data().tierId;
    const tierName = tierId
        ? (await (0, admin_1.db)().collection('events').doc(staff.eventId).collection('ticketTiers').doc(tierId).get()).data()?.name ?? ''
        : String(ticket.data().tierName ?? '');
    return {
        result: 'FOUND',
        ticketId: ticket.id,
        firstName: firstNameOf(String(booking.userId)),
        tierName,
        admits: Number(ticket.data().admits ?? 1),
        seq: Number(ticket.data().seq ?? 0),
        status: String(ticket.data().status),
    };
});
exports.admitManualLookup = (0, callable_1.miloOnCall)({}, async (req) => {
    const staff = (0, auth_1.requireStaff)(req);
    const input = zod_1.z
        .object({
        ticketId: zod_1.z.string().min(1).max(64),
        sessionId: zod_1.z.string().trim().min(1).max(64),
        deviceId: zod_1.z.string().trim().min(8).max(120),
    })
        .parse(req.data);
    const session = await requireActiveSession(staff, input.sessionId, input.deviceId);
    const ticketSnap = await (0, admin_1.db)().collection('tickets').doc(input.ticketId).get();
    if (!ticketSnap.exists)
        (0, errors_1.fail)('TICKET_INVALID', 'This ticket does not exist.');
    if (ticketSnap.data()?.eventId !== staff.eventId)
        (0, errors_1.fail)('TICKET_WRONG_EVENT', 'This ticket is for another event.');
    return runCheckIn({
        eventId: staff.eventId,
        ticketId: input.ticketId,
        gate: session.gate,
        staffId: session.staffId,
        sessionId: session.id,
        mode: 'online',
    });
});
exports.getGateManifest = (0, callable_1.miloOnCall)({}, async (req) => {
    const staff = (0, auth_1.requireStaff)(req);
    const input = zod_1.z.object({ eventId: zod_1.z.string().min(1).max(64).optional() }).parse(req.data ?? {});
    const eventId = input.eventId ?? staff.eventId;
    if (eventId !== staff.eventId)
        (0, errors_1.fail)('FORBIDDEN', 'You can only download the manifest for your event.');
    const [tickets, tierSnaps, secretSnap] = await Promise.all([
        (0, admin_1.db)().collection('tickets').where('eventId', '==', eventId).get(),
        (0, admin_1.db)().collection('events').doc(eventId).collection('ticketTiers').get(),
        (0, admin_1.db)().collection('eventSecrets').doc(eventId).get(),
    ]);
    const publicKey = secretSnap.data()?.gatePublicKey;
    if (!publicKey)
        (0, errors_1.fail)('INTERNAL', 'Offline signing is not provisioned for this event.');
    const tierMap = new Map();
    for (const tier of tierSnaps.docs) {
        tierMap.set(tier.id, {
            name: String(tier.data().name ?? ''),
            validDays: tier.data().validDays ?? null,
        });
    }
    const entries = tickets.docs.map((t) => {
        const data = t.data();
        const tier = tierMap.get(String(data.tierId ?? ''));
        return {
            ticketIdHash: (0, crypto_2.sha256Hex)(t.id),
            tierId: String(data.tierId ?? ''),
            tierName: tier?.name ?? String(data.tierName ?? ''),
            admits: Number(data.admits ?? 1),
            seq: Number(data.seq ?? 0),
            holderFirstName: String(data.holderName ?? '').split(/\s+/)[0] ?? '',
            validDays: tier?.validDays ?? null,
            status: String(data.status),
        };
    });
    return {
        eventId,
        eventPublicKey: publicKey,
        algorithm: 'ed25519',
        generatedAt: new Date().toISOString(),
        expiresAt: new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString(),
        count: entries.length,
        entries,
    };
});
const syncSchema = zod_1.z.object({
    sessionId: zod_1.z.string().trim().min(1).max(64),
    deviceId: zod_1.z.string().trim().min(8).max(120),
    checkins: zod_1.z
        .array(zod_1.z.object({
        ticketId: zod_1.z.string().min(1).max(64),
        at: zod_1.z.number().int().positive(),
        gate: zod_1.z.string().trim().min(1).max(40),
        mode: zod_1.z.enum(['online', 'offline']).default('offline'),
    }))
        .max(500),
});
exports.syncOfflineCheckins = (0, callable_1.miloOnCall)({}, async (req) => {
    const staff = (0, auth_1.requireStaff)(req);
    const input = syncSchema.parse(req.data);
    const session = await requireActiveSession(staff, input.sessionId, input.deviceId);
    const ordered = [...input.checkins].sort((a, b) => a.at - b.at);
    const results = [];
    for (const entry of ordered) {
        try {
            const outcome = await runCheckIn({
                eventId: staff.eventId,
                ticketId: entry.ticketId,
                gate: entry.gate,
                staffId: session.staffId,
                sessionId: session.id,
                mode: 'offline',
                offlineAt: firestore_1.Timestamp.fromMillis(entry.at),
            });
            results.push({ ticketId: entry.ticketId, ...outcome });
        }
        catch (err) {
            const code = err?.code;
            results.push({
                ticketId: entry.ticketId,
                result: 'FAILED',
                error: code ?? (err instanceof Error ? err.message : 'unknown'),
            });
        }
    }
    const conflicts = results.filter((r) => r.result === 'ALREADY_CHECKED_IN');
    if (conflicts.length > 0) {
        firebase_functions_1.logger.warn('gate.sync.duplicate_conflicts', {
            eventId: staff.eventId,
            gate: session.gate,
            count: conflicts.length,
        });
    }
    return {
        synced: results.length,
        approved: results.filter((r) => r.result === 'APPROVED').length,
        duplicates: conflicts.length,
        results,
    };
});
//# sourceMappingURL=checkin.js.map