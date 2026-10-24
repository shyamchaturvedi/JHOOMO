"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestCommunityCollab = exports.shareCommunityPost = exports.deleteCommunityComment = exports.addCommunityComment = exports.toggleCommunityLike = exports.createCommunityPost = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../shared/callable");
const auth_1 = require("../shared/auth");
const admin_1 = require("../shared/admin");
const errors_1 = require("../shared/errors");
const ratelimit_1 = require("../shared/ratelimit");
const audit_1 = require("../shared/audit");
const POST_ROLES = ['ORGANIZER', 'INFLUENCER', 'ARTIST', 'SPONSOR', 'ADMIN'];
const ROLE_BADGES = {
    ORGANIZER: 'Host / Organizer',
    INFLUENCER: 'Influencer / Creator',
    ARTIST: 'Artist / Performer',
    SPONSOR: 'Official Partner',
    ADMIN: 'Milo Admin',
    ATTENDEE: 'Attendee',
};
const postIdSchema = zod_1.z.object({
    postId: zod_1.z.string().trim().min(1).max(128),
});
const createPostSchema = zod_1.z.object({
    content: zod_1.z.string().trim().min(1).max(1000),
    eventId: zod_1.z.string().trim().min(1).max(128).optional().nullable(),
    eventTitle: zod_1.z.string().trim().max(120).optional().nullable(),
    mediaUrl: zod_1.z.string().trim().url().max(1024).optional().nullable(),
    isCollabOpen: zod_1.z.boolean().default(false),
    collabType: zod_1.z.string().trim().max(60).optional().nullable(),
});
const commentSchema = postIdSchema.extend({
    text: zod_1.z.string().trim().min(1).max(600),
});
const deleteCommentSchema = postIdSchema.extend({
    commentId: zod_1.z.string().trim().min(1).max(128),
});
const collabSchema = postIdSchema.extend({
    message: zod_1.z.string().trim().max(300).optional().nullable(),
});
function displayNameOf(user, token) {
    const candidates = [user.displayName, user.name, token.name];
    for (const candidate of candidates) {
        const value = typeof candidate === 'string' ? candidate.trim() : '';
        if (value.length > 0)
            return value.slice(0, 80);
    }
    return 'Milo User';
}
function avatarOf(user, token) {
    for (const candidate of [user.avatarUrl, token.picture]) {
        if (typeof candidate === 'string' && candidate.trim().startsWith('https://')) {
            return candidate.trim();
        }
    }
    return null;
}
async function resolveAuthor(ctx) {
    const claims = ctx.token;
    const userSnap = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const user = userSnap.data() ?? {};
    const roles = (user.roles ?? {});
    let role = null;
    if (claims.admin === true) {
        role = 'ADMIN';
    }
    else {
        const explicitRole = String(claims.communityRole ?? '');
        if (claims.communityPoster === true && POST_ROLES.includes(explicitRole)) {
            role = explicitRole;
        }
    }
    if (!role && (claims.organizer === true || roles.organizer === true)) {
        role = 'ORGANIZER';
    }
    if (!role && (claims.promoter === true || roles.promoter === true)) {
        role = 'INFLUENCER';
    }
    if (!role) {
        const organizerSnap = await (0, admin_1.db)().collection('organizers').doc(ctx.uid).get();
        if (organizerSnap.data()?.kycStatus === 'approved')
            role = 'ORGANIZER';
    }
    if (!role) {
        const promoterSnap = await (0, admin_1.db)().collection('promoters').doc(ctx.uid).get();
        if (promoterSnap.data()?.status === 'active')
            role = 'INFLUENCER';
    }
    if (!role)
        return null;
    return {
        uid: ctx.uid,
        name: displayNameOf(user, claims),
        avatarUrl: avatarOf(user, claims),
        role,
        badge: ROLE_BADGES[role],
    };
}
async function resolveCommenter(ctx) {
    const postAuthor = await resolveAuthor(ctx);
    if (postAuthor)
        return postAuthor;
    const claims = ctx.token;
    const userSnap = await (0, admin_1.db)().collection('users').doc(ctx.uid).get();
    const user = userSnap.data() ?? {};
    return {
        uid: ctx.uid,
        name: displayNameOf(user, claims),
        avatarUrl: avatarOf(user, claims),
        role: 'ATTENDEE',
        badge: ROLE_BADGES.ATTENDEE,
    };
}
exports.createCommunityPost = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = createPostSchema.parse(req.data);
    const author = await resolveAuthor(ctx);
    if (!author) {
        (0, errors_1.fail)('FORBIDDEN', 'Only verified organizers, promoters, artists and partners can publish posts.');
    }
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('community_post', ctx.uid), 5, 24 * 60 * 60 * 1000);
    let eventTitle = input.eventTitle?.trim() || null;
    if (input.eventId) {
        const eventSnap = await (0, admin_1.db)().collection('events').doc(input.eventId).get();
        if (!eventSnap.exists)
            (0, errors_1.fail)('NOT_FOUND', 'That event could not be found.');
        const event = eventSnap.data();
        if (author.role === 'ORGANIZER' && event.organizerId !== ctx.uid) {
            (0, errors_1.fail)('FORBIDDEN', 'You can only tag events that you organize.');
        }
        eventTitle = typeof event.title === 'string' ? event.title.slice(0, 120) : eventTitle;
    }
    const isCollabOpen = input.isCollabOpen === true;
    const ref = (0, admin_1.db)().collection('communityPosts').doc();
    await ref.set({
        schemaVersion: 1,
        authorId: author.uid,
        authorName: author.name,
        authorAvatar: author.avatarUrl,
        authorRole: author.role,
        roleBadge: author.badge,
        content: input.content,
        eventId: input.eventId ?? null,
        eventTitle,
        mediaUrl: input.mediaUrl ?? null,
        isCollabOpen,
        collabType: isCollabOpen ? (input.collabType?.trim() || 'Collaboration') : null,
        isOfficialCollab: false,
        likesCount: 0,
        commentsCount: 0,
        shareCount: 0,
        likedBy: [],
        status: 'active',
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, audit_1.writeAuditLog)({
        actorUid: ctx.uid,
        action: 'community.post.create',
        targetType: 'communityPost',
        targetId: ref.id,
        after: { role: author.role },
    });
    return { ok: true, postId: ref.id };
});
exports.toggleCommunityLike = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = postIdSchema.parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('community_like', ctx.uid), 120, 60 * 60 * 1000);
    const ref = (0, admin_1.db)().collection('communityPosts').doc(input.postId);
    let result = { liked: false, likesCount: 0 };
    await (0, admin_1.db)().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists)
            (0, errors_1.fail)('NOT_FOUND', 'This post no longer exists.');
        const data = snap.data();
        if (data.status !== 'active')
            (0, errors_1.fail)('NOT_FOUND', 'This post is not available.');
        const likedBy = Array.isArray(data.likedBy)
            ? data.likedBy.filter((value) => typeof value === 'string')
            : [];
        const liked = likedBy.includes(ctx.uid);
        const next = liked ? likedBy.filter((uid) => uid !== ctx.uid) : [...likedBy, ctx.uid];
        tx.update(ref, {
            likedBy: next,
            likesCount: next.length,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        result = { liked: !liked, likesCount: next.length };
    });
    return result;
});
exports.addCommunityComment = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = commentSchema.parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('community_comment', ctx.uid), 30, 10 * 60 * 1000);
    const author = await resolveCommenter(ctx);
    const postRef = (0, admin_1.db)().collection('communityPosts').doc(input.postId);
    const postSnap = await postRef.get();
    if (!postSnap.exists || postSnap.data()?.status !== 'active') {
        (0, errors_1.fail)('NOT_FOUND', 'This post is not available.');
    }
    const commentRef = postRef.collection('comments').doc();
    const batch = (0, admin_1.db)().batch();
    batch.set(commentRef, {
        schemaVersion: 1,
        postId: input.postId,
        authorId: author.uid,
        authorName: author.name,
        authorAvatar: author.avatarUrl,
        authorRole: author.role,
        roleBadge: author.badge,
        text: input.text,
        status: 'active',
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {
        commentsCount: firestore_1.FieldValue.increment(1),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { ok: true, commentId: commentRef.id };
});
exports.deleteCommunityComment = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = deleteCommentSchema.parse(req.data);
    const postRef = (0, admin_1.db)().collection('communityPosts').doc(input.postId);
    const commentRef = postRef.collection('comments').doc(input.commentId);
    const commentSnap = await commentRef.get();
    if (!commentSnap.exists)
        (0, errors_1.fail)('NOT_FOUND', 'Comment not found.');
    const comment = commentSnap.data();
    const claims = ctx.token;
    const isAdmin = claims.admin === true;
    if (comment.authorId !== ctx.uid && !isAdmin) {
        (0, errors_1.fail)('FORBIDDEN', 'You can only delete your own comment.');
    }
    if (comment.status === 'deleted')
        return { ok: true };
    const batch = (0, admin_1.db)().batch();
    batch.update(commentRef, { status: 'deleted', updatedAt: firestore_1.FieldValue.serverTimestamp() });
    batch.update(postRef, {
        commentsCount: firestore_1.FieldValue.increment(-1),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return { ok: true };
});
exports.shareCommunityPost = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = postIdSchema.parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('community_share', ctx.uid), 60, 60 * 60 * 1000);
    const ref = (0, admin_1.db)().collection('communityPosts').doc(input.postId);
    const snap = await ref.get();
    if (!snap.exists || snap.data()?.status !== 'active') {
        (0, errors_1.fail)('NOT_FOUND', 'This post is not available.');
    }
    await ref.update({
        shareCount: firestore_1.FieldValue.increment(1),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    const base = (process.env.MILO_WEB_BASE_URL || 'https://milo.app').replace(/\/+$/, '');
    return { ok: true, url: `${base}/community/${input.postId}` };
});
exports.requestCommunityCollab = (0, callable_1.miloOnCall)({}, async (req) => {
    const ctx = (0, auth_1.requireAuth)(req);
    const input = collabSchema.parse(req.data);
    await (0, ratelimit_1.consumeRateLimit)((0, ratelimit_1.rateLimitKey)('community_collab', ctx.uid), 20, 60 * 60 * 1000);
    const postSnap = await (0, admin_1.db)().collection('communityPosts').doc(input.postId).get();
    if (!postSnap.exists || postSnap.data()?.status !== 'active') {
        (0, errors_1.fail)('NOT_FOUND', 'This post is not available.');
    }
    const post = postSnap.data();
    if (post.authorId === ctx.uid)
        (0, errors_1.fail)('INVALID_INPUT', 'You cannot request a collaboration on your own post.');
    if (post.isCollabOpen !== true)
        (0, errors_1.fail)('INVALID_INPUT', 'This post is not open for collaborations.');
    const existing = await (0, admin_1.db)()
        .collection('communityCollabRequests')
        .where('postId', '==', input.postId)
        .where('fromUid', '==', ctx.uid)
        .limit(1)
        .get();
    if (!existing.empty)
        (0, errors_1.fail)('CONFLICT', 'You have already requested this collaboration.');
    const ref = (0, admin_1.db)().collection('communityCollabRequests').doc();
    await ref.set({
        schemaVersion: 1,
        postId: input.postId,
        postAuthorId: post.authorId,
        fromUid: ctx.uid,
        message: input.message ?? null,
        status: 'pending',
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true, requestId: ref.id };
});
//# sourceMappingURL=community.js.map