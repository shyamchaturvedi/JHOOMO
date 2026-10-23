"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.maskDisplayName = maskDisplayName;
/**
 * Privacy helpers for showing a member's identity before a mutual match.
 *
 * PRD rule: a member is only ever shown as "First name + last initial".
 * Full names are revealed only inside a DM that both sides accepted.
 */
function maskDisplayName(name) {
    const raw = String(name ?? '').trim();
    if (!raw)
        return 'Milo User';
    const parts = raw.split(/\s+/).filter(Boolean);
    const first = parts[0] ?? 'Milo';
    if (parts.length === 1)
        return first;
    const lastInitial = parts[parts.length - 1].charAt(0).toUpperCase();
    return `${first} ${lastInitial}.`;
}
//# sourceMappingURL=mask.js.map