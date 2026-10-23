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