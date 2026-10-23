"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminListFraudFlags = exports.adminGetConfig = exports.adminSearchUsers = exports.adminListPromoters = exports.adminListSettlements = exports.adminListRefunds = exports.adminListEventQueue = exports.adminListKycQueue = exports.adminListAuditLogs = exports.adminResolveReport = exports.adminListReports = exports.adminSendCampaign = exports.adminUpdateConfig = exports.adminPromoterAction = exports.adminUserAction = exports.adminFraudAction = exports.adminReleaseSettlement = exports.adminDecideRefund = exports.adminReviewEvent = exports.adminReviewKyc = exports.adminDashboardStats = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const audit_1 = require("../shared/audit");
const config_1 = require("../shared/config");
const notify_1 = require("../shared/notify");
const refunds_1 = require("../booking/refunds");
const claims_1 = require("../shared/claims");
function levelOf(req) {
    return String(req.auth?.token?.adminLevel ?? 'L1');
}
exports.adminDashboardStats = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const now = new Date();
    const since = new Date(now.getTime() - 30 * 86_400_000);
    const [bookings, kycQueue, eventQueue, refundQueue, reports, fraud, liveEvents, stats] = await Promise.all([
        (0, admin_1.db)().collection('bookings').where('createdAt', '>=', firestore_1.Timestamp.fromDate(since)).limit(1000).get(),
        (0, admin_1.db)().collection('organizers').where('kycStatus', 'in', ['submitted', 'auto_verified']).get(),
        (0, admin_1.db)().collection('events').where('status', '==', 'pending_review').get(),
        (0, admin_1.db)().collection('refunds').where('status', '==', 'needs_review').get(),
        (0, admin_1.db)().collection('reports').where('status', 'in', ['open', 'in_review']).get(),
        (0, admin_1.db)().collection('fraudFlags').where('status', '==', 'open').get(),
        (0, admin_1.db)().collection('events').where('status', 'in', ['live', 'sold_out']).get(),
        (0, admin_1.db)().collection('adminStats').orderBy('__name__', 'desc').limit(30).get(),
    ]);
    let gmvPaise = 0;
    for (const doc of bookings.docs) {
        gmvPaise += Number(doc.data().pricing?.totalPaise ?? 0);
    }
    const liveNow = liveEvents.docs.filter((doc) => {
        const start = doc.data().schedule?.startAt;
        const end = doc.data().schedule?.endAt;
        const t = now.getTime();
        return ((start ? start.toMillis() <= t : true) && (end ? end.toMillis() >= t : true));
    });
    return {
        gmv30dPaise: gmvPaise,
        bookings30d: bookings.size,
        queues: {
            kyc: kycQueue.size,
            eventReview: eventQueue.size,
            refunds: refundQueue.size,
            reports: reports.size,
            fraud: fraud.size,
        },
        liveEventsNow: liveNow.length,
        daily: stats.docs.map((d) => ({ id: d.id, ...d.data() })),
    };
});
exports.adminReviewKyc = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        organizerUid: zod_1.z.string().min(1).max(64),
        decision: zod_1.z.enum(['approve', 'request_info', 'reject', 'suspend']),
        fields: zod_1.z.array(zod_1.z.string().max(40)).max(20).default([]),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const orgRef = (0, admin_1.db)().collection('organizers').doc(input.organizerUid);
    const snap = await orgRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Organizer not found.');
    const before = snap.data();
    const nextStatus = input.decision === 'approve'
        ? 'approved'
        : input.decision === 'reject'
            ? 'rejected'
            : input.decision === 'suspend'
                ? 'suspended'
                : 'needs_info';
    await orgRef.set({
        kycStatus: nextStatus,
        reviewedBy: ctx.uid,
        reviewedAt: firestore_1.FieldValue.serverTimestamp(),
        reviewFields: input.fields,
        reviewReason: input.reason ?? null,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    if (nextStatus === 'approved') {
        await (0, claims_1.mergeCustomClaims)(input.organizerUid, { organizer: true }).catch(() => undefined);
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `kyc.${input.decision}`,
        targetType: 'organizer',
        targetId: input.organizerUid,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)({ kycStatus: nextStatus }),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    await (0, notify_1.notifyUser)(input.organizerUid, 'kyc_update', 'Verification update', `Your organiser verification is now: ${nextStatus.replace(/_/g, ' ')}.`, { deepLink: '/organizer/kyc', channel: 'bookings' }).catch(() => undefined);
    return { ok: true, kycStatus: nextStatus };
});
exports.adminReviewEvent = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        eventId: zod_1.z.string().min(1).max(64),
        decision: zod_1.z.enum(['approve', 'request_changes', 'reject', 'take_down', 'feature', 'unfeature']),
        reason: zod_1.z.string().trim().max(500).optional(),
        trendScoreBoost: zod_1.z.number().int().min(0).max(1000).optional(),
    })
        .parse(req.data);
    const eventRef = (0, admin_1.db)().collection('events').doc(input.eventId);
    const snap = await eventRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Event not found.');
    const before = snap.data();
    let patch = { updatedAt: firestore_1.FieldValue.serverTimestamp() };
    let nextStatus = String(before.status);
    switch (input.decision) {
        case 'approve':
            nextStatus = 'live';
            patch.status = 'live';
            patch.reviewedBy = ctx.uid;
            patch.reviewedAt = firestore_1.FieldValue.serverTimestamp();
            break;
        case 'request_changes':
            nextStatus = 'changes_requested';
            patch.status = 'changes_requested';
            patch.reviewReason = input.reason ?? null;
            break;
        case 'reject':
            nextStatus = 'rejected';
            patch.status = 'rejected';
            patch.reviewReason = input.reason ?? null;
            break;
        case 'take_down':
            nextStatus = 'taken_down';
            patch.status = 'taken_down';
            patch.reviewReason = input.reason ?? null;
            break;
        case 'feature':
            patch.featured = true;
            if (input.trendScoreBoost !== undefined)
                patch.trendScore = input.trendScoreBoost;
            break;
        case 'unfeature':
            patch.featured = false;
            break;
    }
    await eventRef.set(patch, { merge: true });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `event.${input.decision}`,
        targetType: 'event',
        targetId: input.eventId,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)(patch),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    await (0, notify_1.notifyUser)(String(before.organizerId), 'event_review_update', 'Event review update', `"${before.title}" is now ${nextStatus.replace(/_/g, ' ')}.`, { deepLink: `/organizer/events/${input.eventId}`, channel: 'bookings' }).catch(() => undefined);
    return { ok: true, status: nextStatus };
});
exports.adminDecideRefund = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        refundId: zod_1.z.string().min(1).max(64),
        decision: zod_1.z.enum(['approve', 'partial', 'deny', 'escalate']),
        partialPaise: zod_1.z.number().int().min(0).optional(),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const refundRef = (0, admin_1.db)().collection('refunds').doc(input.refundId);
    const snap = await refundRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Refund not found.');
    const before = snap.data();
    const amountPaise = Number(before.amountPaise ?? 0);
    if (input.decision === 'escalate') {
        await refundRef.set({ status: 'needs_review', escalatedBy: ctx.uid, escalatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    else if (input.decision === 'deny') {
        await refundRef.set({
            status: 'denied',
            deniedBy: ctx.uid,
            deniedAt: firestore_1.FieldValue.serverTimestamp(),
            denialReason: input.reason ?? null,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    else {
        const approvedPaise = input.decision === 'partial'
            ? Math.min(Math.max(input.partialPaise ?? 0, 0), amountPaise)
            : amountPaise;
        if (approvedPaise <= 0)
            (0, errors_1.fail)('INVALID_INPUT', 'Enter a refund amount greater than zero.');
        await refundRef.set({
            status: 'approved',
            amountPaise: approvedPaise,
            approvedPaise,
            approvedBy: ctx.uid,
            approvedAt: firestore_1.FieldValue.serverTimestamp(),
            approvalReason: input.reason ?? null,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        await (0, refunds_1.processRefund)(input.refundId);
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `refund.${input.decision}`,
        targetType: 'refund',
        targetId: input.refundId,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)({ decision: input.decision, amountPaise }),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true, decision: input.decision };
});
exports.adminReleaseSettlement = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L3');
    const input = zod_1.z
        .object({
        settlementId: zod_1.z.string().min(1).max(64),
        action: zod_1.z.enum(['release', 'hold', 'retry']),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const settlementRef = (0, admin_1.db)().collection('settlements').doc(input.settlementId);
    const snap = await settlementRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Settlement not found.');
    const before = snap.data();
    const patch = { updatedAt: firestore_1.FieldValue.serverTimestamp() };
    if (input.action === 'release') {
        patch.status = 'scheduled';
        patch.holdReasons = [];
    }
    else if (input.action === 'hold') {
        patch.status = 'on_hold';
        patch.holdReasons = ['MANUAL_HOLD'];
    }
    else {
        patch.status = 'processing';
        patch.attempts = Number(before.attempts ?? 0) + 1;
    }
    await settlementRef.set(patch, { merge: true });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `settlement.${input.action}`,
        targetType: 'settlement',
        targetId: input.settlementId,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)(patch),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true, status: patch.status };
});
exports.adminFraudAction = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        flagId: zod_1.z.string().min(1).max(64),
        action: zod_1.z.enum(['confirm', 'false_positive', 'block_user', 'void_tickets', 'hold_settlement']),
        subjectId: zod_1.z.string().max(64).optional(),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const flagRef = (0, admin_1.db)().collection('fraudFlags').doc(input.flagId);
    const snap = await flagRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Fraud flag not found.');
    const before = snap.data();
    await flagRef.set({
        status: input.action === 'confirm' ? 'confirmed' : input.action === 'false_positive' ? 'false_positive' : 'open',
        reviewedBy: ctx.uid,
        reviewedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const subjectId = input.subjectId ?? String(before.subjectId ?? '');
    if (input.action === 'block_user' && subjectId) {
        await (0, admin_1.db)()
            .collection('users')
            .doc(subjectId)
            .set({ status: 'suspended', suspendedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
        await (0, claims_1.mergeCustomClaims)(subjectId, { admin: false }).catch(() => undefined);
    }
    if (input.action === 'void_tickets' && subjectId) {
        const tickets = await (0, admin_1.db)().collection('tickets').where('userId', '==', subjectId).limit(200).get();
        const batch = (0, admin_1.db)().batch();
        for (const ticket of tickets.docs)
            batch.update(ticket.ref, { status: 'void', voidedAt: firestore_1.FieldValue.serverTimestamp() });
        await batch.commit();
    }
    if (input.action === 'hold_settlement' && subjectId) {
        const settlements = await (0, admin_1.db)().collection('settlements').where('organizerId', '==', subjectId).limit(50).get();
        const batch = (0, admin_1.db)().batch();
        for (const settlement of settlements.docs) {
            batch.update(settlement.ref, {
                status: 'on_hold',
                holdReasons: ['FRAUD_FLAG'],
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `fraud.${input.action}`,
        targetType: 'fraudFlag',
        targetId: input.flagId,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)({ action: input.action }),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true };
});
exports.adminUserAction = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        uid: zod_1.z.string().min(1).max(64),
        action: zod_1.z.enum(['warn', 'ghost', 'suspend', 'ban', 'restore']),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const userRef = (0, admin_1.db)().collection('users').doc(input.uid);
    const snap = await userRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'User not found.');
    const before = snap.data();
    const patch = { updatedAt: firestore_1.FieldValue.serverTimestamp() };
    switch (input.action) {
        case 'warn':
            patch.warning = { reason: input.reason ?? null, at: firestore_1.FieldValue.serverTimestamp(), by: ctx.uid };
            break;
        case 'ghost':
            patch.privacy = { ...(before.privacy ?? {}), ghostMode: true };
            await (0, admin_1.db)().collectionGroup('radarMembers').where('uid', '==', input.uid).get().then((r) => Promise.all(r.docs.map((d) => d.ref.delete())).catch(() => undefined));
            break;
        case 'suspend':
            patch.status = 'suspended';
            patch.suspendedAt = firestore_1.FieldValue.serverTimestamp();
            break;
        case 'ban':
            patch.status = 'banned';
            patch.bannedAt = firestore_1.FieldValue.serverTimestamp();
            patch.banReason = input.reason ?? null;
            break;
        case 'restore':
            patch.status = 'active';
            patch.suspendedAt = null;
            patch.bannedAt = null;
            patch.privacy = { ...(before.privacy ?? {}), ghostMode: false };
            break;
    }
    await userRef.set(patch, { merge: true });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `user.${input.action}`,
        targetType: 'user',
        targetId: input.uid,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)(patch),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true };
});
exports.adminPromoterAction = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        promoterUid: zod_1.z.string().min(1).max(64),
        action: zod_1.z.enum(['approve', 'suspend', 'adjust_cap']),
        commissionCapPct: zod_1.z.number().min(0).max(50).optional(),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const promoterRef = (0, admin_1.db)().collection('promoters').doc(input.promoterUid);
    const snap = await promoterRef.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Promoter not found.');
    const before = snap.data();
    const patch = { updatedAt: firestore_1.FieldValue.serverTimestamp() };
    if (input.action === 'approve')
        patch.status = 'active';
    if (input.action === 'suspend')
        patch.status = 'suspended';
    if (input.action === 'adjust_cap' && input.commissionCapPct !== undefined) {
        patch.commissionCapPct = input.commissionCapPct;
    }
    await promoterRef.set(patch, { merge: true });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `promoter.${input.action}`,
        targetType: 'promoter',
        targetId: input.promoterUid,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)(patch),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true };
});
exports.adminUpdateConfig = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L3');
    const input = zod_1.z
        .object({
        scope: zod_1.z.enum(['public', 'fees', 'limits']),
        patch: zod_1.z.record(zod_1.z.string(), zod_1.z.unknown()),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('appConfig').doc(input.scope);
    const snap = await ref.get();
    const before = snap.data() ?? {};
    await ref.set({
        ...input.patch,
        version: Number(before.version ?? 0) + 1,
        updatedBy: ctx.uid,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    (0, config_1.invalidateConfigCache)();
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: 'config.update',
        targetType: 'appConfig',
        targetId: input.scope,
        before: (0, audit_1.maskForAudit)(before),
        after: (0, audit_1.maskForAudit)(input.patch),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true, version: Number(before.version ?? 0) + 1 };
});
exports.adminSendCampaign = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        title: zod_1.z.string().trim().min(2).max(80),
        body: zod_1.z.string().trim().min(2).max(300),
        segment: zod_1.z
            .object({
            cityIds: zod_1.z.array(zod_1.z.string().max(64)).max(50).default([]),
            categoryIds: zod_1.z.array(zod_1.z.string().max(64)).max(50).default([]),
            topics: zod_1.z.array(zod_1.z.string().max(64)).max(50).default([]),
        })
            .default({}),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('campaigns').doc();
    await ref.set({
        schemaVersion: 1,
        title: input.title,
        body: input.body,
        segment: input.segment,
        status: 'approved',
        approvedBy: ctx.uid,
        approvedAt: firestore_1.FieldValue.serverTimestamp(),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    for (const topic of input.segment.topics) {
        await (0, notify_1.sendPushToTopic)(topic, {
            title: input.title,
            body: input.body,
            channel: 'marketing',
        });
    }
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: 'campaign.send',
        targetType: 'campaign',
        targetId: ref.id,
        after: (0, audit_1.maskForAudit)(input),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true, campaignId: ref.id };
});
exports.adminListReports = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.enum(['open', 'in_review', 'actioned', 'dismissed']).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('reports').orderBy('createdAt', 'desc').limit(input.limit);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.get();
    return {
        reports: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
    };
});
exports.adminResolveReport = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        reportId: zod_1.z.string().min(1).max(64),
        status: zod_1.z.enum(['in_review', 'actioned', 'dismissed']),
        action: zod_1.z.string().trim().max(300).optional(),
        reason: zod_1.z.string().trim().max(500).optional(),
    })
        .parse(req.data);
    const ref = (0, admin_1.db)().collection('reports').doc(input.reportId);
    const snap = await ref.get();
    if (!snap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Report not found.');
    await ref.set({
        status: input.status,
        action: input.action ?? null,
        assignedTo: ctx.uid,
        resolvedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        actorLevel: levelOf(req),
        action: `report.${input.status}`,
        targetType: 'report',
        targetId: input.reportId,
        after: (0, audit_1.maskForAudit)(input),
        reason: input.reason,
        ip: (0, auth_1.clientIp)(req),
        requestId: (0, callable_1.requestIdOf)(req),
    });
    return { ok: true };
});
exports.adminListAuditLogs = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L2');
    const input = zod_1.z
        .object({
        action: zod_1.z.string().max(60).optional(),
        targetType: zod_1.z.string().max(40).optional(),
        limit: zod_1.z.number().int().min(1).max(200).default(100),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('adminAuditLogs').orderBy('at', 'desc').limit(input.limit);
    if (input.action)
        query = query.where('action', '==', input.action);
    if (input.targetType)
        query = query.where('targetType', '==', input.targetType);
    const snap = await query.get();
    return {
        logs: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
    };
});
// ───────── queue listings ─────────
exports.adminListKycQueue = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.enum(['submitted', 'auto_verified', 'needs_info', 'approved', 'rejected', 'suspended']).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('organizers').orderBy('updatedAt', 'desc').limit(input.limit);
    if (input.status)
        query = query.where('kycStatus', '==', input.status);
    const snap = await query.get();
    return {
        organizers: snap.docs.map((d) => {
            const data = d.data();
            return {
                uid: d.id,
                displayName: data.displayName ?? null,
                email: data.email ?? null,
                kycStatus: data.kycStatus ?? 'none',
                legalName: data.legalName ?? null,
                panMasked: data.panMasked ?? null,
                bankName: data.bankName ?? null,
                ifsc: data.ifsc ?? null,
                nameMatchScore: data.nameMatchScore ?? null,
                trusted: data.trusted === true,
                completedEvents: data.completedEvents ?? 0,
                updatedAt: data.updatedAt ?? null,
                createdAt: data.createdAt ?? null,
            };
        }),
    };
});
exports.adminListEventQueue = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.string().max(30).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('events').orderBy('updatedAt', 'desc').limit(input.limit);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.get();
    return {
        events: snap.docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                title: data.title,
                cityId: data.cityId ?? null,
                categoryId: data.categoryId ?? null,
                status: data.status,
                organizerId: data.organizerId,
                organizerName: data.organizerPublic?.name ?? null,
                startAt: data.schedule?.startAt ?? null,
                endAt: data.schedule?.endAt ?? null,
                capacityTotal: data.capacityTotal ?? 0,
                minPricePaise: data.minPricePaise ?? 0,
                ageLimit: data.ageLimit ?? 18,
                reportCount: data.reportCount ?? 0,
                updatedAt: data.updatedAt ?? null,
            };
        }),
    };
});
exports.adminListRefunds = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.string().max(30).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('refunds').orderBy('createdAt', 'desc').limit(input.limit);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.get();
    return {
        refunds: snap.docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                bookingId: data.bookingId ?? null,
                eventId: data.eventId ?? null,
                userId: data.userId ?? null,
                organizerId: data.organizerId ?? null,
                status: data.status,
                amountPaise: data.amountPaise ?? 0,
                feePaise: data.feePaise ?? 0,
                reason: data.reason ?? null,
                createdAt: data.createdAt ?? null,
            };
        }),
    };
});
exports.adminListSettlements = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.string().max(30).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('settlements').orderBy('scheduledFor', 'desc').limit(input.limit);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.get();
    return {
        settlements: snap.docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                eventId: data.eventId,
                organizerId: data.organizerId,
                status: data.status,
                holdReasons: data.holdReasons ?? [],
                grossPaise: data.grossPaise ?? 0,
                refundsPaise: data.refundsPaise ?? 0,
                platformFeePaise: data.platformFeePaise ?? 0,
                gstOnFeePaise: data.gstOnFeePaise ?? 0,
                promoterCommissionPaise: data.promoterCommissionPaise ?? 0,
                netPaise: data.netPaise ?? 0,
                bankMasked: data.bankMasked ?? null,
                utr: data.utr ?? null,
                scheduledFor: data.scheduledFor ?? null,
                paidAt: data.paidAt ?? null,
                approvals: data.approvals ?? [],
            };
        }),
    };
});
exports.adminListPromoters = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({ limit: zod_1.z.number().int().min(1).max(100).default(50) })
        .parse(req.data ?? {});
    const snap = await (0, admin_1.db)()
        .collection('promoters')
        .orderBy('createdAt', 'desc')
        .limit(input.limit)
        .get();
    return {
        promoters: snap.docs.map((d) => {
            const data = d.data();
            return {
                uid: d.id,
                code: data.code ?? null,
                displayName: data.displayName ?? null,
                status: data.status ?? 'pending',
                panMasked: data.panMasked ?? null,
                commissionCapPct: data.commissionCapPct ?? null,
                pendingPaise: data.pendingPaise ?? 0,
                approvedPaise: data.approvedPaise ?? 0,
                paidPaise: data.paidPaise ?? 0,
                createdAt: data.createdAt ?? null,
            };
        }),
    };
});
exports.adminSearchUsers = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({ query: zod_1.z.string().trim().min(2).max(64) })
        .parse(req.data);
    const direct = await (0, admin_1.db)().collection('users').doc(input.query).get();
    const phone = await (0, admin_1.db)().collection('users').where('phone', '==', input.query).limit(1).get();
    const email = await (0, admin_1.db)().collection('users').where('email', '==', input.query).limit(1).get();
    const found = new Map();
    if (direct.exists)
        found.set(direct.id, direct.data() ?? {});
    for (const doc of [...phone.docs, ...email.docs])
        found.set(doc.id, doc.data() ?? {});
    const sos = await (0, admin_1.db)()
        .collection('sosAlerts')
        .where('userId', 'in', found.size ? [...found.keys()] : ['__none__'])
        .limit(20)
        .get();
    return {
        users: [...found.entries()].map(([uid, data]) => ({
            uid,
            displayName: data.displayName ?? null,
            emailMasked: data.email ? String(data.email).replace(/^(.{2}).*(@.*)$/, '$1***$2') : null,
            phoneMasked: data.phone ? `+91 XXXXX X${String(data.phone).replace(/\D/g, '').slice(-3)}` : null,
            status: data.status ?? 'active',
            roles: data.roles ?? [],
            faceVerified: data.faceVerified === true,
            kycStatus: data.kycStatus ?? null,
            createdAt: data.createdAt ?? null,
        })),
        sosAlerts: sos.docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                status: data.status,
                startedAt: data.startedAt ?? null,
                resolvedAt: data.resolvedAt ?? null,
                eventId: data.eventId ?? null,
            };
        }),
    };
});
exports.adminGetConfig = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const [publicSnap, feesSnap, limitsSnap] = await Promise.all([
        (0, admin_1.db)().collection('appConfig').doc('public').get(),
        (0, admin_1.db)().collection('appConfig').doc('fees').get(),
        (0, admin_1.db)().collection('appConfig').doc('limits').get(),
    ]);
    return {
        public: publicSnap.data() ?? {},
        fees: feesSnap.data() ?? {},
        limits: limitsSnap.data() ?? {},
    };
});
exports.adminListFraudFlags = (0, callable_1.miloOnCall)({}, async (req) => {
    (0, auth_1.requireAdmin)(req, 'L1');
    const input = zod_1.z
        .object({
        status: zod_1.z.enum(['open', 'confirmed', 'false_positive']).optional(),
        limit: zod_1.z.number().int().min(1).max(100).default(50),
    })
        .parse(req.data ?? {});
    let query = (0, admin_1.db)().collection('fraudFlags').orderBy('createdAt', 'desc').limit(input.limit);
    if (input.status)
        query = query.where('status', '==', input.status);
    const snap = await query.get();
    return {
        flags: snap.docs.map((d) => {
            const data = d.data();
            return {
                id: d.id,
                type: data.type,
                severity: data.severity,
                subjectType: data.subjectType,
                subjectId: data.subjectId,
                status: data.status,
                details: data.details ?? {},
                createdAt: data.createdAt ?? null,
            };
        }),
    };
});
//# sourceMappingURL=console.js.map