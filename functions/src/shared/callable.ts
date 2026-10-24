import { CallableOptions, CallableRequest, HttpsError } from 'firebase-functions/https';
import { onCall } from 'firebase-functions/https';
import { logger } from 'firebase-functions';
import { randomUUID } from 'node:crypto';
import { toHttpsError } from './errors';
import { MILO_KYC_DATA_KEY } from './envelope';
import {
  KYC_VENDOR_API_KEY,
  KYC_VENDOR_BASE_URL,
  SMS_DLT_SENDER_ID,
  SMS_DLT_TEMPLATE_ID,
  SMS_PROVIDER_API_KEY,
} from './vendors';
import {
  RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET,
} from './razorpay';

/**
 * Secret params must be bound to the function declaration, otherwise calling
 * `.value()` at runtime throws. Attach every integration secret the callables
 * may touch so enabling a provider never silently disables the feature.
 */
const MILO_SECRETS = [
  MILO_KYC_DATA_KEY,
  KYC_VENDOR_API_KEY,
  KYC_VENDOR_BASE_URL,
  SMS_PROVIDER_API_KEY,
  SMS_DLT_TEMPLATE_ID,
  SMS_DLT_SENDER_ID,
  RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET,
];

export interface MiloCallableOptions<T = unknown> extends CallableOptions<T> {
  enforceAppCheck?: boolean;
  rateLimit?: { key: string; limit: number; windowMs: number };
}

function appCheckEnforced(): boolean {
  return process.env.MILO_APPCHECK_ENFORCE !== 'false';
}

export function requestIdOf(req: CallableRequest<unknown>): string {
  const header = req.rawRequest?.headers?.['x-request-id'];
  const value = Array.isArray(header) ? header[0] : header;
  return typeof value === 'string' && value.length > 0 && value.length <= 64 ? value : randomUUID();
}

export function miloOnCall<T = unknown, R = unknown>(
  opts: MiloCallableOptions<T>,
  handler: (req: CallableRequest<T>) => Promise<R> | R,
) {
  const { enforceAppCheck, ...rest } = opts;
  return onCall<T, Promise<R> | R>(
    {
      region: 'asia-south1',
      enforceAppCheck: enforceAppCheck ?? appCheckEnforced(),
      ...rest,
      secrets: [...(rest.secrets ?? []), ...MILO_SECRETS],
    },
    async (req) => {
      const requestId = requestIdOf(req as CallableRequest<unknown>);
      const started = Date.now();
      try {
        const result = await handler(req);
        logger.info('milo.callable.ok', {
          requestId,
          name: (req as { functionName?: string }).functionName ?? 'unknown',
          uid: req.auth?.uid ?? null,
          durationMs: Date.now() - started,
        });
        return result;
      } catch (err) {
        const httpError = toHttpsError(err);
        logger.error('milo.callable.err', {
          requestId,
          name: (req as { functionName?: string }).functionName ?? 'unknown',
          uid: req.auth?.uid ?? null,
          durationMs: Date.now() - started,
          code: httpError.message,
          httpStatus: httpError.code,
          stack: err instanceof Error ? err.stack : undefined,
        });
        throw httpError;
      }
    },
  );
}

export function unauthenticated(): HttpsError {
  return new HttpsError('unauthenticated', 'UNAUTHENTICATED', {
    code: 'UNAUTHENTICATED',
    message: 'Please sign in to continue.',
  });
}
