import { FieldValue } from 'firebase-admin/firestore';
import { db } from './admin';

export interface AuditEntry {
  actorUid: string;
  actorLevel?: string;
  action: string;
  targetType: string;
  targetId: string;
  before?: unknown;
  after?: unknown;
  reason?: string;
  ip?: string;
  requestId?: string;
}

export async function writeAuditLog(entry: AuditEntry): Promise<string> {
  const ref = db().collection('adminAuditLogs').doc();
  await ref.set({
    actorUid: entry.actorUid,
    actorLevel: entry.actorLevel ?? null,
    action: entry.action,
    targetType: entry.targetType,
    targetId: entry.targetId,
    before: entry.before ?? null,
    after: entry.after ?? null,
    reason: entry.reason ?? null,
    ip: entry.ip ?? null,
    requestId: entry.requestId ?? null,
    at: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

export function maskForAudit(value: unknown): unknown {
  if (!value || typeof value !== 'object') return value ?? null;
  const record = value as Record<string, unknown>;
  const masked: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(record)) {
    if (/pan|account|ifsc|gstin|dob|phone|email|password|secret|token/i.test(key)) {
      masked[key] = '***masked***';
    } else {
      masked[key] = val;
    }
  }
  return masked;
}
