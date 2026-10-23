"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RAZORPAY_ROUTE_ACCOUNT_ID = exports.RAZORPAY_WEBHOOK_SECRET = exports.RAZORPAY_KEY_SECRET = exports.RAZORPAY_KEY_ID = void 0;
exports.createOrder = createOrder;
exports.fetchPayment = fetchPayment;
exports.fetchOrder = fetchOrder;
exports.cancelOrder = cancelOrder;
exports.createRefund = createRefund;
exports.createTransfer = createTransfer;
exports.createVirtualAccount = createVirtualAccount;
exports.fetchSettlement = fetchSettlement;
exports.verifyWebhookSignature = verifyWebhookSignature;
exports.gatewayConfigured = gatewayConfigured;
const params_1 = require("firebase-functions/params");
const node_crypto_1 = require("node:crypto");
exports.RAZORPAY_KEY_ID = (0, params_1.defineSecret)('RAZORPAY_KEY_ID');
exports.RAZORPAY_KEY_SECRET = (0, params_1.defineSecret)('RAZORPAY_KEY_SECRET');
exports.RAZORPAY_WEBHOOK_SECRET = (0, params_1.defineSecret)('RAZORPAY_WEBHOOK_SECRET');
exports.RAZORPAY_ROUTE_ACCOUNT_ID = (0, params_1.defineSecret)('RAZORPAY_ROUTE_ACCOUNT_ID');
const API_BASE = 'https://api.razorpay.com/v1';
function authHeader() {
    const id = secretValue(exports.RAZORPAY_KEY_ID);
    const secret = secretValue(exports.RAZORPAY_KEY_SECRET);
    return `Basic ${Buffer.from(`${id}:${secret}`).toString('base64')}`;
}
function secretValue(secret) {
    try {
        const value = secret.value();
        if (!value)
            throw new Error('empty');
        return value;
    }
    catch {
        throw new Error('Payment gateway secret is not configured (RAZORPAY_*).');
    }
}
async function request(path, init = {}) {
    const { json, ...rest } = init;
    const res = await fetch(`${API_BASE}${path}`, {
        ...rest,
        headers: {
            Authorization: authHeader(),
            'Content-Type': 'application/json',
            ...(rest.headers ?? {}),
        },
        body: json === undefined ? undefined : JSON.stringify(json),
    });
    const text = await res.text();
    const parsed = text ? safeParse(text) : {};
    if (!res.ok) {
        const message = parsed?.error?.description ?? `HTTP ${res.status}`;
        throw new Error(`Razorpay ${path} failed: ${message}`);
    }
    return parsed;
}
function safeParse(text) {
    try {
        return JSON.parse(text);
    }
    catch {
        return { raw: text };
    }
}
/**
 * Create a gateway order for a booking. The captured funds stay with the
 * licensed PA (Razorpay) and are released to the organiser on T+1 through
 * Route held transfers — Milo never custodies funds itself.
 */
async function createOrder(params) {
    return request('/orders', {
        method: 'POST',
        json: {
            amount: params.amountPaise,
            currency: 'INR',
            receipt: params.receipt,
            notes: params.notes ?? {},
            payment_capture: 1,
        },
    });
}
async function fetchPayment(paymentId) {
    return request(`/payments/${paymentId}`);
}
async function fetchOrder(orderId) {
    return request(`/orders/${orderId}`);
}
/**
 * Cancel an unpaid order. Used when a promo code changes the amount after an
 * order was already created — the stale order must be closed so the buyer is
 * never charged the old amount.
 */
async function cancelOrder(orderId) {
    return request(`/orders/${orderId}/cancel`, { method: 'POST', json: {} });
}
async function createRefund(params) {
    return request(`/payments/${params.paymentId}/refund`, {
        method: 'POST',
        json: {
            ...(params.amountPaise ? { amount: params.amountPaise } : {}),
            speed: 'normal',
            notes: params.notes ?? {},
        },
    });
}
/**
 * Route held transfer to a linked organiser account (T+1 settlement leg).
 * Requires the organiser to be onboarded as a Razorpay linked account.
 */
async function createTransfer(params) {
    return request('/transfers', {
        method: 'POST',
        json: {
            account: params.account,
            amount: params.amountPaise,
            currency: params.currency ?? 'INR',
            reference_id: params.referenceId,
            mode: 'UPI',
            on_hold: false,
            description: params.referenceId,
            notes: params.notes ?? {},
        },
    });
}
async function createVirtualAccount(params) {
    return request('/virtual_accounts', {
        method: 'POST',
        json: {
            receivers: { types: ['bank_account'] },
            customer: { name: params.customerName },
            description: params.receipt,
            notes: params.notes ?? {},
        },
    });
}
async function fetchSettlement(settlementId) {
    return request(`/settlements/${settlementId}`);
}
function verifyWebhookSignature(rawBody, signature) {
    let secret;
    try {
        secret = secretValue(exports.RAZORPAY_WEBHOOK_SECRET);
    }
    catch {
        return false;
    }
    const body = typeof rawBody === 'string' ? rawBody : rawBody.toString('utf8');
    const expected = (0, node_crypto_1.createHmac)('sha256', secret).update(body).digest('hex');
    const a = Buffer.from(expected);
    const b = Buffer.from(signature);
    if (a.length !== b.length)
        return false;
    return (0, node_crypto_1.timingSafeEqual)(a, b);
}
function gatewayConfigured() {
    try {
        secretValue(exports.RAZORPAY_KEY_ID);
        secretValue(exports.RAZORPAY_KEY_SECRET);
        return true;
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=razorpay.js.map