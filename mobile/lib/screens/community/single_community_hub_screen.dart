import '../../services/milo_session_service.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/mock_data.dart';
import '../../theme/milo_theme.dart';
import '../event_details_screen.dart';

class SingleCommunityHubScreen extends StatefulWidget {
  const SingleCommunityHubScreen({super.key});

  @override
  State<SingleCommunityHubScreen> createState() => _SingleCommunityHubScreenState();
}

class _SingleCommunityHubScreenState extends State<SingleCommunityHubScreen> {
  String _selectedRoleFilter = 'ALL';
  late List<CommunityPost> _posts;

  @override
  void initState() {
    super.initState();
    _posts = _generateInitialCommunityPosts();
  }

  List<CommunityPost> _generateInitialCommunityPosts() {
    return [
      CommunityPost(
        id: 'post-1',
        authorName: 'Utsav Events & Club',
        authorRole: 'ORGANIZER',
        roleBadge: 'Host / Organizer 🎪',
        authorAvatar: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
        content:
            '📢 OFFICIAL ANNOUNCEMENT: Grand Dandiya Mahotsav 2026 stage setup is 80% complete at Sanskriti Lawns! We are offering 10 VIP Backstage Influencer Passes for lifestyle creators with 50k+ reach. DM or tap Apply to Collab!',
        eventTag: 'Grand Dandiya Mahotsav 2026 ✨',
        eventId: 'e1',
        timeAgo: '20m ago',
        likesCount: 142,
        commentsCount: 28,
        mediaUrl: 'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&w=800&q=80',
        isCollabOpen: true,
        collabType: 'Creator Collab 🌟',
        comments: const [
          CommunityComment(
            id: 'c1',
            authorName: 'Riya Sharma',
            authorRole: 'INFLUENCER',
            authorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
            text: 'Just applied! Looking forward to covering the red carpet look! 💃',
            timeAgo: '12m ago',
          ),
          CommunityComment(
            id: 'c2',
            authorName: 'Sahil',
            authorRole: 'ATTENDEE',
            authorAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
            text: 'Can we buy couple passes on self-UPI gateway directly? Booking done!',
            timeAgo: '5m ago',
          ),
        ],
      ),
      CommunityPost(
        id: 'post-2',
        authorName: 'Riya Sharma (Lifestyle)',
        authorRole: 'INFLUENCER',
        roleBadge: 'Influencer (180K) 🌟',
        authorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
        content:
            'Super thrilled to be the Official Creator Ambassador for Neon Garba 2026! 🪘⚡ Use my exclusive Host coupon code "RIYAVIP" for ₹100 instant discount on single & couple passes. Drop your outfit colors below! 👇',
        eventTag: 'Neon Garba & Electronic Beats 🪘⚡',
        eventId: 'e2',
        timeAgo: '1h ago',
        likesCount: 389,
        commentsCount: 54,
        mediaUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=800&q=80',
        isCollabOpen: true,
        collabType: 'Meet & Greet 📸',
        comments: const [
          CommunityComment(
            id: 'c3',
            authorName: 'Ananya S.',
            authorRole: 'ATTENDEE',
            authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
            text: 'Wearing Neon Pink Chaniya Choli! Can we click a squad picture at the booth? 😍',
            timeAgo: '45m ago',
          ),
        ],
      ),
      CommunityPost(
        id: 'post-3',
        authorName: 'DJ Aakash Beats',
        authorRole: 'ARTIST',
        roleBadge: 'Headline Performer 🎤',
        authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
        content:
            'Testing the EDM-Dhol drop for this weekend! Which classic track should we drop into the bass transition: "Chogada" or "Sanedo"? Tell me in the comments, top voted track gets the live stage premiere! 🔥🪘',
        eventTag: 'Grand Dandiya Mahotsav 2026 ✨',
        eventId: 'e1',
        timeAgo: '2h ago',
        likesCount: 276,
        commentsCount: 92,
        isCollabOpen: false,
      ),
      CommunityPost(
        id: 'post-4',
        authorName: 'RedBull India Pop-up',
        authorRole: 'SPONSOR',
        roleBadge: 'Official Beverage Sponsor 💼',
        authorAvatar: 'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?auto=format&fit=crop&w=200&q=80',
        content:
            'We are setting up the Glow Energy Mocktail Bar at both Sunset Rooftop & Neon Garba! We have 2 Pop-Up Stall Slots open for handcrafted accessories / Garba jewelry artisans. Zero stall deposit, pure revenue share.',
        eventTag: 'Sunset Rooftop Acoustic & Open Mic 🎸',
        eventId: 'e3',
        timeAgo: '4h ago',
        likesCount: 94,
        commentsCount: 16,
        isCollabOpen: true,
        collabType: 'Stall Partnership 🤝',
      )
    ];
  }

