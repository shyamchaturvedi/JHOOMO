"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CONSENT_VERSIONS = exports.CONSENT_TYPES = void 0;
exports.mergeConsents = mergeConsents;
exports.hasConsent = hasConsent;
exports.consentRecord = consentRecord;
exports.requireConsent = requireConsent;
exports.CONSENT_TYPES = ['terms', 'privacy', 'marketing', 'radar', 'location', 'sos'];
exports.CONSENT_VERSIONS = {
    terms: '1.0',
    privacy: '1.0',
    marketing: '1.0',
    radar: '1.0',
    location: '1.0',
    sos: '1.0',
};
function mergeConsents(existing, incoming, at) {
    const byType = new Map();
    for (const record of existing ?? []) {
        if (record && exports.CONSENT_TYPES.includes(record.type))
            byType.set(record.type, record);
    }
    for (const item of incoming) {
        byType.set(item.type, {
            type: item.type,
            version: exports.CONSENT_VERSIONS[item.type],
            granted: item.granted,
            at,
        });
    }
    return exports.CONSENT_TYPES.map((type) => byType.get(type)).filter((r) => Boolean(r));
}
function hasConsent(consents, type) {
    const record = (consents ?? []).find((c) => c.type === type);
    return Boolean(record?.granted);
}
function consentRecord(consents, type) {
    return (consents ?? []).find((c) => c.type === type);
}
function requireConsent(consents, types) {
    for (const type of types) {
        if (!hasConsent(consents, type)) {
            throw new Error(`CONSENT_REQUIRED:${type}`);
        }
    }
}
//# sourceMappingURL=consent.js.map