import { Timestamp } from 'firebase-admin/firestore';
import PDFDocument from 'pdfkit';
import QRCode from 'qrcode';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth } from '../shared/auth';
import { db, storageAdmin } from '../shared/admin';
import { fail } from '../shared/errors';
import { QR_TOKEN_TTL_SECONDS, signQrToken } from '../shared/crypto';
import { buildStaticOfflinePayload, signOfflineQr } from '../shared/gatekeys';
import { istDateKey } from '../shared/time';

export const getTicketQrToken = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ ticketId: z.string().min(1).max(64) }).parse(req.data);

  const ticketSnap = await db().collection('tickets').doc(input.ticketId).get();
  if (!ticketSnap.exists) fail('NOT_FOUND', 'Ticket not found.');
  const ticket = ticketSnap.data()!;
  const isOwner = ticket.userId === ctx.uid;
  const isOrganizer = ticket.organizerId === ctx.uid;
  if (!isOwner && !isOrganizer) fail('FORBIDDEN', 'You cannot access this ticket.');

  if (ticket.status === 'void' || ticket.status === 'refunded') {
    fail('TICKET_REFUNDED_OR_VOID', 'This ticket is no longer valid.');
  }

  const secretSnap = await db().collection('ticketSecrets').doc(input.ticketId).get();
  const secret = secretSnap.data()?.secret as string | undefined;
  if (!secret) fail('TICKET_INVALID', 'This ticket could not be verified.');

  const issuedAt = Math.floor(Date.now() / 1000);
  const signature = signQrToken(secret, input.ticketId, ticket.userId, issuedAt);
  const payload = `MILO1.${input.ticketId}.${issuedAt}.${signature}`;

  return {
    payload,
    issuedAt,
    expiresAt: issuedAt + QR_TOKEN_TTL_SECONDS,
    ttlSeconds: QR_TOKEN_TTL_SECONDS,
    status: ticket.status,
  };
});

export const generateTicketPdf = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = z.object({ ticketId: z.string().min(1).max(64) }).parse(req.data);

  const ticketSnap = await db().collection('tickets').doc(input.ticketId).get();
  if (!ticketSnap.exists) fail('NOT_FOUND', 'Ticket not found.');
  const raw = ticketSnap.data()!;
  const ticket = {
    id: input.ticketId,
    refCode: String(raw.refCode ?? ''),
    tierName: String(raw.tierName ?? ''),
    holderName: (raw.holderName as string | undefined) ?? undefined,
    eventId: String(raw.eventId ?? ''),
    eventTitle: String(raw.eventTitle ?? ''),
    eventStartAt: raw.eventStartAt as Timestamp,
    seq: Number(raw.seq ?? 0),
    admits: Number(raw.admits ?? 1),
    userId: String(raw.userId ?? ''),
  };
  if (ticket.userId !== ctx.uid) fail('FORBIDDEN', 'You cannot download this ticket.');

  const eventSnap = await db().collection('events').doc(ticket.eventId).get();
  const event = eventSnap.data() ?? {};
  if (event.allowPdfTickets === false) {
    fail('FORBIDDEN', 'The organiser has disabled PDF tickets for this event.');
  }

  const gateSecret = await db().collection('eventSecrets').doc(ticket.eventId).get();
  const privateKeyPem = gateSecret.data()?.gatePrivateKey as string | undefined;
  if (!privateKeyPem) fail('INTERNAL', 'Offline signing key is not provisioned for this event.');

  const offlineSignature = signOfflineQr(privateKeyPem, ticket.id, ticket.eventId, 0);
  const payload = buildStaticOfflinePayload(ticket.id, ticket.eventId, offlineSignature);

  const qrBuffer = await QRCode.toBuffer(payload, {
    type: 'png',
    width: 480,
    margin: 2,
    errorCorrectionLevel: 'M',
  });

  const pdfBuffer = await renderTicketPdf({ ticket, event, qrBuffer });

  const path = `tickets/${ticket.id}.pdf`;
  const bucket = storageAdmin().bucket();
  await bucket.file(path).save(pdfBuffer, {
    contentType: 'application/pdf',
    metadata: { metadata: { ticketId: ticket.id, bookingId: String(raw.bookingId ?? '') } },
  });

  const [url] = await bucket.file(path).getSignedUrl({
    action: 'read',
    expires: new Date(Date.now() + 15 * 60 * 1000),
  });

  return { url, expiresInSeconds: 900, path };
});
interface TicketForPdf {
  id: string;
  refCode: string;
  tierName: string;
  holderName?: string;
  eventTitle: string;
  eventStartAt: Timestamp;
  seq: number;
  admits: number;
  userId: string;
}
async function renderTicketPdf(params: {
  ticket: TicketForPdf;
  event: Record<string, unknown>;
  qrBuffer: Buffer;
}): Promise<Buffer> {
  const { ticket, event, qrBuffer } = params;
  const venue = (event.venue ?? {}) as { name?: string; address?: string };
  const startAt = ticket.eventStartAt?.toDate?.() ?? new Date();

  const doc = new PDFDocument({ size: 'A4', margin: 48 });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk: Buffer) => chunks.push(chunk));
  const finished = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  doc.rect(0, 0, doc.page.width, 120).fill('#1E293B');
  doc.fillColor('#FFFFFF').fontSize(22).font('Helvetica-Bold').text('MILO', 48, 40);
  doc.fontSize(10).font('Helvetica').fillColor('#E2E8F0').text('Secure event pass', 48, 68);
  doc.fontSize(10).fillColor('#FFFFFF').text(ticket.refCode, 300, 68, { align: 'right', width: 245 });

  doc.fillColor('#0F172A').fontSize(20).font('Helvetica-Bold').text(ticket.eventTitle, 48, 150, { width: 500 });
  doc.fontSize(11).font('Helvetica').fillColor('#334155');
  doc.text(`When: ${formatIst(startAt)}`, 48, doc.y + 8);
  doc.text(`Where: ${venue.name ?? ''}${venue.address ? ` — ${venue.address}` : ''}`, 48, doc.y + 4);
  doc.text(`Pass: ${ticket.tierName}${ticket.holderName ? ` · ${ticket.holderName}` : ''}`, 48, doc.y + 4);
  doc.text(`Admits: ${ticket.admits} · Sequence: ${ticket.seq}`, 48, doc.y + 4);
  doc.text(`Booking: ${ticket.refCode}`, 48, doc.y + 4);

  doc.image(qrBuffer, 48, doc.y + 24, { width: 220 });

  doc
    .fontSize(9)
    .fillColor('#64748B')
    .text(
      'This pass is personal and non-transferable. The QR is valid for first scan only. ' +
        'Show the QR at the gate; screenshots may be rejected. Entry is subject to the event age policy and ID check.',
      300,
      doc.y + 24,
      { width: 245 },
    );

  doc
    .fontSize(8)
    .fillColor('#94A3B8')
    .text(`Milo · Ticket ${ticket.id} · Issued ${istDateKey(new Date())}`, 48, 760, { width: 500 });

  doc.end();
  return finished;
}

function formatIst(d: Date): string {
  const shifted = new Date(d.getTime() + 5.5 * 60 * 60 * 1000);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const hh = String(shifted.getUTCHours()).padStart(2, '0');
  const mm = String(shifted.getUTCMinutes()).padStart(2, '0');
  return `${shifted.getUTCDate()} ${months[shifted.getUTCMonth()]} ${shifted.getUTCFullYear()}, ${hh}:${mm} IST`;
}
