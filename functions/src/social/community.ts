import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { miloOnCall } from '../shared/callable';
import { requireAuth, type CallerContext } from '../shared/auth';
import { db } from '../shared/admin';
import { fail } from '../shared/errors';
import { consumeRateLimit, rateLimitKey } from '../shared/ratelimit';
import { writeAuditLog } from '../shared/audit';

type CommunityRole = 'ORGANIZER' | 'INFLUENCER' | 'ARTIST' | 'SPONSOR' | 'ADMIN' | 'ATTENDEE';

const POST_ROLES: CommunityRole[] = ['ORGANIZER', 'INFLUENCER', 'ARTIST', 'SPONSOR', 'ADMIN'];

const ROLE_BADGES: Record<CommunityRole, string> = {
  ORGANIZER: 'Host / Organizer',
  INFLUENCER: 'Influencer / Creator',
  ARTIST: 'Artist / Performer',
  SPONSOR: 'Official Partner',
  ADMIN: 'Milo Admin',
  ATTENDEE: 'Attendee',
};

interface CommunityAuthor {
  uid: string;
  name: string;
  avatarUrl: string | null;
  role: CommunityRole;
  badge: string;
}

const postIdSchema = z.object({
  postId: z.string().trim().min(1).max(128),
});

const createPostSchema = z.object({
  content: z.string().trim().min(1).max(1000),
  eventId: z.string().trim().min(1).max(128).optional().nullable(),
  eventTitle: z.string().trim().max(120).optional().nullable(),
  mediaUrl: z.string().trim().url().max(1024).optional().nullable(),
  isCollabOpen: z.boolean().default(false),
  collabType: z.string().trim().max(60).optional().nullable(),
});

const commentSchema = postIdSchema.extend({
  text: z.string().trim().min(1).max(600),
});

const deleteCommentSchema = postIdSchema.extend({
  commentId: z.string().trim().min(1).max(128),
});

const collabSchema = postIdSchema.extend({
  message: z.string().trim().max(300).optional().nullable(),
});

function displayNameOf(user: Record<string, unknown>, token: Record<string, unknown>): string {
  const candidates = [user.displayName, user.name, token.name];
  for (const candidate of candidates) {
    const value = typeof candidate === 'string' ? candidate.trim() : '';
    if (value.length > 0) return value.slice(0, 80);
  }
  return 'Milo User';
}

function avatarOf(user: Record<string, unknown>, token: Record<string, unknown>): string | null {
  for (const candidate of [user.avatarUrl, token.picture]) {
    if (typeof candidate === 'string' && candidate.trim().startsWith('https://')) {
      return candidate.trim();
    }
  }
  return null;
}

async function resolveAuthor(ctx: CallerContext): Promise<CommunityAuthor | null> {
  const claims = ctx.token as Record<string, unknown>;
  const userSnap = await db().collection('users').doc(ctx.uid).get();
  const user = userSnap.data() ?? {};
  const roles = (user.roles ?? {}) as Record<string, unknown>;

  let role: CommunityRole | null = null;
  if (claims.admin === true) {
    role = 'ADMIN';
  } else {
    const explicitRole = String(claims.communityRole ?? '');
    if (claims.communityPoster === true && POST_ROLES.includes(explicitRole as CommunityRole)) {
      role = explicitRole as CommunityRole;
    }
  }

  if (!role && (claims.organizer === true || roles.organizer === true)) {
    role = 'ORGANIZER';
  }
  if (!role && (claims.promoter === true || roles.promoter === true)) {
    role = 'INFLUENCER';
  }

  if (!role) {
    const organizerSnap = await db().collection('organizers').doc(ctx.uid).get();
    if (organizerSnap.data()?.kycStatus === 'approved') role = 'ORGANIZER';
  }
  if (!role) {
    const promoterSnap = await db().collection('promoters').doc(ctx.uid).get();
    if (promoterSnap.data()?.status === 'active') role = 'INFLUENCER';
  }

  if (!role) return null;

  return {
    uid: ctx.uid,
    name: displayNameOf(user, claims),
    avatarUrl: avatarOf(user, claims),
    role,
    badge: ROLE_BADGES[role],
  };
}

async function resolveCommenter(ctx: CallerContext): Promise<CommunityAuthor> {
  const postAuthor = await resolveAuthor(ctx);
  if (postAuthor) return postAuthor;

  const claims = ctx.token as Record<string, unknown>;
  const userSnap = await db().collection('users').doc(ctx.uid).get();
  const user = userSnap.data() ?? {};
  return {
    uid: ctx.uid,
    name: displayNameOf(user, claims),
    avatarUrl: avatarOf(user, claims),
    role: 'ATTENDEE',
    badge: ROLE_BADGES.ATTENDEE,
  };
}

