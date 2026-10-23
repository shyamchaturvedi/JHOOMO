import { defineSecret } from 'firebase-functions/params';
import { createHmac, timingSafeEqual } from 'node:crypto';

export const RAZORPAY_KEY_ID = defineSecret('RAZORPAY_KEY_ID');
export const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
export const RAZORPAY_WEBHOOK_SECRET = defineSecret('RAZORPAY_WEBHOOK_SECRET');
export const RAZORPAY_ROUTE_ACCOUNT_ID = defineSecret('RAZORPAY_ROUTE_ACCOUNT_ID');

const API_BASE = 'https://api.razorpay.com/v1';

export interface RazorpayOrder {
  id: string;
  amount: number;
  currency: string;
  receipt?: string;
  status: string;
}

export interface RazorpayRefund {
  id: string;
  amount: number;
  status: string;
}

export interface RazorpayTransfer {
  id: string;
  amount: number;
  status: string;
  account?: string;
}

function authHeader(): string {
  const id = secretValue(RAZORPAY_KEY_ID);
  const secret = secretValue(RAZORPAY_KEY_SECRET);
  return `Basic ${Buffer.from(`${id}:${secret}`).toString('base64')}`;
}

function secretValue(secret: { value(): string }): string {
  try {
    const value = secret.value();
    if (!value) throw new Error('empty');
    return value;
  } catch {
    throw new Error('Payment gateway secret is not configured (RAZORPAY_*).');
  }
}

async function request<T>(path: string, init: RequestInit & { json?: unknown } = {}): Promise<T> {
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
    const message =
      (parsed as { error?: { description?: string } })?.error?.description ?? `HTTP ${res.status}`;
    throw new Error(`Razorpay ${path} failed: ${message}`);
  }
  return parsed as T;
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

/**
 * Create a gateway order for a booking. The captured funds stay with the
 * licensed PA (Razorpay) and are released to the organiser on T+1 through
 * Route held transfers — Milo never custodies funds itself.
 */
export async function createOrder(params: {
  amountPaise: number;
  receipt: string;
  notes?: Record<string, string>;
}): Promise<RazorpayOrder> {
  return request<RazorpayOrder>('/orders', {
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

export async function fetchPayment(paymentId: string): Promise<Record<string, unknown>> {
  return request<Record<string, unknown>>(`/payments/${paymentId}`);
}

export async function fetchOrder(orderId: string): Promise<Record<string, unknown>> {
  return request<Record<string, unknown>>(`/orders/${orderId}`);
}

/**
 * Cancel an unpaid order. Used when a promo code changes the amount after an
 * order was already created — the stale order must be closed so the buyer is
 * never charged the old amount.
 */
export async function cancelOrder(orderId: string): Promise<Record<string, unknown>> {
  return request<Record<string, unknown>>(`/orders/${orderId}/cancel`, { method: 'POST', json: {} });
}

export async function createRefund(params: {
  paymentId: string;
  amountPaise?: number;
  notes?: Record<string, string>;
}): Promise<RazorpayRefund> {
  return request<RazorpayRefund>(`/payments/${params.paymentId}/refund`, {
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
export async function createTransfer(params: {
  account: string;
  amountPaise: number;
  currency?: string;
  referenceId: string;
  notes?: Record<string, string>;
}): Promise<RazorpayTransfer> {
  return request<RazorpayTransfer>('/transfers', {
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

export async function createVirtualAccount(params: {
  customerName: string;
  receipt: string;
  notes?: Record<string, string>;
}): Promise<Record<string, unknown>> {
  return request<Record<string, unknown>>('/virtual_accounts', {
    method: 'POST',
    json: {
      receivers: { types: ['bank_account'] },
      customer: { name: params.customerName },
      description: params.receipt,
      notes: params.notes ?? {},
    },
  });
}

export async function fetchSettlement(settlementId: string): Promise<Record<string, unknown>> {
  return request<Record<string, unknown>>(`/settlements/${settlementId}`);
}

export function verifyWebhookSignature(rawBody: Buffer | string, signature: string): boolean {
  let secret: string;
  try {
    secret = secretValue(RAZORPAY_WEBHOOK_SECRET);
  } catch {
    return false;
  }
  const body = typeof rawBody === 'string' ? rawBody : rawBody.toString('utf8');
  const expected = createHmac('sha256', secret).update(body).digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(signature);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

export function gatewayConfigured(): boolean {
  try {
    secretValue(RAZORPAY_KEY_ID);
    secretValue(RAZORPAY_KEY_SECRET);
    return true;
  } catch {
    return false;
  }
}
