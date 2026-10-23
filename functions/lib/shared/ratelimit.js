"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.consumeRateLimit = consumeRateLimit;
exports.rateLimitKey = rateLimitKey;
const admin_1 = require("./admin");
const errors_1 = require("./errors");
async function consumeRateLimit(key, limit, windowMs) {
    const ref = (0, admin_1.db)().collection('rateLimits').doc(key);
    const now = Date.now();
    let blocked = false;
    let retryAfterSeconds = 0;
    let count = 0;
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const data = snap.data();
        const windowStart = Number(data?.windowStart ?? 0);
        const fresh = data && now - windowStart < windowMs;
        const current = fresh ? Number(data?.count ?? 0) : 0;
        if (fresh && current >= limit) {
            blocked = true;
            retryAfterSeconds = Math.max(1, Math.ceil((windowStart + windowMs - now) / 1000));
            count = current;
            return;
        }
        count = current + 1;
        tx.set(ref, {
            count,
            windowStart: fresh ? windowStart : now,
            expiresAt: new Date((fresh ? windowStart : now) + windowMs + 60_000),
        }, { merge: true });
    });
    if (blocked) {
        throw new errors_1.MiloError('RATE_LIMITED', 'Too many attempts. Please try again later.', {
            retryAfterSeconds,
        });
    }
    return { allowed: true, remaining: Math.max(0, limit - count), retryAfterSeconds: 0 };
}
function rateLimitKey(scope, ...parts) {
    const safe = parts
        .map((p) => String(p).replace(/[^a-zA-Z0-9_.:@-]/g, '_'))
        .join('_');
    return `${scope}_${safe}`.slice(0, 180);
}
//# sourceMappingURL=ratelimit.js.map