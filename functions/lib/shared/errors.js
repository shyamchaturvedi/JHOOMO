"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MiloError = void 0;
exports.fail = fail;
exports.toHttpsError = toHttpsError;
exports.isMiloError = isMiloError;
const https_1 = require("firebase-functions/https");
const HTTP_STATUS = {
    UNAUTHENTICATED: 'unauthenticated',
    FORBIDDEN: 'permission-denied',
    INVALID_INPUT: 'invalid-argument',
    NOT_FOUND: 'not-found',
    CONFLICT: 'already-exists',
    ALREADY_REGISTERED: 'already-exists',
    RATE_LIMITED: 'resource-exhausted',
    CONSENT_REQUIRED: 'failed-precondition',
    AGE_RESTRICTED: 'failed-precondition',
    SOLD_OUT: 'failed-precondition',
    LIMIT_EXCEEDED: 'failed-precondition',
    EVENT_NOT_ON_SALE: 'failed-precondition',
    EVENT_ENDED: 'failed-precondition',
    HOLD_EXPIRED: 'failed-precondition',
    PAYMENT_FAILED: 'failed-precondition',
    PAYOUTS_LOCKED: 'failed-precondition',
    KYC_INCOMPLETE: 'failed-precondition',
    INVALID_STAFF_CREDENTIALS: 'unauthenticated',
    TICKET_INVALID: 'failed-precondition',
    TICKET_WRONG_EVENT: 'failed-precondition',
    TICKET_REFUNDED_OR_VOID: 'failed-precondition',
    TICKET_CHECKED_IN: 'failed-precondition',
    NOT_VALID_TODAY: 'failed-precondition',
    QR_EXPIRED: 'failed-precondition',
    ALREADY_CHECKED_IN: 'already-exists',
    FEATURE_DISABLED: 'failed-precondition',
    INTERNAL: 'internal',
};
class MiloError extends Error {
    code;
    details;
    constructor(code, message, details = {}) {
        super(message);
        this.name = 'MiloError';
        this.code = code;
        this.details = details;
    }
}
exports.MiloError = MiloError;
function fail(code, message, details = {}) {
    throw new https_1.HttpsError(HTTP_STATUS[code], code, { code, message, ...details });
}
function toHttpsError(err) {
    if (err instanceof https_1.HttpsError)
        return err;
    if (err instanceof MiloError) {
        return new https_1.HttpsError(HTTP_STATUS[err.code], err.code, { code: err.code, message: err.message, ...err.details });
    }
    return new https_1.HttpsError('internal', 'INTERNAL', {
        code: 'INTERNAL',
        message: 'Something went wrong. Please try again.',
    });
}
function isMiloError(err) {
    return err instanceof MiloError;
}
//# sourceMappingURL=errors.js.map