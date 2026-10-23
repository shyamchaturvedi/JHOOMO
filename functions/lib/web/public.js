"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmEmergencyContactLink = exports.sosTrackingPage = exports.referralRedirect = void 0;
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/https");
const firebase_functions_1 = require("firebase-functions");
const admin_1 = require("../shared/admin");
const privacy_1 = require("../profile/privacy");
const APP_DEEP_LINK = 'https://milo.live';
/**
 * Referral landing route: `/r/{code}` and `/e/{eventId}`.
 * Stores the attribution server-side (last-click, 30-day window) and then
 * redirects into the app. No PII is written and no secret is exposed.
 */
exports.referralRedirect = (0, https_1.onRequest)({ region: 'asia-south1' }, async (req, res) => {
    const path = req.path.replace(/^\/+/, '');
    const [kind, rawValue] = path.split('/');
    const value = decodeURIComponent(rawValue ?? '').trim();
    if (!value || !['r', 'e'].includes(kind)) {
        res.redirect(302, `${APP_DEEP_LINK}/events`);
        return;
    }
    const ip = req.headers['x-forwarded-for'];
    const ipValue = Array.isArray(ip) ? ip[0] : (ip ?? '');
    try {
        if (kind === 'r') {
            const codeSnap = await (0, admin_1.db)().collection('referralCodes').doc(value.toUpperCase()).get();
            if (!codeSnap.exists) {
                res.redirect(302, `${APP_DEEP_LINK}/events`);
                return;
            }
            const promoterId = String(codeSnap.data()?.promoterId ?? '');
            await (0, admin_1.db)()
                .collection('referralAttributions')
                .add({
                code: value.toUpperCase(),
                promoterId,
                source: 'link',
                ip: ipValue ?? null,
                userAgent: String(req.headers['user-agent'] ?? '').slice(0, 300),
                createdAt: firestore_1.FieldValue.serverTimestamp(),
                expiresAt: new Date(Date.now() + 30 * 86_400_000),
            })
                .catch(() => undefined);
            res.redirect(302, `${APP_DEEP_LINK}/events?ref=${encodeURIComponent(value.toUpperCase())}`);
            return;
        }
        const eventSnap = await (0, admin_1.db)().collection('events').doc(value).get();
        if (!eventSnap.exists || eventSnap.data()?.status !== 'live') {
            res.redirect(302, `${APP_DEEP_LINK}/events`);
            return;
        }
        res.redirect(302, `${APP_DEEP_LINK}/event/${value}`);
    }
    catch (err) {
        firebase_functions_1.logger.error('referralRedirect.failed', { kind, error: String(err) });
        res.redirect(302, `${APP_DEEP_LINK}/events`);
    }
});
const PAGE_STYLE = `body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#0b0b12;color:#f5f5f7;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:#15151f;border:1px solid #26263a;border-radius:18px;padding:28px;max-width:420px;width:92%}.pill{display:inline-block;background:#2a1530;color:#ff8fb1;border-radius:999px;padding:4px 12px;font-size:12px;font-weight:600;letter-spacing:.4px}h1{font-size:20px;margin:14px 0 6px}p{color:#a5a5bd;line-height:1.5;font-size:14px}.meta{color:#6f6f8a;font-size:12px;margin-top:18px}.btn{display:block;margin-top:20px;background:#e8b04b;color:#1a1a1a;font-weight:700;text-align:center;padding:12px;border-radius:12px;text-decoration:none}`;
/**
 * Read-only SOS tracking page: `/sos/{token}`.
 * The token is hashed server-side; only the holder of the raw token can see
 * the live location of the alert owner.
 */
