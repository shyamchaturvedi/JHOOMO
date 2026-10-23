"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
exports.requireRole = requireRole;
exports.requireAdmin = requireAdmin;
exports.requireStaff = requireStaff;
exports.loadOrganizer = loadOrganizer;
exports.requireOrganizer = requireOrganizer;
exports.requireApprovedOrganizer = requireApprovedOrganizer;
exports.clientIp = clientIp;
const admin_1 = require("./admin");
const errors_1 = require("./errors");
const LEVEL_RANK = { L1: 1, L2: 2, L3: 3 };
function requireAuth(req) {
    if (!req.auth)
        (0, errors_1.fail)('UNAUTHENTICATED', 'Please sign in to continue.');
    return { uid: req.auth.uid, token: req.auth.token, email: req.auth.token.email };
}
function requireRole(req, role) {
    const ctx = requireAuth(req);
    const claims = ctx.token;
    if (role === 'admin' && claims.admin !== true)
        (0, errors_1.fail)('FORBIDDEN', 'Admin access required.');
    if (role === 'organizer' && claims.organizer !== true) {
        (0, errors_1.fail)('FORBIDDEN', 'Organizer verification is required for this action.');
    }
    if (role === 'promoter' && claims.promoter !== true) {
        (0, errors_1.fail)('FORBIDDEN', 'Promoter programme access required.');
    }
    return ctx;
}
function requireAdmin(req, minLevel = 'L1') {
    const ctx = requireAuth(req);
    const claims = ctx.token;
    if (claims.admin !== true)
        (0, errors_1.fail)('FORBIDDEN', 'Admin access required.');
    const level = claims.adminLevel ?? 'L1';
    if (LEVEL_RANK[level] < LEVEL_RANK[minLevel]) {
        (0, errors_1.fail)('FORBIDDEN', `This action requires admin level ${minLevel} or above.`);
    }
    return ctx;
}
function requireStaff(req) {
    if (!req.auth)
        (0, errors_1.fail)('UNAUTHENTICATED', 'Please sign in to continue.');
    const token = req.auth.token;
    if (token.role !== 'gate_staff')
        (0, errors_1.fail)('FORBIDDEN', 'Gate staff session required.');
    const eventId = typeof token.eventId === 'string' ? token.eventId : '';
    const gate = typeof token.gate === 'string' ? token.gate : '';
    const staffId = typeof token.staffId === 'string' ? token.staffId : '';
    if (!eventId || !gate || !staffId)
        (0, errors_1.fail)('FORBIDDEN', 'Invalid gate staff claims.');
    return { uid: req.auth.uid, eventId, gate, staffId, token: req.auth.token };
}
async function loadOrganizer(uid) {
    const snap = await (0, admin_1.db)().collection('organizers').doc(uid).get();
    if (!snap.exists)
        return null;
    const data = snap.data();
    return {
        uid,
        kycStatus: (data.kycStatus ?? 'none'),
        completedEvents: Number(data.completedEvents ?? 0),
        trusted: data.trusted === true,
    };
}
async function requireOrganizer(req) {
    const ctx = requireRole(req, 'organizer');
    const organizer = await loadOrganizer(ctx.uid);
    if (!organizer)
        (0, errors_1.fail)('KYC_INCOMPLETE', 'Complete organiser onboarding first.');
    if (organizer.kycStatus === 'suspended' || organizer.kycStatus === 'rejected') {
        (0, errors_1.fail)('FORBIDDEN', 'Your organiser account is not active.');
    }
    return ctx;
}
async function requireApprovedOrganizer(req) {
    const ctx = await requireOrganizer(req);
    const organizer = await loadOrganizer(ctx.uid);
    if (!organizer || organizer.kycStatus !== 'approved') {
        (0, errors_1.fail)('PAYOUTS_LOCKED', 'Payouts unlock after Milo verification.');
    }
    return ctx;
}
function clientIp(req) {
    const raw = req.rawRequest?.headers?.['x-forwarded-for'];
    const value = Array.isArray(raw) ? raw[0] : raw;
    if (typeof value === 'string' && value.length > 0)
        return value.split(',')[0].trim();
    return req.rawRequest?.ip ?? 'unknown';
}
//# sourceMappingURL=auth.js.map