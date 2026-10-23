import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../services/community_service.dart';
import '../../theme/milo_theme.dart';

class SingleCommunityHubScreen extends StatefulWidget {
  const SingleCommunityHubScreen({super.key});

  @override
  State<SingleCommunityHubScreen> createState() =>
      _SingleCommunityHubScreenState();
}

class _SingleCommunityHubScreenState extends State<SingleCommunityHubScreen> {
  String _selectedRoleFilter = 'ALL';
  late Stream<List<CommunityPost>> _postsStream;

  @override
  void initState() {
    super.initState();
    _postsStream = CommunityService.instance.watchPosts();
  }

  Future<void> _toggleLike(CommunityPost post) async {
    try {
      await CommunityService.instance.toggleLike(post.id);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _sharePost(CommunityPost post) async {
    try {
      final url = await CommunityService.instance.sharePost(post.id);
      if (url.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community link copied to clipboard.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _requestCollab(CommunityPost post) async {
    try {
      await CommunityService.instance.requestCollab(postId: post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MiloColors.bgSurface,
          content: Text(
            'Collaboration request sent to ${post.authorName}.',
            style: GoogleFonts.inter(
              color: MiloColors.emerald,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is Exception ? error.toString() : '$error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MiloColors.bgSurface,
        content: Text(
          message.replaceFirst('MiloApiException(', '').replaceFirst(')', ''),
          style: GoogleFonts.inter(
            color: MiloColors.rose,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _openComments(CommunityPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: post),
    );
  }

  Future<void> _openCreatePost() async {
    if (!CommunityService.instance.canPublish) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MiloColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Verified creators only',
            style: GoogleFonts.inter(
              color: MiloColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Community publishing is limited to verified organizers, promoters, '
            'artists and partners. Attendees can like, comment and share posts.',
            style: GoogleFonts.inter(
              color: MiloColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Got it',
                style: GoogleFonts.inter(
                  color: MiloColors.primaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePostSheet(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published to the community.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Events Community',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: MiloColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: MiloGradients.primaryBrand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'HUB',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: MiloColors.bg,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Official updates • Influencers • Artists • Sponsors',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MiloColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (CommunityService.instance.canPublish)
            IconButton(
              tooltip: 'Create post',
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: MiloColors.primaryLight,
                size: 26,
              ),
              onPressed: _openCreatePost,
            ),
        ],
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Could not load the community feed.',
              onRetry: () {
                setState(() {
                  _postsStream = CommunityService.instance.watchPosts();
                });
              },
            );
          }

          final posts = snapshot.data ?? const <CommunityPost>[];
          final filtered = _selectedRoleFilter == 'ALL'
              ? posts
              : posts
                  .where((post) => post.authorRole == _selectedRoleFilter)
                  .toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildBanner(),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterTab('ALL', 'All Hub'),
                    const SizedBox(width: 8),
                    _buildFilterTab('ORGANIZER', 'Organizers'),
                    const SizedBox(width: 8),
                    _buildFilterTab('INFLUENCER', 'Influencers'),
                    const SizedBox(width: 8),
                    _buildFilterTab('ARTIST', 'Artists'),
                    const SizedBox(width: 8),
                    _buildFilterTab('SPONSOR', 'Sponsors'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _EmptyState(
                  hasFilter: _selectedRoleFilter != 'ALL',
                  canPublish: CommunityService.instance.canPublish,
                  onPost: _openCreatePost,
                )
              else
                ...filtered.map(
                  (post) => _PostCard(
                    post: post,
                    onLike: () => _toggleLike(post),
                    onComments: () => _openComments(post),
                    onShare: () => _sharePost(post),
                    onCollab: () => _requestCollab(post),
                  ),
                ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MiloColors.primary.withValues(alpha: 0.22),
            MiloColors.bgSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MiloColors.primaryLight.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MiloColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: MiloColors.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Verified event updates, creator collabs and community conversations — all in one real-time feed.',
              style: GoogleFonts.inter(
                color: MiloColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String roleKey, String label) {
    final isSelected = _selectedRoleFilter == roleKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = roleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MiloColors.primary : MiloColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MiloColors.primaryLight : MiloColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onCollab,
  });

  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onCollab;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(post.authorRole);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: MiloColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MiloColors.glassBorder, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: MiloColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: MiloColors.bgCard,
                  backgroundImage: NetworkImage(post.authorAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            flex: 5,
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: MiloColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: roleColor.withValues(alpha: 0.5),
                                  width: 0.9,
                                ),
                              ),
                              child: Text(
                                post.roleBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MiloColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post.eventTag != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: MiloColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MiloColors.primaryLight.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: MiloColors.primaryLight,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        post.eventTag!,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MiloColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MiloColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (post.mediaUrl != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 200,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  post.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (post.isCollabOpen)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: MiloColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MiloColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.handshake_outlined,
                          color: MiloColors.primaryLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            post.collabType ?? 'Collab opportunity',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: MiloColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiloColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onCollab,
                    child: Text(
                      'Request',
                      style: GoogleFonts.inter(
                        color: MiloColors.bg,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Divider(color: MiloColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onLike,
                  icon: Icon(
                    post.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: post.isLiked ? MiloColors.rose : MiloColors.textMuted,
                    size: 18,
                  ),
                  label: Text(
                    '${post.likesCount}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: post.isLiked
                          ? MiloColors.rose
                          : MiloColors.textMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onComments,
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: MiloColors.textMuted,
                    size: 18,
                  ),
                  label: Text(
                    '${post.commentsCount} Comments',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MiloColors.textMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onShare,
                  icon: const Icon(
                    Icons.share_outlined,
                    color: MiloColors.textMuted,
                    size: 18,
                  ),
                  label: Text(
                    'Share',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MiloColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'ORGANIZER':
        return MiloColors.primary;
      case 'INFLUENCER':
        return MiloColors.amber;
      case 'ARTIST':
        return const Color(0xFFE040FB);
      case 'SPONSOR':
        return MiloColors.primaryLight;
      case 'ADMIN':
        return MiloColors.cyan;
      default:
        return MiloColors.emerald;
    }
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post});

  final CommunityPost post;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<CommunityComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await CommunityService.instance.fetchComments(
        widget.post.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load comments.';
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CommunityService.instance.addComment(
        postId: widget.post.id,
        text: text,
      );
      _controller.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: MiloColors.bgSurface.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: MiloColors.glassBorder),
          ),
          child: Column(
            children: [
              _handle(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Community Discussion',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: MiloColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_comments.length} comments',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MiloColors.primaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _body()),
              _inputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: MiloColors.primaryLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.inter(color: MiloColors.textMuted),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'No comments yet. Start the conversation!',
          style: GoogleFonts.inter(color: MiloColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MiloColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MiloColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: MiloColors.bgSurface,
                backgroundImage: NetworkImage(comment.authorAvatar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            comment.authorName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: MiloColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          comment.timeAgo,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: MiloColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.text,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MiloColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: MiloColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MiloColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.inter(
                color: MiloColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Share your vibe or ask host...',
                hintStyle: GoogleFonts.inter(
                  color: MiloColors.textMuted,
                  fontSize: 12,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: MiloColors.primaryLight,
                    size: 20,
                  ),
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet();

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _content = TextEditingController();
  final TextEditingController _eventTitle = TextEditingController();
  bool _isCollab = false;
  bool _submitting = false;

  @override
  void dispose() {
    _content.dispose();
    _eventTitle.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _content.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await CommunityService.instance.createPost(
        content: text,
        eventTitle: _eventTitle.text.trim().isEmpty
            ? null
            : _eventTitle.text.trim(),
        isCollabOpen: _isCollab,
        collabType: _isCollab ? 'Creator collaboration' : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: MiloColors.bgSurface.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: MiloColors.glassBorder),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MiloColors.primaryLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: MiloGradients.primaryBrand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Post to Events Community',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: MiloColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your verified role and badge are added automatically by Milo.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MiloColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _eventTitle,
                  label: 'Event tag (optional)',
                  hint: 'e.g. Neon Garba 2026',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MiloColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MiloColors.glassBorder),
                  ),
                  child: TextField(
                    controller: _content,
                    maxLines: 5,
                    maxLength: 1000,
                    style: GoogleFonts.inter(
                      color: MiloColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Share an update, lineup news, or call for collaborators...',
                      hintStyle: GoogleFonts.inter(
                        color: MiloColors.textMuted,
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      counterStyle: GoogleFonts.inter(
                        color: MiloColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Open for collaboration',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MiloColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Shows a real collaboration request button on the post',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MiloColors.textMuted,
                    ),
                  ),
                  value: _isCollab,
                  activeThumbColor: MiloColors.primaryLight,
                  activeTrackColor: MiloColors.primary.withValues(alpha: 0.5),
                  onChanged: (value) => setState(() => _isCollab = value),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiloColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Publish Post',
                            style: GoogleFonts.inter(
                              color: MiloColors.bg,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: MiloColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MiloColors.border),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(
          color: MiloColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: MiloColors.textMuted,
            fontSize: 11,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: MiloColors.textMuted,
            fontSize: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilter,
    required this.canPublish,
    required this.onPost,
  });

  final bool hasFilter;
  final bool canPublish;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MiloColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MiloColors.glassBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.forum_outlined,
            color: MiloColors.textMuted,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'No posts in this category yet.'
                : 'No community posts yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: MiloColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canPublish
                ? 'Share the first verified update with the community.'
                : 'Verified organizers, promoters and partners will post updates here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: MiloColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (canPublish) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: MiloColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onPost,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: Text(
                'Create first post',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: MiloColors.textMuted,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(color: MiloColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
