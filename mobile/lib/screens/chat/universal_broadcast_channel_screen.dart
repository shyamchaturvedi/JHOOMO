import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/milo_session_service.dart';

enum BroadcastType { eventOrganizer, creatorChannel }

class BroadcastChannelMessage {
  final String id;
  final String senderName;
  final String senderAvatar;
  final String title;
  final String message;
  final String time;
  final bool isUrgent;
  final String? attachedPromoCode;
  final double? attachedDiscount;
  final int reactionCount;

  const BroadcastChannelMessage({
    required this.id,
    required this.senderName,
    required this.senderAvatar,
    required this.title,
    required this.message,
    required this.time,
    this.isUrgent = false,
    this.attachedPromoCode,
    this.attachedDiscount,
    this.reactionCount = 0,
  });
}

class UniversalBroadcastChannelScreen extends StatefulWidget {
  final BroadcastType type;
  final String channelTitle;
  final String channelSubtitle;
  final String ownerName;
  final String ownerHandle;
  final String ownerAvatar;
  final String ownerUid;
  final EventModel? event;

  const UniversalBroadcastChannelScreen({
    super.key,
    required this.type,
    required this.channelTitle,
    required this.channelSubtitle,
    required this.ownerName,
    required this.ownerHandle,
    required this.ownerAvatar,
    required this.ownerUid,
    this.event,
  });

  @override
  State<UniversalBroadcastChannelScreen> createState() => _UniversalBroadcastChannelScreenState();
}

class _UniversalBroadcastChannelScreenState extends State<UniversalBroadcastChannelScreen> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isUrgent = false;

  late final List<BroadcastChannelMessage> _messages;

  bool get _isChannelOwner {
    final currentUid = MiloSessionService.currentUid.trim();
    if (currentUid.isNotEmpty && currentUid == widget.ownerUid.trim()) {
      return true;
    }
    // Check if role is Organizer or Promoter matching handle
    final role = MiloSessionService.currentRole;
    if (widget.type == BroadcastType.eventOrganizer && role == MiloRole.organizer) {
      return true;
    }
    if (widget.type == BroadcastType.creatorChannel && role == MiloRole.promoter) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _messages = _getInitialBroadcasts();
  }

  List<BroadcastChannelMessage> _getInitialBroadcasts() {
    if (widget.type == BroadcastType.eventOrganizer) {
      return [
        const BroadcastChannelMessage(
          id: 'b-1',
          senderName: 'Official Host',
          senderAvatar: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
          title: '🚨 VIP Gate & Parking Schedule',
          message: 'VIP and Couple Pass holders are requested to use Gate No. 2 directly. Free valet parking is open at Ground B from 06:30 PM onwards.',
          time: 'Today, 03:15 PM',
          isUrgent: true,
          reactionCount: 142,
        ),
        const BroadcastChannelMessage(
          id: 'b-2',
          senderName: 'Official Host',
          senderAvatar: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
          title: '✨ Complementary Dandiya Sticks',
          message: 'Collect your high-grade illuminated dandiya sticks at the welcome counter by simply showing your confirmed ticket QR pass.',
          time: 'Yesterday, 07:00 PM',
          reactionCount: 289,
        ),
      ];
    } else {
      return [
        BroadcastChannelMessage(
          id: 'cb-1',
          senderName: widget.ownerName,
          senderAvatar: widget.ownerAvatar,
          title: 'Exclusive Host Discount Drop! 🎟️',
          message: 'Hey squad! Host has authorized my special link with ₹20 instant discount for the first 50 bookings. Book before passes sell out!',
          time: '1h ago',
          isUrgent: false,
          attachedPromoCode: 'RIYA20',
          attachedDiscount: 20.0,
          reactionCount: 95,
        ),
        BroadcastChannelMessage(
          id: 'cb-2',
          senderName: widget.ownerName,
          senderAvatar: widget.ownerAvatar,
          title: 'Outfit & Red Carpet Meetup 💖',
          message: 'Wearing Emerald Green lehenga tonight! Let us all click a grand squad photo near the Jhoomo Photo Booth at 8:30 PM sharp.',
          time: '5h ago',
          reactionCount: 210,
        ),
      ];
    }
  }

  void _sendMessage() {
    final body = _msgController.text.trim();
    if (body.isEmpty) return;

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (widget.type == BroadcastType.eventOrganizer ? '📢 Host Announcement' : '✨ Creator Update');

    setState(() {
      _messages.insert(
        0,
        BroadcastChannelMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          senderName: widget.ownerName,
          senderAvatar: widget.ownerAvatar,
          title: title,
          message: body,
          time: 'Just now',
          isUrgent: _isUrgent,
        ),
      );
      _msgController.clear();
      _titleController.clear();
      _isUrgent = false;
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Text(
          '📢 Broadcast sent to all ${widget.type == BroadcastType.eventOrganizer ? 'ticket holders' : 'followers'}!',
          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.ownerAvatar),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.channelTitle,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: widget.type == BroadcastType.eventOrganizer
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                  Text(
                    widget.type == BroadcastType.eventOrganizer
                        ? 'Official Event Channel · 1-Way'
                        : '${widget.ownerHandle} · Creator Broadcast',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB), size: 14),
                const SizedBox(width: 4),
                Text(
                  'BROADCAST',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isChannelOwner
                        ? 'You are the Owner. Only you can broadcast messages here.'
                        : 'Only ${widget.ownerName} can send messages. Members can react.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                return _buildBroadcastBubble(item);
              },
            ),
          ),

          // Bottom Bar: Owner Composer OR Follower Read-Only Reaction Dock
          _isChannelOwner ? _buildOwnerComposer() : _buildFollowerReactionDock(),
        ],
      ),
    );
  }

  Widget _buildBroadcastBubble(BroadcastChannelMessage item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isUrgent ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
          width: item.isUrgent ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(item.senderAvatar),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.senderName,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                  ),
                ],
              ),
              Text(item.time, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: item.isUrgent ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.message,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.45),
          ),

          // Attached Offer Card (if any)
          if (item.attachedPromoCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDA4AF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_rounded, color: Color(0xFFE11D48), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Code: ${item.attachedPromoCode} (₹${item.attachedDiscount?.toStringAsFixed(0)} OFF)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFE11D48)),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.attachedPromoCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Promo Code ${item.attachedPromoCode} copied!')),
                      );
                    },
                    child: Text('Copy', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Reaction strip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('❤️ 🔥 🙌', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      '${item.reactionCount}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      hintText: 'Title (e.g. Gate Update, Soundcheck)',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Urgent 🚨', style: TextStyle(fontSize: 11)),
                  selected: _isUrgent,
                  selectedColor: const Color(0xFFFEE2E2),
                  onSelected: (val) => setState(() => _isUrgent = val),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Broadcast message to everyone...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowerReactionDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              'React to Broadcast:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
            const Spacer(),
            ...['❤️', '🔥', '🙌', '🎟️', '👏'].map((emoji) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 900),
                      content: Text('Reacted with $emoji'),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
