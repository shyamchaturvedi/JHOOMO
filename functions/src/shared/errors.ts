import { HttpsError } from 'firebase-functions/https';

export type MiloErrorCode =
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'INVALID_INPUT'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'ALREADY_REGISTERED'
  | 'RATE_LIMITED'
  | 'CONSENT_REQUIRED'
  | 'AGE_RESTRICTED'
  | 'SOLD_OUT'
  | 'LIMIT_EXCEEDED'
  | 'EVENT_NOT_ON_SALE'
  | 'EVENT_ENDED'
  | 'HOLD_EXPIRED'
  | 'PAYMENT_FAILED'
  | 'PAYOUTS_LOCKED'
  | 'KYC_INCOMPLETE'
  | 'INVALID_STAFF_CREDENTIALS'
  | 'TICKET_INVALID'
  | 'TICKET_WRONG_EVENT'
  | 'TICKET_REFUNDED_OR_VOID'
  | 'TICKET_CHECKED_IN'
  | 'NOT_VALID_TODAY'
  | 'QR_EXPIRED'
  | 'ALREADY_CHECKED_IN'
  | 'FEATURE_DISABLED'
  | 'INTERNAL';

const HTTP_STATUS: Record<MiloErrorCode, HttpsError['code']> = {
  UNAUTHENTICATED: 'unauthenticated',
  FORBIDDEN: 'permission-denied',
  INVALID_INPUT: 'invalid-argument',
  NOT_FOUND: 'not-found',
  CONFLICT: 'already-exists',
  ALREADY_REGISTERED: 'already-exists',
  RATE_LIMITED: 'resource-exhausted',
  CONSENT_REQUIRED: 'failed-precondition',
  AGE_RESTRICTED: 'failed-precondition',
  SOLD_OUT: 'failed-precondition',
  LIMIT_EXCEEDED: 'failed-precondition',
  EVENT_NOT_ON_SALE: 'failed-precondition',
  EVENT_ENDED: 'failed-precondition',
  HOLD_EXPIRED: 'failed-precondition',
  PAYMENT_FAILED: 'failed-precondition',
  PAYOUTS_LOCKED: 'failed-precondition',
  KYC_INCOMPLETE: 'failed-precondition',
  INVALID_STAFF_CREDENTIALS: 'unauthenticated',
  TICKET_INVALID: 'failed-precondition',
  TICKET_WRONG_EVENT: 'failed-precondition',
  TICKET_REFUNDED_OR_VOID: 'failed-precondition',
  TICKET_CHECKED_IN: 'failed-precondition',
  NOT_VALID_TODAY: 'failed-precondition',
  QR_EXPIRED: 'failed-precondition',
  ALREADY_CHECKED_IN: 'already-exists',
  FEATURE_DISABLED: 'failed-precondition',
  INTERNAL: 'internal',
};

export class MiloError extends Error {
  readonly code: MiloErrorCode;
  readonly details: Record<string, unknown>;

  constructor(code: MiloErrorCode, message: string, details: Record<string, unknown> = {}) {
    super(message);
    this.name = 'MiloError';
    this.code = code;
    this.details = details;
  }
}

export function fail(code: MiloErrorCode, message: string, details: Record<string, unknown> = {}): never {
  throw new HttpsError(HTTP_STATUS[code], code, { code, message, ...details });
}

export function toHttpsError(err: unknown): HttpsError {
  if (err instanceof HttpsError) return err;
  if (err instanceof MiloError) {
    return new HttpsError(HTTP_STATUS[err.code], err.code, { code: err.code, message: err.message, ...err.details });
  }
  return new HttpsError('internal', 'INTERNAL', {
    code: 'INTERNAL',
    message: 'Something went wrong. Please try again.',
  });
}

export function isMiloError(err: unknown): err is MiloError {
  return err instanceof MiloError;
}
