"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestIdOf = requestIdOf;
exports.miloOnCall = miloOnCall;
exports.unauthenticated = unauthenticated;
const https_1 = require("firebase-functions/https");
const https_2 = require("firebase-functions/https");
const firebase_functions_1 = require("firebase-functions");
const node_crypto_1 = require("node:crypto");
const errors_1 = require("./errors");
const envelope_1 = require("./envelope");
const vendors_1 = require("./vendors");
const razorpay_1 = require("./razorpay");
/**
 * Secret params must be bound to the function declaration, otherwise calling
 * `.value()` at runtime throws. Attach every integration secret the callables
 * may touch so enabling a provider never silently disables the feature.
 */
const MILO_SECRETS = [
    envelope_1.MILO_KYC_DATA_KEY,
    vendors_1.KYC_VENDOR_API_KEY,
    vendors_1.KYC_VENDOR_BASE_URL,
    vendors_1.SMS_PROVIDER_API_KEY,
    vendors_1.SMS_DLT_TEMPLATE_ID,
    vendors_1.SMS_DLT_SENDER_ID,
    razorpay_1.RAZORPAY_KEY_ID,
    razorpay_1.RAZORPAY_KEY_SECRET,
];
function appCheckEnforced() {
    return process.env.MILO_APPCHECK_ENFORCE !== 'false';
}
function requestIdOf(req) {
    const header = req.rawRequest?.headers?.['x-request-id'];
    const value = Array.isArray(header) ? header[0] : header;
    return typeof value === 'string' && value.length > 0 && value.length <= 64 ? value : (0, node_crypto_1.randomUUID)();
}
function miloOnCall(opts, handler) {
    const { enforceAppCheck, ...rest } = opts;
    return (0, https_2.onCall)({
        region: 'asia-south1',
        enforceAppCheck: enforceAppCheck ?? appCheckEnforced(),
        ...rest,
        secrets: [...(rest.secrets ?? []), ...MILO_SECRETS],
    }, async (req) => {
        const requestId = requestIdOf(req);
        const started = Date.now();
        try {
            const result = await handler(req);
            firebase_functions_1.logger.info('milo.callable.ok', {
                requestId,
                name: req.functionName ?? 'unknown',
                uid: req.auth?.uid ?? null,
                durationMs: Date.now() - started,
            });
            return result;
        }
        catch (err) {
            const httpError = (0, errors_1.toHttpsError)(err);
            firebase_functions_1.logger.error('milo.callable.err', {
                requestId,
                name: req.functionName ?? 'unknown',
                uid: req.auth?.uid ?? null,
                durationMs: Date.now() - started,
                code: httpError.message,
                httpStatus: httpError.code,
                stack: err instanceof Error ? err.stack : undefined,
            });
            throw httpError;
        }
    });
}
function unauthenticated() {
    return new https_1.HttpsError('unauthenticated', 'UNAUTHENTICATED', {
        code: 'UNAUTHENTICATED',
        message: 'Please sign in to continue.',
    });
}
//# sourceMappingURL=callable.js.map