import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../theme/milo_theme.dart';

class HostBroadcastChannelScreen extends StatefulWidget {
  final EventModel event;
  final bool isHost;

  const HostBroadcastChannelScreen({
    super.key,
    required this.event,
    this.isHost = false,
  });

  @override
  State<HostBroadcastChannelScreen> createState() => _HostBroadcastChannelScreenState();
}

class _HostBroadcastChannelScreenState extends State<HostBroadcastChannelScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _broadcastMessages = [
    {
      'sender': 'Official Host',
      'title': '⚡ Entry & Gate Update',
      'message': 'Gate No. 2 will open at 06:00 PM for VIP pass holders. Parking is free at Ground B.',
      'time': 'Today, 02:15 PM',
      'isUrgent': true,
    },
    {
      'sender': 'Official Host',
      'title': '🪘 Dandiya Sticks Collection',
      'message': 'Collect your complementary illuminated sticks at the welcome desk near registration booth.',
      'time': 'Yesterday, 07:30 PM',
      'isUrgent': false,
    },
    {
      'sender': 'Official Host',
      'title': '🌧️ Weather & Air Conditioned Hall Update',
      'message': 'The entire performance area is weatherproof with high-capacity air-cooling fans installed.',
      'time': '2 days ago',
      'isUrgent': false,
    },
  ];

  void _sendHostBroadcast() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _broadcastMessages.insert(0, {
        'sender': 'Official Host (${widget.event.organizerName})',
        'title': '📢 Live Announcement',
        'message': text,
        'time': 'Just now',
        'isUrgent': true,
      });
      _msgController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MiloColors.bgSurface,
        content: Text(
          '📢 Broadcast SMS & Push Notification Sent to all 240+ attendees!',
          style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: MiloColors.bgSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.event.title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MiloColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HOST ONLY CHAT',
                    style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            Text(
              'Official Updates & Announcements Channel',
              style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Channel Info Notice Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: MiloColors.bgSurface.withValues(alpha: 0.6),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: MiloColors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'One-Way Announcement Channel: Only the event organizer can post. Attendees receive instant SMS & push alerts.',
                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // Broadcast Messages Feed
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: _broadcastMessages.length,
              itemBuilder: (context, index) {
                final item = _broadcastMessages[index];
                final isUrgent = item['isUrgent'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MiloColors.bgSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isUrgent ? MiloColors.primaryLight.withValues(alpha: 0.5) : MiloColors.glassBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: MiloColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.campaign_rounded, color: MiloColors.primaryLight, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item['sender'] as String,
                                style: GoogleFonts.inter(
                                  color: MiloColors.primaryLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item['time'] as String,
                            style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MiloColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['message'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MiloColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Host Composer Toolbar (if Host) or Attendee Listening Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface,
              border: const Border(top: BorderSide(color: MiloColors.glassBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: MiloColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MiloColors.border),
                      ),
                      child: TextField(
                        controller: _msgController,
                        style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Host: Type live announcement for all attendees...',
                          hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: MiloGradients.primaryBrand,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: MiloColors.bg, size: 20),
                      onPressed: _sendHostBroadcast,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
