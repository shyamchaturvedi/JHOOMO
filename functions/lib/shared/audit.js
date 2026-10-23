"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.writeAuditLog = writeAuditLog;
exports.maskForAudit = maskForAudit;
const firestore_1 = require("firebase-admin/firestore");
const admin_1 = require("./admin");
async function writeAuditLog(entry) {
    const ref = (0, admin_1.db)().collection('adminAuditLogs').doc();
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
        at: firestore_1.FieldValue.serverTimestamp(),
    });
    return ref.id;
}
function maskForAudit(value) {
    if (!value || typeof value !== 'object')
        return value ?? null;
    const record = value;
    const masked = {};
    for (const [key, val] of Object.entries(record)) {
        if (/pan|account|ifsc|gstin|dob|phone|email|password|secret|token/i.test(key)) {
            masked[key] = '***masked***';
        }
        else {
            masked[key] = val;
        }
    }
    return masked;
}
//# sourceMappingURL=audit.js.map