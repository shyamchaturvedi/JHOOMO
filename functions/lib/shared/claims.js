"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mergeCustomClaims = mergeCustomClaims;
exports.readCustomClaims = readCustomClaims;
const admin_1 = require("./admin");
/**
 * Custom claims are set only by Cloud Functions (§2.1). Claims are merged, never
 * replaced, so adding one role never strips another.
 */
async function mergeCustomClaims(uid, patch) {
    const user = await (0, admin_1.authAdmin)().getUser(uid);
    const existing = (user.customClaims ?? {});
    const next = { ...existing };
    for (const [key, value] of Object.entries(patch)) {
        if (value === undefined)
            delete next[key];
        else
            next[key] = value;
    }
    await (0, admin_1.authAdmin)().setCustomUserClaims(uid, next);
}
async function readCustomClaims(uid) {
    const user = await (0, admin_1.authAdmin)().getUser(uid);
    return (user.customClaims ?? {});
}
//# sourceMappingURL=claims.js.map