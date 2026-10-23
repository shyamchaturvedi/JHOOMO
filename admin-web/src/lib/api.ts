import { httpsCallable } from 'firebase/functions';
import { functions } from './firebase';

export class AdminApiError extends Error {
  constructor(
    message: string,
    readonly code: string,
  ) {
    super(message);
    this.name = 'AdminApiError';
  }
}

/**
 * Calls a backend callable. The backend is the only place where state is
 * decided — this client never computes permissions, fees or refunds.
 */
export async function call<TReq = Record<string, unknown>, TRes = unknown>(
  name: string,
  payload: TReq,
): Promise<TRes> {
  const callable = httpsCallable<Record<string, unknown>, TRes>(functions, name);
  try {
    const result = await callable(payload as Record<string, unknown>);
    return result.data;
  } catch (err) {
    const e = err as { code?: string; message?: string; details?: { code?: string; message?: string } };
    const code = e.details?.code ?? e.code ?? 'INTERNAL';
    const message = e.details?.message ?? e.message ?? 'Request failed';
    throw new AdminApiError(message, code);
  }
}
