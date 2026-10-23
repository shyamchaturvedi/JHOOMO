import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../services/mock_data.dart';
import 'chat/chat_conversation_screen.dart';
import 'chat/universal_broadcast_channel_screen.dart';

/// S-21 · Chat List Screen
/// Shows Direct DMs, Event Group Chats, and Official 1-Way Broadcast Channels
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _search = '';

  // Mock chat data
  final List<_ChatPreview> _dms = [
    _ChatPreview(
      uid: 'u1',
      name: 'Priya S.',
      avatarLetter: 'P',
      lastMessage: 'See you at the event! 💃',
      time: '2m',
      unread: 2,
      isOnline: true,
      isE2EE: true,
    ),
    _ChatPreview(
      uid: 'u2',
      name: 'Rohan K.',
      avatarLetter: 'R',
      lastMessage: 'Which gate are you entering from?',
      time: '1h',
      unread: 0,
      isOnline: false,
      isE2EE: true,
    ),
    _ChatPreview(
      uid: 'u3',
      name: 'Neha M.',
      avatarLetter: 'N',
      lastMessage: '🔥 Can\'t wait for tonight!',
      time: 'Yesterday',
      unread: 0,
      isOnline: true,
      isE2EE: true,
    ),
  ];

  final List<_BroadcastChannelPreview> _broadcasts = [
    _BroadcastChannelPreview(
      id: 'bc_e1',
      type: BroadcastType.eventOrganizer,
      title: 'Grand Dandiya 2026 • Official Channel',
      subtitle: 'Official Event Updates & Announcements',
      ownerName: 'Utsav Events & Club',
      ownerHandle: '@utsav_club',
      ownerAvatar: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
      ownerUid: 'org-utsav-01',
      lastUpdate: 'Entry Gate 1 & 2 open now! Please keep dynamic QR ready.',
      time: '10m',
      unreadCount: 3,
      memberCount: 840,
      isVerified: true,
      tag: 'BOOKED EVENT',
    ),
    _BroadcastChannelPreview(
      id: 'bc_c1',
      type: BroadcastType.creatorChannel,
      title: 'Riya Lifestyle • Exclusive Garba Squad',
      subtitle: 'Creator VIP Hub & Outfits',
      ownerName: 'Riya Sharma',
      ownerHandle: '@riya_lifestyle',
      ownerAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
      ownerUid: 'creator-riya-99',
      lastUpdate: 'Host approved 10 backstage passes! Tap link to claim.',
      time: '1h',
      unreadCount: 1,
      memberCount: 2450,
      isVerified: true,
      tag: 'FOLLOWING CREATOR',
    ),
    _BroadcastChannelPreview(
      id: 'bc_e2',
      type: BroadcastType.eventOrganizer,
      title: 'Neon Garba & Electronic Beats',
      subtitle: 'Artist Lineup & Parking Map Updates',
      ownerName: 'Vibe Nation Productions',
      ownerHandle: '@vibenation_in',
      ownerAvatar: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=200&q=80',
      ownerUid: 'org-vibe-02',
      lastUpdate: 'DJ Aakash Beats soundcheck live at 6:30 PM!',
      time: '3h',
      unreadCount: 0,
      memberCount: 1210,
      isVerified: true,
      tag: 'BOOKED EVENT',
    ),
  ];

  final List<_ChatPreview> _groups = [
    _ChatPreview(
      uid: 'g1',
      name: 'Dandiya Night 2026 🎉',
      avatarLetter: '🎉',
      lastMessage: 'Organizer: Doors open at 7 PM sharp!',
      time: '5m',
      unread: 18,
      isOnline: false,
      isGroup: true,
      memberCount: 342,
    ),
    _ChatPreview(
      uid: 'g2',
      name: 'DJ Night – Lucknow Live',
      avatarLetter: '🎧',
      lastMessage: 'Anyone carpooling from Hazratganj?',
      time: '30m',
      unread: 5,
      isOnline: false,
      isGroup: true,
      memberCount: 128,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Messages & Channels',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: MiloColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(92),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  style: GoogleFonts.inter(fontSize: 14, color: MiloColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search chats & broadcast channels…',
                    hintStyle: GoogleFonts.inter(color: MiloColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: MiloColors.textMuted, size: 20),
                    filled: true,
                    fillColor: MiloColors.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                labelColor: MiloColors.primaryLight,
                unselectedLabelColor: MiloColors.textMuted,
                indicatorColor: MiloColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Direct'),
                        if (_dms.any((d) => d.unread > 0)) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: MiloColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_dms.fold(0, (s, d) => s + d.unread)}',
                              style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Groups'),
                        if (_groups.any((g) => g.unread > 0)) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: MiloColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_groups.fold(0, (s, g) => s + g.unread)}',
                              style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.campaign_rounded, size: 14),
                        const SizedBox(width: 4),
                        const Text('Broadcasts'),
                        if (_broadcasts.any((b) => b.unreadCount > 0)) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_broadcasts.fold(0, (s, b) => s + b.unreadCount)}',
                              style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(_dms, isDM: true),
          _buildChatList(_groups, isDM: false),
          _buildBroadcastsList(),
        ],
      ),
    );
  }

  Widget _buildBroadcastsList() {
    final filtered = _search.isEmpty
        ? _broadcasts
        : _broadcasts.where((b) =>
            b.title.toLowerCase().contains(_search) ||
            b.ownerName.toLowerCase().contains(_search) ||
            b.ownerHandle.toLowerCase().contains(_search)).toList();

    return Column(
      children: [
        // Broadcast explanation pill banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDA4AF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFFE11D48), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '1-Way Official Channels: Only Organizers & Creators post updates. Zero spam, pure real-time event intel & deals.',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF881337), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState(
                  message: 'No broadcast channels yet.\nFollow creators or book events to be auto-enrolled!',
                  icon: Icons.campaign_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    color: MiloColors.border.withValues(alpha: 0.5),
                    indent: 80,
                    height: 1,
                  ),
                  itemBuilder: (_, i) => _buildBroadcastTile(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildBroadcastTile(_BroadcastChannelPreview b) {
    final isOrganizer = b.type == BroadcastType.eventOrganizer;

    return ListTile(
      onTap: () {
        final matchingEvent = MockData.events.firstWhere(
          (e) => b.title.toLowerCase().contains(e.title.toLowerCase()),
          orElse: () => MockData.events.first,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UniversalBroadcastChannelScreen(
              type: b.type,
              channelTitle: b.title,
              channelSubtitle: b.subtitle,
              ownerName: b.ownerName,
              ownerHandle: b.ownerHandle,
              ownerAvatar: b.ownerAvatar,
              ownerUid: b.ownerUid,
              event: matchingEvent,
            ),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: NetworkImage(b.ownerAvatar),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isOrganizer ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                isOrganizer ? Icons.festival_rounded : Icons.star_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    b.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: b.unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                      color: MiloColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            b.time,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: b.unreadCount > 0 ? const Color(0xFFE11D48) : MiloColors.textMuted,
              fontWeight: b.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: (isOrganizer ? const Color(0xFFE11D48) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.tag,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: isOrganizer ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${b.memberCount} members',
                style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${b.ownerName}: ${b.lastUpdate}',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: b.unreadCount > 0 ? MiloColors.textPrimary : MiloColors.textMuted,
                    fontWeight: b.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (b.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${b.unreadCount}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<_ChatPreview> chats, {required bool isDM}) {
    final filtered = _search.isEmpty
        ? chats
        : chats.where((c) => c.name.toLowerCase().contains(_search)).toList();

    if (filtered.isEmpty) {
      return _EmptyState(
        message: isDM
            ? 'No conversations yet.\nSay hello to someone on Radar! 👋'
            : 'No group chats.\nBuy a ticket to join event chats! 🎟️',
        icon: isDM ? Icons.chat_bubble_outline_rounded : Icons.group_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(
        color: MiloColors.border.withValues(alpha: 0.5),
        indent: 80,
        height: 1,
      ),
      itemBuilder: (_, i) => _ChatTile(
        chat: filtered[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              chatId: filtered[i].uid,
              peerName: filtered[i].name,
              isGroup: filtered[i].isGroup,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPreview {
  final String uid;
  final String name;
  final String avatarLetter;
  final String lastMessage;
  final String time;
  final int unread;
  final bool isOnline;
  final bool isGroup;
  final int memberCount;
  final bool isE2EE;

  const _ChatPreview({
    required this.uid,
    required this.name,
    required this.avatarLetter,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.isOnline,
    this.isGroup = false,
    this.memberCount = 0,
    this.isE2EE = false,
  });
}

class _BroadcastChannelPreview {
  final String id;
  final BroadcastType type;
  final String title;
  final String subtitle;
  final String ownerName;
  final String ownerHandle;
  final String ownerAvatar;
  final String ownerUid;
  final String lastUpdate;
  final String time;
  final int unreadCount;
  final int memberCount;
  final bool isVerified;
  final String tag;

  const _BroadcastChannelPreview({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.ownerName,
    required this.ownerHandle,
    required this.ownerAvatar,
    required this.ownerUid,
    required this.lastUpdate,
    required this.time,
    required this.unreadCount,
    required this.memberCount,
    this.isVerified = true,
    required this.tag,
  });
}

class _ChatTile extends StatelessWidget {
  final _ChatPreview chat;
  final VoidCallback onTap;

  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: chat.isGroup ? MiloColors.primary.withValues(alpha: 0.15) : MiloColors.bgCard,
            child: Text(
              chat.avatarLetter,
              style: GoogleFonts.outfit(
                fontSize: chat.avatarLetter.length > 1 ? 20 : 18,
                fontWeight: FontWeight.w800,
                color: MiloColors.primaryLight,
              ),
            ),
          ),
          if (chat.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: MiloColors.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: MiloColors.bg, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: chat.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                color: MiloColors.textPrimary,
              ),
            ),
          ),
          Text(
            chat.time,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: chat.unread > 0 ? MiloColors.primary : MiloColors.textMuted,
              fontWeight: chat.unread > 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            if (chat.isE2EE && !chat.isGroup)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_rounded, size: 11, color: MiloColors.emerald.withValues(alpha: 0.7)),
              ),
            Expanded(
              child: Text(
                chat.lastMessage,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: chat.unread > 0 ? MiloColors.textSecondary : MiloColors.textMuted,
                  fontWeight: chat.unread > 0 ? FontWeight.w500 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chat.unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: MiloColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${chat.unread}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MiloColors.bgCard,
                ),
                child: Icon(icon, size: 32, color: MiloColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: MiloColors.textMuted,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
