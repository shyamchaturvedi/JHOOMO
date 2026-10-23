import { Timestamp } from 'firebase-admin/firestore';
import { db } from './admin';
import { FeeBearer } from './pricing';

export interface PublicConfig {
  minAppVersion: { android: string; ios: string };
  maintenance: { on: boolean; message: string; etaAt?: Timestamp; allowGate: boolean };
  featureFlags: {
    bookings: boolean;
    radar: boolean;
    groupChat: boolean;
    promoter: boolean;
    sos: boolean;
  };
  otpResendSeconds: number;
  holdMinutes: number;
  displayFeePct: number;
  displayGstPct: number;
}

export interface FeesConfig {
  platformFeePct: number;
  gstPct: number;
  feeBearer: FeeBearer;
  refundPlatformFee: boolean;
  freeTicketFeePaise: number;
  minPayoutPaise: number;
  version: number;
  updatedBy: string;
  tdsPct: number;
  tdsThresholdPaise: number;
  tdsRateWithoutPanPct: number;
}

export interface LimitsConfig {
  hellosPerDay: number;
  beaconsPerUser: number;
  staffPerEvent: number;
  maxEmergencyContacts: number;
  fourEyesThresholdPaise: number;
  trustedOrganizerMinEvents: number;
}

export const DEFAULT_PUBLIC_CONFIG: PublicConfig = {
  minAppVersion: { android: '4.0.0', ios: '4.0.0' },
  maintenance: { on: false, message: '', allowGate: false },
  featureFlags: { bookings: true, radar: true, groupChat: true, promoter: true, sos: true },
  otpResendSeconds: 25,
  holdMinutes: 10,
  displayFeePct: 5,
  displayGstPct: 18,
};

export const DEFAULT_FEES_CONFIG: FeesConfig = {
  platformFeePct: 5,
  gstPct: 18,
  feeBearer: 'organizer',
  refundPlatformFee: false,
  freeTicketFeePaise: 0,
  minPayoutPaise: 50_000,
  version: 1,
  updatedBy: 'system-default',
  tdsPct: 2,
  tdsThresholdPaise: 2_000_000,
  tdsRateWithoutPanPct: 20,
};

export const DEFAULT_LIMITS_CONFIG: LimitsConfig = {
  hellosPerDay: 20,
  beaconsPerUser: 3,
  staffPerEvent: 20,
  maxEmergencyContacts: 3,
  fourEyesThresholdPaise: 10_000_000,
  trustedOrganizerMinEvents: 3,
};

const CACHE_TTL_MS = 60_000;
let publicCache: { at: number; value: PublicConfig } | null = null;
let feesCache: { at: number; value: FeesConfig } | null = null;
let limitsCache: { at: number; value: LimitsConfig } | null = null;

export function invalidateConfigCache(): void {
  publicCache = null;
  feesCache = null;
  limitsCache = null;
}

export async function getPublicConfig(): Promise<PublicConfig> {
  if (publicCache && Date.now() - publicCache.at < CACHE_TTL_MS) return publicCache.value;
  const snap = await db().collection('appConfig').doc('public').get();
  const value: PublicConfig = snap.exists
    ? { ...DEFAULT_PUBLIC_CONFIG, ...snap.data() } as PublicConfig
    : DEFAULT_PUBLIC_CONFIG;
  publicCache = { at: Date.now(), value };
  return value;
}

export async function getFeesConfig(): Promise<FeesConfig> {
  if (feesCache && Date.now() - feesCache.at < CACHE_TTL_MS) return feesCache.value;
  const snap = await db().collection('appConfig').doc('fees').get();
  const value: FeesConfig = snap.exists
    ? { ...DEFAULT_FEES_CONFIG, ...snap.data() } as FeesConfig
    : DEFAULT_FEES_CONFIG;
  feesCache = { at: Date.now(), value };
  return value;
}

export async function getLimitsConfig(): Promise<LimitsConfig> {
  if (limitsCache && Date.now() - limitsCache.at < CACHE_TTL_MS) return limitsCache.value;
  const snap = await db().collection('appConfig').doc('limits').get();
  const value: LimitsConfig = snap.exists
    ? { ...DEFAULT_LIMITS_CONFIG, ...snap.data() } as LimitsConfig
    : DEFAULT_LIMITS_CONFIG;
  limitsCache = { at: Date.now(), value };
  return value;
}

export async function requireFeature(flag: keyof PublicConfig['featureFlags']): Promise<boolean> {
  const config = await getPublicConfig();
  return config.featureFlags[flag] !== false;
}
