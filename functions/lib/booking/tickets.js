"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateTicketPdf = exports.getTicketQrToken = void 0;
const pdfkit_1 = __importDefault(require("pdfkit"));
const qrcode_1 = __importDefault(require("qrcode"));
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const crypto_1 = require("../shared/crypto");
const gatekeys_1 = require("../shared/gatekeys");
const time_1 = require("../shared/time");
exports.getTicketQrToken = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ ticketId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const ticketSnap = await (0, admin_1.db)().collection('tickets').doc(input.ticketId).get();
    if (!ticketSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Ticket not found.');
    const ticket = ticketSnap.data();
    const isOwner = ticket.userId === ctx.uid;
    const isOrganizer = ticket.organizerId === ctx.uid;
    if (!isOwner && !isOrganizer)
        (0, errors_1.fail)('FORBIDDEN', 'You cannot access this ticket.');
    if (ticket.status === 'void' || ticket.status === 'refunded') {
        (0, errors_1.fail)('TICKET_REFUNDED_OR_VOID', 'This ticket is no longer valid.');
    }
    const secretSnap = await (0, admin_1.db)().collection('ticketSecrets').doc(input.ticketId).get();
    const secret = secretSnap.data()?.secret;
    if (!secret)
        (0, errors_1.fail)('TICKET_INVALID', 'This ticket could not be verified.');
    const issuedAt = Math.floor(Date.now() / 1000);
    const signature = (0, crypto_1.signQrToken)(secret, input.ticketId, ticket.userId, issuedAt);
    const payload = `MILO1.${input.ticketId}.${issuedAt}.${signature}`;
    return {
        payload,
        issuedAt,
        expiresAt: issuedAt + crypto_1.QR_TOKEN_TTL_SECONDS,
        ttlSeconds: crypto_1.QR_TOKEN_TTL_SECONDS,
        status: ticket.status,
    };
});
exports.generateTicketPdf = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = zod_1.z.object({ ticketId: zod_1.z.string().min(1).max(64) }).parse(req.data);
    const ticketSnap = await (0, admin_1.db)().collection('tickets').doc(input.ticketId).get();
    if (!ticketSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Ticket not found.');
    const raw = ticketSnap.data();
    const ticket = {
        id: input.ticketId,
        refCode: String(raw.refCode ?? ''),
        tierName: String(raw.tierName ?? ''),
        holderName: raw.holderName ?? undefined,
        eventId: String(raw.eventId ?? ''),
        eventTitle: String(raw.eventTitle ?? ''),
        eventStartAt: raw.eventStartAt,
        seq: Number(raw.seq ?? 0),
        admits: Number(raw.admits ?? 1),
        userId: String(raw.userId ?? ''),
    };
    if (ticket.userId !== ctx.uid)
        (0, errors_1.fail)('FORBIDDEN', 'You cannot download this ticket.');
    const eventSnap = await (0, admin_1.db)().collection('events').doc(ticket.eventId).get();
    const event = eventSnap.data() ?? {};
    if (event.allowPdfTickets === false) {
        (0, errors_1.fail)('FORBIDDEN', 'The organiser has disabled PDF tickets for this event.');
    }
    const gateSecret = await (0, admin_1.db)().collection('eventSecrets').doc(ticket.eventId).get();
    const privateKeyPem = gateSecret.data()?.gatePrivateKey;
    if (!privateKeyPem)
        (0, errors_1.fail)('INTERNAL', 'Offline signing key is not provisioned for this event.');
    const offlineSignature = (0, gatekeys_1.signOfflineQr)(privateKeyPem, ticket.id, ticket.eventId, 0);
    const payload = (0, gatekeys_1.buildStaticOfflinePayload)(ticket.id, ticket.eventId, offlineSignature);
    const qrBuffer = await qrcode_1.default.toBuffer(payload, {
        type: 'png',
        width: 480,
        margin: 2,
        errorCorrectionLevel: 'M',
    });
    const pdfBuffer = await renderTicketPdf({ ticket, event, qrBuffer });
    const path = `tickets/${ticket.id}.pdf`;
    const bucket = (0, admin_1.storageAdmin)().bucket();
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
async function renderTicketPdf(params) {
    const { ticket, event, qrBuffer } = params;
    const venue = (event.venue ?? {});
    const startAt = ticket.eventStartAt?.toDate?.() ?? new Date();
    const doc = new pdfkit_1.default({ size: 'A4', margin: 48 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    const finished = new Promise((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));
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
        .text('This pass is personal and non-transferable. The QR is valid for first scan only. ' +
        'Show the QR at the gate; screenshots may be rejected. Entry is subject to the event age policy and ID check.', 300, doc.y + 24, { width: 245 });
    doc
        .fontSize(8)
        .fillColor('#94A3B8')
        .text(`Milo · Ticket ${ticket.id} · Issued ${(0, time_1.istDateKey)(new Date())}`, 48, 760, { width: 500 });
    doc.end();
    return finished;
}
function formatIst(d) {
    const shifted = new Date(d.getTime() + 5.5 * 60 * 60 * 1000);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const hh = String(shifted.getUTCHours()).padStart(2, '0');
    const mm = String(shifted.getUTCMinutes()).padStart(2, '0');
    return `${shifted.getUTCDate()} ${months[shifted.getUTCMonth()]} ${shifted.getUTCFullYear()}, ${hh}:${mm} IST`;
}
//# sourceMappingURL=tickets.js.map