export const createCommunityPost = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = createPostSchema.parse(req.data);
  const author = await resolveAuthor(ctx);
  if (!author) {
    fail('FORBIDDEN', 'Only verified organizers, promoters, artists and partners can publish posts.');
  }

  await consumeRateLimit(rateLimitKey('community_post', ctx.uid), 5, 24 * 60 * 60 * 1000);

  let eventTitle = input.eventTitle?.trim() || null;
  if (input.eventId) {
    const eventSnap = await db().collection('events').doc(input.eventId).get();
    if (!eventSnap.exists) fail('NOT_FOUND', 'That event could not be found.');
    const event = eventSnap.data()!;
    if (author.role === 'ORGANIZER' && event.organizerId !== ctx.uid) {
      fail('FORBIDDEN', 'You can only tag events that you organize.');
    }
    eventTitle = typeof event.title === 'string' ? event.title.slice(0, 120) : eventTitle;
  }

  const isCollabOpen = input.isCollabOpen === true;
  const ref = db().collection('communityPosts').doc();
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
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeAuditLog({
    actorUid: ctx.uid,
    action: 'community.post.create',
    targetType: 'communityPost',
    targetId: ref.id,
    after: { role: author.role },
  });

  return { ok: true, postId: ref.id };
});

export const toggleCommunityLike = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = postIdSchema.parse(req.data);
  await consumeRateLimit(rateLimitKey('community_like', ctx.uid), 120, 60 * 60 * 1000);

  const ref = db().collection('communityPosts').doc(input.postId);
  let result = { liked: false, likesCount: 0 };

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) fail('NOT_FOUND', 'This post no longer exists.');
    const data = snap.data()!;
    if (data.status !== 'active') fail('NOT_FOUND', 'This post is not available.');

    const likedBy = Array.isArray(data.likedBy)
      ? data.likedBy.filter((value): value is string => typeof value === 'string')
      : [];
    const liked = likedBy.includes(ctx.uid);
    const next = liked ? likedBy.filter((uid) => uid !== ctx.uid) : [...likedBy, ctx.uid];

    tx.update(ref, {
      likedBy: next,
      likesCount: next.length,
      updatedAt: FieldValue.serverTimestamp(),
    });
    result = { liked: !liked, likesCount: next.length };
  });

  return result;
});

export const addCommunityComment = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = commentSchema.parse(req.data);
  await consumeRateLimit(rateLimitKey('community_comment', ctx.uid), 30, 10 * 60 * 1000);

  const author = await resolveCommenter(ctx);
  const postRef = db().collection('communityPosts').doc(input.postId);
  const postSnap = await postRef.get();
  if (!postSnap.exists || postSnap.data()?.status !== 'active') {
    fail('NOT_FOUND', 'This post is not available.');
  }

  const commentRef = postRef.collection('comments').doc();
  const batch = db().batch();
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
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.update(postRef, {
    commentsCount: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  return { ok: true, commentId: commentRef.id };
});

export const deleteCommunityComment = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = deleteCommentSchema.parse(req.data);
  const postRef = db().collection('communityPosts').doc(input.postId);
  const commentRef = postRef.collection('comments').doc(input.commentId);
  const commentSnap = await commentRef.get();
  if (!commentSnap.exists) fail('NOT_FOUND', 'Comment not found.');

  const comment = commentSnap.data()!;
  const claims = ctx.token as Record<string, unknown>;
  const isAdmin = claims.admin === true;
  if (comment.authorId !== ctx.uid && !isAdmin) {
    fail('FORBIDDEN', 'You can only delete your own comment.');
  }
  if (comment.status === 'deleted') return { ok: true };

  const batch = db().batch();
  batch.update(commentRef, { status: 'deleted', updatedAt: FieldValue.serverTimestamp() });
  batch.update(postRef, {
    commentsCount: FieldValue.increment(-1),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { ok: true };
});

export const shareCommunityPost = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = postIdSchema.parse(req.data);
  await consumeRateLimit(rateLimitKey('community_share', ctx.uid), 60, 60 * 60 * 1000);

  const ref = db().collection('communityPosts').doc(input.postId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.status !== 'active') {
    fail('NOT_FOUND', 'This post is not available.');
  }
  await ref.update({
    shareCount: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const base = (process.env.MILO_WEB_BASE_URL || 'https://milo.app').replace(/\/+$/, '');
  return { ok: true, url: `${base}/community/${input.postId}` };
});

export const requestCommunityCollab = miloOnCall({}, async (req) => {
  const ctx = requireAuth(req);
  const input = collabSchema.parse(req.data);
  await consumeRateLimit(rateLimitKey('community_collab', ctx.uid), 20, 60 * 60 * 1000);

  const postSnap = await db().collection('communityPosts').doc(input.postId).get();
  if (!postSnap.exists || postSnap.data()?.status !== 'active') {
    fail('NOT_FOUND', 'This post is not available.');
  }
  const post = postSnap.data()!;
  if (post.authorId === ctx.uid) fail('INVALID_INPUT', 'You cannot request a collaboration on your own post.');
  if (post.isCollabOpen !== true) fail('INVALID_INPUT', 'This post is not open for collaborations.');

  const existing = await db()
    .collection('communityCollabRequests')
    .where('postId', '==', input.postId)
    .where('fromUid', '==', ctx.uid)
    .limit(1)
    .get();
  if (!existing.empty) fail('CONFLICT', 'You have already requested this collaboration.');

  const ref = db().collection('communityCollabRequests').doc();
  await ref.set({
    schemaVersion: 1,
    postId: input.postId,
    postAuthorId: post.authorId,
    fromUid: ctx.uid,
    message: input.message ?? null,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, requestId: ref.id };
});
