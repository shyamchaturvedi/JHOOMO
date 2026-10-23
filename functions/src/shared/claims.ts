import { authAdmin } from './admin';

export interface MiloClaims {
  organizer?: boolean;
  promoter?: boolean;
  admin?: boolean;
  adminLevel?: 'L1' | 'L2' | 'L3';
  role?: 'gate_staff';
  eventId?: string;
  gate?: string;
  staffId?: string;
}

/**
 * Custom claims are set only by Cloud Functions (§2.1). Claims are merged, never
 * replaced, so adding one role never strips another.
 */
export async function mergeCustomClaims(uid: string, patch: MiloClaims): Promise<void> {
  const user = await authAdmin().getUser(uid);
  const existing = (user.customClaims ?? {}) as MiloClaims;
  const next: MiloClaims = { ...existing };
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) delete (next as Record<string, unknown>)[key];
    else (next as Record<string, unknown>)[key] = value;
  }
  await authAdmin().setCustomUserClaims(uid, next);
}

export async function readCustomClaims(uid: string): Promise<MiloClaims> {
  const user = await authAdmin().getUser(uid);
  return (user.customClaims ?? {}) as MiloClaims;
}
