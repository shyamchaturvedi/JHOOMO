import { CallableRequest } from 'firebase-functions/https';
import { DecodedIdToken } from 'firebase-admin/auth';
import { db } from './admin';
import { fail } from './errors';

export interface CallerContext {
  uid: string;
  token: DecodedIdToken;
  email: string | undefined;
}

export interface StaffContext {
  uid: string;
  eventId: string;
  gate: string;
  staffId: string;
  token: DecodedIdToken;
}

export type AdminLevel = 'L1' | 'L2' | 'L3';

const LEVEL_RANK: Record<AdminLevel, number> = { L1: 1, L2: 2, L3: 3 };

export function requireAuth(req: CallableRequest<unknown>): CallerContext {
  if (!req.auth) fail('UNAUTHENTICATED', 'Please sign in to continue.');
  return { uid: req.auth.uid, token: req.auth.token, email: req.auth.token.email };
}

export function requireRole(req: CallableRequest<unknown>, role: 'customer' | 'organizer' | 'promoter' | 'admin'): CallerContext {
  const ctx = requireAuth(req);
  const claims = ctx.token as Record<string, unknown>;
  if (role === 'admin' && claims.admin !== true) fail('FORBIDDEN', 'Admin access required.');
  if (role === 'organizer' && claims.organizer !== true) {
    fail('FORBIDDEN', 'Organizer verification is required for this action.');
  }
  if (role === 'promoter' && claims.promoter !== true) {
    fail('FORBIDDEN', 'Promoter programme access required.');
  }
  return ctx;
}

export function requireAdmin(req: CallableRequest<unknown>, minLevel: AdminLevel = 'L1'): CallerContext {
  const ctx = requireAuth(req);
  const claims = ctx.token as Record<string, unknown>;
  if (claims.admin !== true) fail('FORBIDDEN', 'Admin access required.');
  const level = (claims.adminLevel as AdminLevel | undefined) ?? 'L1';
  if (LEVEL_RANK[level] < LEVEL_RANK[minLevel]) {
    fail('FORBIDDEN', `This action requires admin level ${minLevel} or above.`);
  }
  return ctx;
}

export function requireStaff(req: CallableRequest<unknown>): StaffContext {
  if (!req.auth) fail('UNAUTHENTICATED', 'Please sign in to continue.');
  const token = req.auth.token as Record<string, unknown>;
  if (token.role !== 'gate_staff') fail('FORBIDDEN', 'Gate staff session required.');
  const eventId = typeof token.eventId === 'string' ? token.eventId : '';
  const gate = typeof token.gate === 'string' ? token.gate : '';
  const staffId = typeof token.staffId === 'string' ? token.staffId : '';
  if (!eventId || !gate || !staffId) fail('FORBIDDEN', 'Invalid gate staff claims.');
  return { uid: req.auth.uid, eventId, gate, staffId, token: req.auth.token };
}

export type KycStatus =
  | 'none'
  | 'draft'
  | 'submitted'
  | 'auto_verified'
  | 'approved'
  | 'needs_info'
  | 'rejected'
  | 'suspended';

export interface OrganizerRecord {
  uid: string;
  kycStatus: KycStatus;
  completedEvents: number;
  trusted: boolean;
}

export async function loadOrganizer(uid: string): Promise<OrganizerRecord | null> {
  const snap = await db().collection('organizers').doc(uid).get();
  if (!snap.exists) return null;
  const data = snap.data()!;
  return {
    uid,
    kycStatus: (data.kycStatus ?? 'none') as KycStatus,
    completedEvents: Number(data.completedEvents ?? 0),
    trusted: data.trusted === true,
  };
}

export async function requireOrganizer(req: CallableRequest<unknown>): Promise<CallerContext> {
  const ctx = requireRole(req, 'organizer');
  const organizer = await loadOrganizer(ctx.uid);
  if (!organizer) fail('KYC_INCOMPLETE', 'Complete organiser onboarding first.');
  if (organizer.kycStatus === 'suspended' || organizer.kycStatus === 'rejected') {
    fail('FORBIDDEN', 'Your organiser account is not active.');
  }
  return ctx;
}

export async function requireApprovedOrganizer(req: CallableRequest<unknown>): Promise<CallerContext> {
  const ctx = await requireOrganizer(req);
  const organizer = await loadOrganizer(ctx.uid);
  if (!organizer || organizer.kycStatus !== 'approved') {
    fail('PAYOUTS_LOCKED', 'Payouts unlock after Milo verification.');
  }
  return ctx;
}

export function clientIp(req: CallableRequest<unknown>): string {
  const raw = req.rawRequest?.headers?.['x-forwarded-for'];
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (typeof value === 'string' && value.length > 0) return value.split(',')[0]!.trim();
  return req.rawRequest?.ip ?? 'unknown';
}
