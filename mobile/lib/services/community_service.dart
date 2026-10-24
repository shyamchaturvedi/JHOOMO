import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'milo_api.dart';
import 'milo_session_service.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? MiloSessionService.currentUid;

  bool get canPublish {
    final role = MiloSessionService.currentRole;
    return role == MiloRole.organizer ||
        role == MiloRole.promoter ||
        role == MiloRole.admin;
  }

  Stream<List<CommunityPost>> watchPosts() async* {
    try {
      await for (final snapshot in _db
          .collection('communityPosts')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()) {
        yield snapshot.docs.map(_postFromDoc).toList(growable: false);
      }
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;
      await for (final snapshot in _db
          .collection('communityPosts')
          .where('status', isEqualTo: 'active')
          .limit(100)
          .snapshots()) {
        final docs = snapshot.docs.toList()
          ..sort((a, b) {
            final aAt =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final bAt =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return bAt.compareTo(aAt);
          });
        yield docs.map(_postFromDoc).toList(growable: false);
      }
    }
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final snapshot = await _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .get();
    return snapshot.docs.map(_commentFromDoc).toList();
  }

  Future<String> createPost({
    required String content,
    String? eventId,
    String? eventTitle,
    String? mediaUrl,
    bool isCollabOpen = false,
    String? collabType,
  }) async {
    final result = await MiloApi.instance.createCommunityPost(
      content: content,
      eventId: eventId,
      eventTitle: eventTitle,
      mediaUrl: mediaUrl,
      isCollabOpen: isCollabOpen,
      collabType: collabType,
    );
    return (result['postId'] ?? '').toString();
  }

  Future<bool> toggleLike(String postId) async {
    final result = await MiloApi.instance.toggleCommunityLike(postId);
    return result['liked'] == true;
  }

  Future<void> addComment({required String postId, required String text}) =>
      MiloApi.instance.addCommunityComment(postId: postId, text: text);

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) =>
      MiloApi.instance.deleteCommunityComment(
        postId: postId,
        commentId: commentId,
      );

  Future<String> sharePost(String postId) async {
    final result = await MiloApi.instance.shareCommunityPost(postId);
    return (result['url'] ?? '').toString();
  }

  Future<void> requestCollab({required String postId, String? message}) =>
      MiloApi.instance.requestCommunityCollab(postId: postId, message: message);

  CommunityPost _postFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _string(data['authorName'], fallback: 'Jhoomo User');
    final likedBy = _stringList(data['likedBy']);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    return CommunityPost(
      id: doc.id,
      authorName: name,
      authorRole: _string(data['authorRole'], fallback: 'ATTENDEE'),
      roleBadge: _string(data['roleBadge'], fallback: 'Attendee'),
      authorAvatar: _avatar(data['authorAvatar'], name),
      content: _string(data['content']),
      eventTag: _nullableString(data['eventTitle']),
      eventId: _nullableString(data['eventId']),
      timeAgo: _timeAgo(createdAt),
      likesCount: _int(data['likesCount']),
      isLiked: _uid.isNotEmpty && likedBy.contains(_uid),
      commentsCount: _int(data['commentsCount']),
      mediaUrl: _nullableString(data['mediaUrl']),
      isCollabOpen: data['isCollabOpen'] == true,
      collabType: _nullableString(data['collabType']),
      isOfficialCollab: data['isOfficialCollab'] == true,
      bookingsViaCreatorCount: _int(data['bookingsViaCreatorCount']),
    );
  }

  CommunityComment _commentFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _string(data['authorName'], fallback: 'Jhoomo User');
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    return CommunityComment(
      id: doc.id,
      authorName: name,
      authorRole: _string(data['authorRole'], fallback: 'ATTENDEE'),
      authorAvatar: _avatar(data['authorAvatar'], name),
      text: _string(data['text']),
      timeAgo: _timeAgo(createdAt),
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static String _avatar(dynamic value, String name) {
    final url = _nullableString(value);
    if (url != null && url.startsWith('https://')) return url;
    final encoded = Uri.encodeComponent(name.isEmpty ? 'Jhoomo User' : name);
    return 'https://ui-avatars.com/api/?background=E11D48&color=fff&name=$encoded';
  }

  static String _timeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @visibleForTesting
  static String debugTimeAgo(DateTime? date) => _timeAgo(date);
}
