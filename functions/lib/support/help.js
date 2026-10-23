"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminReplySupportTicket = exports.adminListSupportTickets = exports.replySupportTicket = exports.getSupportTicket = exports.listMySupportTickets = exports.createSupportTicket = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const notify_1 = require("../shared/notify");
const CATEGORIES = ['payments', 'refunds', 'tickets', 'events', 'safety', 'account', 'other'];
const SLA_HOURS = {
    payments: 24,
    refunds: 48,
    tickets: 12,
    events: 24,
    safety: 4,
    account: 48,
    other: 72,
};
exports.createSupportTicket = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        category: zod_1.z.enum(CATEGORIES),
        subject: zod_1.z.string().trim().min(3).max(140),
        description: zod_1.z.string().trim().min(5).max(4000),
        bookingId: zod_1.z.string().max(64).optional(),
        attachments: zod_1.z.array(zod_1.z.string().max(1024)).max(3).default([]),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('supportTickets').doc();
    const slaDueAt = firestore_1.Timestamp.fromMillis(Date.now() + SLA_HOURS[input.category] * 60 * 60 * 1000);
    await ref.set({
        schemaVersion: 1,
        userId: ctx.uid,
        category: input.category,
        bookingId: input.bookingId ?? null,
        subject: input.subject,
        status: 'open',
        priority: input.category === 'safety' ? 'high' : 'normal',
        assignedTo: null,
        attachments: input.attachments,
        slaDueAt,
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await ref.collection('messages').doc().set({
        senderType: 'user',
        senderId: ctx.uid,
        text: input.description,
        attachments: input.attachments,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true, ticketId: ref.id, slaDueAt: slaDueAt.toDate().toISOString() };
});
exports.listMySupportTickets = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const snap = await (0, admin_1.db)()
        .collection('supportTickets')
        .where('userId', '==', ctx.uid)
        .orderBy('lastMessageAt', 'desc')
        .limit(50)
        .get();
    return {
        tickets: snap.docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                category: data.category,
                subject: data.subject,
                status: data.status,
                priority: data.priority,
                bookingId: data.bookingId ?? null,
                slaDueAt: data.slaDueAt ?? null,
                lastMessageAt: data.lastMessageAt ?? null,
                createdAt: data.createdAt ?? null,
            };
        }),
    };
});
exports.getSupportTicket = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ ticketId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const ref = (0, admin_1.db)().collection('supportTickets').doc(input.ticketId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Ticket not found.');
    if (snap.data()?.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This ticket belongs to someone else.');
    const messages = await ref.collection('messages').orderBy('createdAt', 'asc').limit(100).get();
    return {
        ticket: snap.data(),
        messages: messages.docs.map((d) => ({ id: d.id, ...d.data() })),
    };
});
exports.replySupportTicket = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z
        .object({
        ticketId: zod_1.z.string().min(1).max(64),
        text: zod_1.z.string().trim().min(1).max(4000),
        attachments: zod_1.z.array(zod_1.z.string().max(1024)).max(3).default([]),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('supportTickets').doc(input.ticketId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Ticket not found.');
    if (snap.data()?.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'This ticket belongs to someone else.');
    await ref.collection('messages').doc().set({
        senderType: 'user',
        senderId: ctx.uid,
        text: input.text,
        attachments: input.attachments,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await ref.set({ lastMessageAt: firestore_1.FieldValue.serverTimestamp(), status: snap.data()?.status === 'open' ? 'in_progress' : snap.data()?.status }, { merge: true });
    return { ok: true };
});
exports.adminListSupportTickets = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.enum(['open', 'in_progress', 'resolved', 'closed']).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('supportTickets').orderBy('slaDueAt', 'asc').limit(input.limit);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.get();
    return {
        tickets: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
        actor: ctx.uid,
    };
});
exports.adminReplySupportTicket = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        ticketId: zod_1.z.string().min(1).max(64),
        text: zod_1.z.string().trim().min(1).max(4000),
        status: zod_1.z.enum(['open', 'in_progress', 'resolved', 'closed']).optional(),
        assignTo: zod_1.z.string().max(64).optional(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('supportTickets').doc(input.ticketId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Ticket not found.');
    await ref.collection('messages').doc().set({
        senderType: 'agent',
        senderId: ctx.uid,
        text: input.text,
        attachments: [],
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await ref.set({
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        ...(input.status ? { status: input.status } : {}),
        ...(input.assignTo ? { assignedTo: input.assignTo } : {}),
    }, { merge: true });
    await (0, notify_1.notifyUser)(String(snap.data()?.userId), 'support_reply', 'Support replied', input.text.slice(0, 120), { deepLink: `/support/${input.ticketId}`, channel: 'bookings' }).catch(() => undefined);
    return { ok: true };
});
//# sourceMappingURL=help.js.map