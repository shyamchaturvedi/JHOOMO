"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SMS_DLT_SENDER_ID = exports.SMS_DLT_TEMPLATE_ID = exports.SMS_PROVIDER_API_KEY = exports.KYC_VENDOR_BASE_URL = exports.KYC_VENDOR_API_KEY = void 0;
exports.verifyPan = verifyPan;
exports.verifyBank = verifyBank;
exports.nameMatchScore = nameMatchScore;
exports.sendSms = sendSms;
const params_1 = require("firebase-functions/params");
exports.KYC_VENDOR_API_KEY = (0, params_1.defineSecret)('KYC_VENDOR_API_KEY');
exports.KYC_VENDOR_BASE_URL = (0, params_1.defineSecret)('KYC_VENDOR_BASE_URL');
exports.SMS_PROVIDER_API_KEY = (0, params_1.defineSecret)('SMS_PROVIDER_API_KEY');
exports.SMS_DLT_TEMPLATE_ID = (0, params_1.defineSecret)('SMS_DLT_TEMPLATE_ID');
exports.SMS_DLT_SENDER_ID = (0, params_1.defineSecret)('SMS_DLT_SENDER_ID');
async function vendorUrl(path) {
    try {
        const base = exports.KYC_VENDOR_BASE_URL.value();
        if (!base)
            return null;
        return `${base.replace(/\/$/, '')}${path}`;
    }
    catch {
        return null;
    }
}
async function vendorKey() {
    try {
        const key = exports.KYC_VENDOR_API_KEY.value();
        return key || null;
    }
    catch {
        return null;
    }
}
/**
 * PAN verification through the configured KYC vendor adapter.
 * Fails closed: an unavailable vendor can never produce a `valid` result, so
 * the organiser is routed to manual review instead of auto-verification.
 */
async function verifyPan(pan) {
    const url = await vendorUrl('/pan/verify');
    const key = await vendorKey();
    if (!url || !key) {
        return { status: 'unavailable', message: 'KYC vendor not configured.' };
    }
    try {
        const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
            body: JSON.stringify({ pan }),
        });
        if (!res.ok)
            return { status: 'unavailable', message: `Vendor HTTP ${res.status}` };
        const body = (await res.json());
        const valid = body.valid === true || body.status === 'valid';
        return {
            status: valid ? 'valid' : 'invalid',
            nameOnRecord: typeof body.name === 'string' ? body.name : undefined,
            entityType: typeof body.entityType === 'string' ? body.entityType : undefined,
            aadhaarLinked: body.aadhaarLinked === 'yes' || body.aadhaarLinked === 'no' || body.aadhaarLinked === 'na'
                ? body.aadhaarLinked
                : undefined,
        };
    }
    catch (err) {
        return { status: 'unavailable', message: err instanceof Error ? err.message : 'vendor error' };
    }
}
/**
 * Penny-drop verification of a beneficiary account.
 * The ₹1 test credit is executed by the vendor; we only consume the result.
 */
async function verifyBank(params) {
    const url = await vendorUrl('/bank/pennydrop');
    const key = await vendorKey();
    if (!url || !key) {
        return { status: 'unavailable', message: 'KYC vendor not configured.' };
    }
    try {
        const res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
            body: JSON.stringify({
                accountNumber: params.accountNumber,
                ifsc: params.ifsc,
                name: params.name,
            }),
        });
        if (!res.ok)
            return { status: 'unavailable', message: `Vendor HTTP ${res.status}` };
        const body = (await res.json());
        const status = body.status === 'verified' ? 'verified' : body.status === 'mismatch' ? 'mismatch' : 'unavailable';
        return {
            status,
            beneficiaryName: typeof body.beneficiaryName === 'string' ? body.beneficiaryName : undefined,
            bankName: typeof body.bankName === 'string' ? body.bankName : undefined,
            branch: typeof body.branch === 'string' ? body.branch : undefined,
            reference: typeof body.reference === 'string' ? body.reference : undefined,
        };
    }
    catch (err) {
        return { status: 'unavailable', message: err instanceof Error ? err.message : 'vendor error' };
    }
}
function nameMatchScore(a, b) {
    const norm = (v) => v
        .toUpperCase()
        .replace(/[^A-Z0-9 ]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
    const x = norm(a);
    const y = norm(b);
    if (!x || !y)
        return 0;
    if (x === y)
        return 100;
    const xTokens = new Set(x.split(' '));
    const yTokens = new Set(y.split(' '));
    let shared = 0;
    for (const t of xTokens)
        if (yTokens.has(t))
            shared += 1;
    const union = new Set([...xTokens, ...yTokens]).size;
    const tokenScore = union === 0 ? 0 : (shared / union) * 100;
    const prefix = Math.min(x.length, y.length);
    let common = 0;
    while (common < prefix && x[common] === y[common])
        common += 1;
    const prefixScore = prefix === 0 ? 0 : (common / prefix) * 100;
    return Math.round(Math.max(tokenScore, prefixScore));
}
async function sendSms(params) {
    let apiKey = null;
    let senderId = null;
    let templateId = params.templateId;
    try {
        apiKey = exports.SMS_PROVIDER_API_KEY.value() || null;
    }
    catch {
        apiKey = null;
    }
    try {
        senderId = exports.SMS_DLT_SENDER_ID.value() || null;
    }
    catch {
        senderId = null;
    }
    try {
        templateId = templateId ?? exports.SMS_DLT_TEMPLATE_ID.value();
    }
    catch {
        templateId = undefined;
    }
    if (!apiKey || !senderId) {
        console.warn('SMS not sent — DLT provider not configured.', { to: maskPhoneForLog(params.to) });
        return { sent: false };
    }
    try {
        const res = await fetch('https://control.msg91.com/api/v5/flow/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', authkey: apiKey },
            body: JSON.stringify({
                sender: senderId,
                template_id: templateId,
                short_url: '0',
                recipients: [{ mobiles: params.to, VAR1: params.body }],
            }),
        });
        const ok = res.ok;
        if (!ok)
            console.warn('SMS provider rejected the request', await res.text());
        return { sent: ok };
    }
    catch (err) {
        console.warn('SMS provider error', err instanceof Error ? err.message : err);
        return { sent: false };
    }
}
function maskPhoneForLog(phone) {
    return phone.length > 4 ? `***${phone.slice(-3)}` : '***';
}
//# sourceMappingURL=vendors.js.map