exports.sosTrackingPage = (0, https_1.onRequest)({ region: 'asia-south1' }, async (req, res) => {
    const token = String(req.path.split('/').filter(Boolean).pop() ?? '').trim();
    if (!token) {
        res.status(400).send('Invalid link');
        return;
    }
    const { createHash } = await Promise.resolve().then(() => __importStar(require('node:crypto')));
    const hash = createHash('sha256').update(token).digest('hex');
    const alerts = await (0, admin_1.db)().collection('sosAlerts').where('trackingTokenHash', '==', hash).limit(1).get();
    if (alerts.empty) {
        res.status(404).type('html').send(`<!doctype html><html><body style="font-family:system-ui;background:#0b0b12;color:#f5f5f7;padding:40px"><h1>Link expired</h1><p style="color:#a5a5bd">This SOS link is no longer valid.</p></body></html>`);
        return;
    }
    const alert = alerts.docs[0].data();
    const location = alert.lastLocation;
    const mapUrl = location
        ? `https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}`
        : 'https://www.google.com/maps';
    res.set('Cache-Control', 'no-store');
    res.type('html').send(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Milo · Safety tracking</title>
<style>${PAGE_STYLE}</style>
</head>
<body>
  <div class="card">
    <span class="pill">SAFETY ALERT ACTIVE</span>
    <h1>Live location sharing</h1>
    <p>This page shows the live location of a Milo safety alert. Keep this link private — anyone with it can see the location.</p>
    <p>Status: <strong>${alert.status}</strong> &middot; Started: ${new Date((alert.startedAt?.toMillis?.() ?? Date.now())).toLocaleString('en-IN')}</p>
    <a class="btn" href="${mapUrl}" target="_blank" rel="noopener">Open in Google Maps</a>
    <div class="meta">If you believe this is an emergency, call 112 immediately.</div>
  </div>
</body>
</html>`);
});
/**
 * Emergency contact confirmation: `/contact/confirm?t={token}`.
 *
 * The contact must confirm from their own device using the token that was
 * SMS'd to them. The token is stored hashed, expires after 72 hours and can
 * only be used once — the account owner can never confirm on their behalf.
 */
exports.confirmEmergencyContactLink = (0, https_1.onRequest)({ region: 'asia-south1' }, async (req, res) => {
    const token = String(req.query.t ?? '').trim();
    if (!token) {
        res.status(400).type('html').send(renderContactPage('Invalid link', 'This confirmation link is not valid.'));
        return;
    }
    const tokenHash = (0, privacy_1.hashContactToken)(token);
    const tokenRef = (0, admin_1.db)().collection('emergencyContactTokens').doc(tokenHash);
    const tokenSnap = await tokenRef.get();
    if (!tokenSnap.exists) {
        res.status(404).type('html').send(renderContactPage('Link expired', 'This confirmation link is no longer valid.'));
        return;
    }
    const record = tokenSnap.data();
    if (record.status !== 'pending') {
        res
            .status(410)
            .type('html')
            .send(renderContactPage('Already used', 'This confirmation link has already been used.'));
        return;
    }
    const expiresAt = record.expiresAt?.toMillis?.() ?? 0;
    if (expiresAt && Date.now() > expiresAt) {
        await tokenRef.set({ status: 'expired', expiredAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        res.status(410).type('html').send(renderContactPage('Link expired', 'This confirmation link has expired.'));
        return;
    }
    const contactRef = (0, admin_1.db)()
        .collection('users')
        .doc(String(record.uid))
        .collection('emergencyContacts')
        .doc(String(record.contactId));
    const contactSnap = await contactRef.get();
    if (!contactSnap.exists) {
        await tokenRef.set({ status: 'revoked', revokedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        res.status(404).type('html').send(renderContactPage('Not found', 'This contact request no longer exists.'));
        return;
    }
    await contactRef.set({
        status: 'confirmed',
        confirmedAt: firestore_1.FieldValue.serverTimestamp(),
        confirmationTokenHash: null,
    }, { merge: true });
    await tokenRef.set({ status: 'used', usedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    const owner = await (0, admin_1.db)().collection('users').doc(String(record.uid)).get();
    const ownerName = String(owner.data()?.displayName ?? 'Someone');
    res.set('Cache-Control', 'no-store');
    res.type('html').send(renderContactPage('You are now an emergency contact', `${ownerName} has added you as an emergency contact on Milo. If they trigger an SOS alert, you will receive an SMS with their live location.`));
});
function renderContactPage(title, body) {
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Milo · ${title}</title>
<style>${PAGE_STYLE}</style>
</head>
<body>
  <div class="card">
    <span class="pill">MILO SAFETY</span>
    <h1>${title}</h1>
    <p>${body}</p>
    <div class="meta">You can close this page.</div>
  </div>
</body>
</html>`;
}
//# sourceMappingURL=public.js.map