  void _toggleLike(int index) {
    setState(() {
      final post = _posts[index];
      _posts[index] = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    });
  }

  void _openCommentsModal(CommunityPost post, int postIndex) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 20),
                  height: MediaQuery.of(context).size.height * 0.72,
                  decoration: BoxDecoration(
                    color: MiloColors.bgSurface.withValues(alpha: 0.98),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: MiloColors.glassBorder),
                  ),
                  child: Column(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Community Discussion 💬',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
                          Text('${post.comments.length} Comments',
                              style: GoogleFonts.inter(fontSize: 12, color: MiloColors.primaryLight, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: post.comments.isEmpty
                            ? Center(
                                child: Text('No comments yet. Start the conversation!',
                                    style: GoogleFonts.inter(color: MiloColors.textMuted)),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: post.comments.length,
                                itemBuilder: (context, i) {
                                  final c = post.comments[i];
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
                                          backgroundImage: NetworkImage(c.authorAvatar),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(c.authorName,
                                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                                                  Text(c.timeAgo,
                                                      style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(c.text,
                                                  style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.3)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Input Bar
                      Container(
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
                                controller: commentController,
                                style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Share your vibe or ask host...',
                                  hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: MiloColors.primaryLight, size: 20),
                              onPressed: () {
                                final text = commentController.text.trim();
                                if (text.isNotEmpty) {
                                  final newComment = CommunityComment(
                                    id: 'c-${DateTime.now().millisecondsSinceEpoch}',
                                    authorName: 'Sahil (You)',
                                    authorRole: 'ATTENDEE',
                                    authorAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
                                    text: text,
                                    timeAgo: 'Just now',
                                  );
                                  setModalState(() {
                                    final updatedComments = List<CommunityComment>.from(post.comments)..add(newComment);
                                    final updatedPost = post.copyWith(
                                      comments: updatedComments,
                                      commentsCount: updatedComments.length,
                                    );
                                    _posts[postIndex] = updatedPost;
                                    post = updatedPost;
                                  });
                                  setState(() {});
                                  commentController.clear();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCreatePostModal() {
    final userRole = MiloSessionService.currentRoleNotifier.value;
    if (userRole == null || userRole == MiloRole.customer) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MiloColors.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: MiloColors.primaryLight, size: 22),
              const SizedBox(width: 8),
              Text(
                'Creator / Host Only',
                style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Community publishing is exclusively for verified Event Organizers, Promoters, and Headline Artists.\n\nAttendees can like, comment, and engage with event updates below.',
            style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Got It', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    String selectedRole = 'INFLUENCER';
    String selectedEvent = MockData.events.first.title;
    final contentController = TextEditingController();
    bool isCollab = true;
    String collabBadge = 'Creator Collab 🌟';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 24),
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
                              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text('Post to Events Community ✍️',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Role Selector
                        Text('CHOOSE YOUR ROLE FOR THIS POST',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.primaryLight, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildRoleSelectorChip('ORGANIZER', 'Organizer 🎪', selectedRole, (r) => setModalState(() => selectedRole = r)),
                              const SizedBox(width: 8),
                              _buildRoleSelectorChip('INFLUENCER', 'Influencer 🌟', selectedRole, (r) => setModalState(() => selectedRole = r)),
                              const SizedBox(width: 8),
                              _buildRoleSelectorChip('ARTIST', 'Artist / Performer 🎤', selectedRole, (r) => setModalState(() => selectedRole = r)),
                              const SizedBox(width: 8),
                              _buildRoleSelectorChip('SPONSOR', 'Sponsor / Brand 💼', selectedRole, (r) => setModalState(() => selectedRole = r)),
                              
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Event Tag Selector
                        Text('TAG EVENT',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.primaryLight, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: MiloColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: MiloColors.border),
                          ),
                          child: DropdownButton<String>(
                            value: selectedEvent,
                            isExpanded: true,
                            dropdownColor: MiloColors.bgSurface,
                            underline: const SizedBox(),
                            style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                            items: MockData.events.map((e) {
                              return DropdownMenuItem(value: e.title, child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedEvent = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Post Text Area
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: MiloColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: MiloColors.glassBorder),
                          ),
                          child: TextField(
                            controller: contentController,
                            maxLines: 4,
                            style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: selectedRole == 'ORGANIZER'
                                  ? 'Share early backstage access, VIP pass giveaways, or announce line-up...'
                                  : (selectedRole == 'INFLUENCER'
                                      ? 'Share your meetup plans, promote special host codes, or call for fan meet...'
                                      : 'Looking for a squad, carpool, artist collab, or stall partner? Post here!'),
                              hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Collab Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Open for Collaboration / Squad 🤝',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textPrimary)),
                          subtitle: Text('Shows "Apply to Collab" badge on post',
                              style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
                          value: isCollab,
                          activeThumbColor: MiloColors.primaryLight,
                          activeTrackColor: MiloColors.primary.withValues(alpha: 0.5),
                          onChanged: (val) => setModalState(() => isCollab = val),
                        ),
                        const SizedBox(height: 16),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MiloColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              final text = contentController.text.trim();
                              if (text.isNotEmpty) {
                                final newPost = CommunityPost(
                                  id: 'post-${DateTime.now().millisecondsSinceEpoch}',
                                  authorName: 'Sahil (You)',
                                  authorRole: selectedRole,
                                  roleBadge: _getRoleBadgeText(selectedRole),
                                  authorAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
                                  content: text,
                                  eventTag: selectedEvent,
                                  timeAgo: 'Just now',
                                  isCollabOpen: isCollab,
                                  collabType: isCollab ? collabBadge : null,
                                );
                                setState(() {
                                  _posts.insert(0, newPost);
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: MiloColors.bgSurface,
                                    content: Text('🎉 Post published to Community!',
                                        style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Publish Post to Community 🚀',
                              style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoleSelectorChip(String role, String label, String currentRole, Function(String) onSelect) {
    final isSelected = currentRole == role;
    return GestureDetector(
      onTap: () => onSelect(role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MiloColors.primary : MiloColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? MiloColors.primaryLight : MiloColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _getRoleBadgeText(String role) {
    switch (role) {
      case 'ORGANIZER':
        return 'Host / Organizer 🎪';
      case 'INFLUENCER':
        return 'Influencer / Creator 🌟';
      case 'ARTIST':
        return 'Artist / DJ 🎤';
      case 'SPONSOR':
        return 'Official Partner 💼';
      default:
        return 'VIP Attendee 👥';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ORGANIZER':
        return MiloColors.primary;
      case 'INFLUENCER':
        return MiloColors.amber;
      case 'ARTIST':
        return const Color(0xFFE040FB);
      case 'SPONSOR':
        return MiloColors.primaryLight;
      default:
        return MiloColors.emerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPosts = _posts.where((p) {
      if (_selectedRoleFilter == 'ALL') return true;
      return p.authorRole == _selectedRoleFilter;
    }).toList();

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
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: MiloGradients.primaryBrand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('HUB', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: MiloColors.bg)),
                ),
              ],
            ),
            Text(
              'Official Event Updates • Influencers • Artists • Sponsors',
              style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: MiloColors.primaryLight, size: 26),
            onPressed: _openCreatePostModal,
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── Open Source Event Platform Banner ──
          Container(
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
              border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MiloColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.code_rounded, color: MiloColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Open Source Event Engine 🌐',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, color: MiloColors.amber, size: 14),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '100% Free & Transparent Event Networking. Direct peer-to-peer connections with zero middleman fees.',
                        style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Role Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterTab('ALL', 'All Hub 🌐'),
                const SizedBox(width: 8),
                _buildFilterTab('ORGANIZER', 'Organizers 🎪'),
                const SizedBox(width: 8),
                _buildFilterTab('INFLUENCER', 'Influencers 🌟'),
                const SizedBox(width: 8),
                _buildFilterTab('ARTIST', 'Artists 🎤'),
                const SizedBox(width: 8),
                _buildFilterTab('SPONSOR', 'Sponsors 💼'),
                
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Community Feed
          if (filteredPosts.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text('No community posts in this category yet. Be the first to post!',
                  style: GoogleFonts.inter(color: MiloColors.textMuted)),
            )
          else
            ...List.generate(filteredPosts.length, (index) {
              final post = filteredPosts[index];
              final roleColor = _getRoleColor(post.authorRole);

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
                    // Post Header: Avatar, Name, Role Badge, Time
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
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
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      flex: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: roleColor.withValues(alpha: 0.5), width: 0.9),
                                        ),
                                        child: Text(
                                          post.roleBadge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: roleColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(post.timeAgo, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Event Tag Pill (Clickable)
                    if (post.eventTag != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: () {
                            final matchingEvent = MockData.events.firstWhere(
                              (e) => e.title == post.eventTag || e.id == post.eventId,
                              orElse: () => MockData.events.first,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EventDetailsScreen(event: matchingEvent)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: MiloColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.confirmation_number_outlined, color: MiloColors.primaryLight, size: 13),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    post.eventTag!,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, color: MiloColors.primaryLight, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Post Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        post.content,
                        style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textPrimary, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Optional Media Image
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
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                        ),
                      ),

                    // Collab Action Box if open
                    if (post.isCollabOpen)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: MiloColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MiloColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.handshake_outlined, color: MiloColors.primaryLight, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  post.collabType ?? 'Collab Opportunity',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.primaryLight),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MiloColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: MiloColors.bgSurface,
                                    content: Text('🤝 Collaboration request sent to ${post.authorName}!',
                                        style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
                                  ),
                                );
                              },
                              child: Text('Connect 🤝', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    const Divider(color: MiloColors.border, height: 1),

                    // Engagement Bar (Like, Comment, Share)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Like Button
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _toggleLike(index),
                            icon: Icon(
                              post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: post.isLiked ? MiloColors.rose : MiloColors.textMuted,
                              size: 18,
                            ),
                            label: Text(
                              '${post.likesCount}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: post.isLiked ? MiloColors.rose : MiloColors.textMuted,
                              ),
                            ),
                          ),
                          // Comments Button
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _openCommentsModal(post, index),
                            icon: const Icon(Icons.mode_comment_outlined, color: MiloColors.textMuted, size: 18),
                            label: Text(
                              '${post.commentsCount} Comments',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textMuted),
                            ),
                          ),
                          // Share Button
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied! Share community thread with squad.')),
                              );
                            },
                            icon: const Icon(Icons.share_outlined, color: MiloColors.textMuted, size: 18),
                            label: Text('Share', style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 60),
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MiloColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
