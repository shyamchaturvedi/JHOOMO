import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth, requireAdmin } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { notifyUser } from '../shared/notify';

const CATEGORIES = ['payments', 'refunds', 'tickets', 'events', 'safety', 'account', 'other'] as const;
const SLA_HOURS: Record<(typeof CATEGORIES)[number], number> = {
  payments: 24,
  refunds: 48,
  tickets: 12,
  events: 24,
  safety: 4,
  account: 48,
  other: 72,
};

export const createSupportTicket = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      category: z.enum(CATEGORIES),
      subject: z.string().trim().min(3).max(140),
      description: z.string().trim().min(5).max(4000),
      bookingId: z.string().max(64).optional(),
      attachments: z.array(z.string().max(1024)).max(3).default([]),
    })
    .parse(req.data);

  const ref = db().collection('supportTickets').doc();
  const slaDueAt = Timestamp.fromMillis(Date.now() + SLA_HOURS[input.category] * 60 * 60 * 1000);

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
    lastMessageAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  });

  await ref.collection('messages').doc().set({
    senderType: 'user',
    senderId: ctx.uid,
    text: input.description,
    attachments: input.attachments,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, ticketId: ref.id, slaDueAt: slaDueAt.toDate().toISOString() };
});

export const listMySupportTickets = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const snap = await db()
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

export const getSupportTicket = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ ticketId: z.string().min(1).max(64) }).parse(req.data);

  const ref = db().collection('supportTickets').doc(input.ticketId);
  const snap = await ref.get();
  if (!snap.exists) fail('NOT_FOUND', 'Ticket not found.');
  if (snap.data()?.userId !== ctx.uid) fail('FORBIDDEN', 'This ticket belongs to someone else.');

  const messages = await ref.collection('messages').orderBy('createdAt', 'asc').limit(100).get();
  return {
    ticket: snap.data(),
    messages: messages.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
});

export const replySupportTicket = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z
    .object({
      ticketId: z.string().min(1).max(64),
      text: z.string().trim().min(1).max(4000),
      attachments: z.array(z.string().max(1024)).max(3).default([]),
    })
    .parse(req.data);

  const ref = db().collection('supportTickets').doc(input.ticketId);
  const snap = await ref.get();
  if (!snap.exists) fail('NOT_FOUND', 'Ticket not found.');
  if (snap.data()?.userId !== ctx.uid) fail('FORBIDDEN', 'This ticket belongs to someone else.');

  await ref.collection('messages').doc().set({
    senderType: 'user',
    senderId: ctx.uid,
    text: input.text,
    attachments: input.attachments,
    createdAt: FieldValue.serverTimestamp(),
  });
  await ref.set(
    { lastMessageAt: FieldValue.serverTimestamp(), status: snap.data()?.status === 'open' ? 'in_progress' : snap.data()?.status },
    { merge: true },
  );

  return { ok: true };
});

export const adminListSupportTickets = miloOnCall({}, async (req) => {
  const ctx = requireAdmin(req, 'L1');
  const input = z
    .object({
      status: z.enum(['open', 'in_progress', 'resolved', 'closed']).optional(),
      limit: z.number().int().min(1).max(100).default(50),
    })
    .parse(req.data ?? {});

  let query = db().collection('supportTickets').orderBy('slaDueAt', 'asc').limit(input.limit);
  if (input.status) query = query.where('status', '==', input.status);
  const snap = await query.get();

  return {
    tickets: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
    actor: ctx.uid,
  };
});

export const adminReplySupportTicket = miloOnCall({}, async (req) => {
  const ctx = requireAdmin(req, 'L1');
  const input = z
    .object({
      ticketId: z.string().min(1).max(64),
      text: z.string().trim().min(1).max(4000),
      status: z.enum(['open', 'in_progress', 'resolved', 'closed']).optional(),
      assignTo: z.string().max(64).optional(),
    })
    .parse(req.data);

  const ref = db().collection('supportTickets').doc(input.ticketId);
  const snap = await ref.get();
  if (!snap.exists) fail('NOT_FOUND', 'Ticket not found.');

  await ref.collection('messages').doc().set({
    senderType: 'agent',
    senderId: ctx.uid,
    text: input.text,
    attachments: [],
    createdAt: FieldValue.serverTimestamp(),
  });
  await ref.set(
    {
      lastMessageAt: FieldValue.serverTimestamp(),
      ...(input.status ? { status: input.status } : {}),
      ...(input.assignTo ? { assignedTo: input.assignTo } : {}),
    },
    { merge: true },
  );

  await notifyUser(
    String(snap.data()?.userId),
    'support_reply',
    'Support replied',
    input.text.slice(0, 120),
    { deepLink: `/support/${input.ticketId}`, channel: 'bookings' },
  ).catch(() => undefined);

  return { ok: true };
});
