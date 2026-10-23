"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_LIMITS_CONFIG = exports.DEFAULT_FEES_CONFIG = exports.DEFAULT_PUBLIC_CONFIG = void 0;
exports.invalidateConfigCache = invalidateConfigCache;
exports.getPublicConfig = getPublicConfig;
exports.getFeesConfig = getFeesConfig;
exports.getLimitsConfig = getLimitsConfig;
exports.requireFeature = requireFeature;
const admin_1 = require("./admin");
exports.DEFAULT_PUBLIC_CONFIG = {
    minAppVersion: { android: '4.0.0', ios: '4.0.0' },
    maintenance: { on: false, message: '', allowGate: false },
    featureFlags: { bookings: true, radar: true, groupChat: true, promoter: true, sos: true },
    otpResendSeconds: 25,
    holdMinutes: 10,
    displayFeePct: 5,
    displayGstPct: 18,
};
exports.DEFAULT_FEES_CONFIG = {
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
exports.DEFAULT_LIMITS_CONFIG = {
    hellosPerDay: 20,
    beaconsPerUser: 3,
    staffPerEvent: 20,
    maxEmergencyContacts: 3,
    fourEyesThresholdPaise: 10_000_000,
    trustedOrganizerMinEvents: 3,
};
const CACHE_TTL_MS = 60_000;
let publicCache = null;
let feesCache = null;
let limitsCache = null;
function invalidateConfigCache() {
    publicCache = null;
    feesCache = null;
    limitsCache = null;
}
async function getPublicConfig() {
    if (publicCache && Date.now() - publicCache.at < CACHE_TTL_MS)
        return publicCache.value;
    const snap = await (0, admin_1.db)().collection('appConfig').doc('public').get();
    const value = snap.exists
        ? { ...exports.DEFAULT_PUBLIC_CONFIG, ...snap.data() }
        : exports.DEFAULT_PUBLIC_CONFIG;
    publicCache = { at: Date.now(), value };
    return value;
}
async function getFeesConfig() {
    if (feesCache && Date.now() - feesCache.at < CACHE_TTL_MS)
        return feesCache.value;
    const snap = await (0, admin_1.db)().collection('appConfig').doc('fees').get();
    const value = snap.exists
        ? { ...exports.DEFAULT_FEES_CONFIG, ...snap.data() }
        : exports.DEFAULT_FEES_CONFIG;
    feesCache = { at: Date.now(), value };
    return value;
}
async function getLimitsConfig() {
    if (limitsCache && Date.now() - limitsCache.at < CACHE_TTL_MS)
        return limitsCache.value;
    const snap = await (0, admin_1.db)().collection('appConfig').doc('limits').get();
    const value = snap.exists
        ? { ...exports.DEFAULT_LIMITS_CONFIG, ...snap.data() }
        : exports.DEFAULT_LIMITS_CONFIG;
    limitsCache = { at: Date.now(), value };
    return value;
}
async function requireFeature(flag) {
    const config = await getPublicConfig();
    return config.featureFlags[flag] !== false;
}
//# sourceMappingURL=config.js.map