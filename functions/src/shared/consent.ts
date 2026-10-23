import { Timestamp } from 'firebase-admin/firestore';

export const CONSENT_TYPES = ['terms', 'privacy', 'marketing', 'radar', 'location', 'sos'] as const;
export type ConsentType = (typeof CONSENT_TYPES)[number];

export const CONSENT_VERSIONS: Record<ConsentType, string> = {
  terms: '1.0',
  privacy: '1.0',
  marketing: '1.0',
  radar: '1.0',
  location: '1.0',
  sos: '1.0',
};

export interface ConsentRecord {
  type: ConsentType;
  version: string;
  granted: boolean;
  at: Timestamp;
}

export function mergeConsents(
  existing: ConsentRecord[] | undefined,
  incoming: Array<{ type: ConsentType; granted: boolean }>,
  at: Timestamp,
): ConsentRecord[] {
  const byType = new Map<ConsentType, ConsentRecord>();
  for (const record of existing ?? []) {
    if (record && CONSENT_TYPES.includes(record.type)) byType.set(record.type, record);
  }
  for (const item of incoming) {
    byType.set(item.type, {
      type: item.type,
      version: CONSENT_VERSIONS[item.type],
      granted: item.granted,
      at,
    });
  }
  return CONSENT_TYPES.map((type) => byType.get(type)).filter((r): r is ConsentRecord => Boolean(r));
}

export function hasConsent(
  consents: ConsentRecord[] | undefined,
  type: ConsentType,
): boolean {
  const record = (consents ?? []).find((c) => c.type === type);
  return Boolean(record?.granted);
}

export function consentRecord(
  consents: ConsentRecord[] | undefined,
  type: ConsentType,
): ConsentRecord | undefined {
  return (consents ?? []).find((c) => c.type === type);
}

export function requireConsent(
  consents: ConsentRecord[] | undefined,
  types: ConsentType[],
): void {
  for (const type of types) {
    if (!hasConsent(consents, type)) {
      throw new Error(`CONSENT_REQUIRED:${type}`);
    }
  }
}
