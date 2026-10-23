import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_approval_service.dart';
import '../services/jhoomo_notification_tone_service.dart';
import '../theme/milo_theme.dart';
import 'my_tickets_screen.dart';
import 'organizer/organizer_dashboard_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedCategory = 'ALL'; // 'ALL', 'TICKETS', 'APPROVALS', 'OFFERS'

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PaymentApprovalService.instance,
      builder: (context, _) {
        final allNotifs = PaymentApprovalService.instance.notifications;

        // Filter notifications by active tab category
        final filteredNotifs = allNotifs.where((n) {
          final type = n['type'] as String? ?? '';
          if (_selectedCategory == 'ALL') return true;
          if (_selectedCategory == 'TICKETS') return type == 'ticket';
          if (_selectedCategory == 'APPROVALS') return type == 'approval_request';
          if (_selectedCategory == 'OFFERS') return type != 'ticket' && type != 'approval_request';
          return true;
        }).toList();

        final unreadCount = allNotifs.where((n) => n['isUnread'] as bool? ?? false).length;

        return Scaffold(
          backgroundColor: MiloColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: MiloColors.border),
                ),
                child: const Icon(Icons.arrow_back, color: MiloColors.textPrimary, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 18),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount NEW',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Instant booking QR, approvals & event alerts',
                  style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
                ),
              ],
            ),
            actions: [
              // Test JHOOMO signature notification chime button
              IconButton(
                tooltip: 'Play JHOOMO Notification Tone',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MiloColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: MiloColors.primaryLight, size: 18),
                ),
                onPressed: () async {
                  await JhoomoNotificationToneService.instance.playJhoomoChime();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: MiloColors.bgSurface,
                        content: Row(
                          children: [
                            const Icon(Icons.music_note_rounded, color: MiloColors.primaryLight, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'JHOOMO Signature Chime Played (F#5 Triad Bell)',
                                style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 1600),
                      ),
                    );
                  }
                },
              ),
              if (unreadCount > 0)
                IconButton(
                  tooltip: 'Mark All as Read',
                  icon: const Icon(Icons.done_all_rounded, color: MiloColors.primaryLight, size: 20),
                  onPressed: () {
                    PaymentApprovalService.instance.markNotificationsRead();
                  },
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),

              // Filter Tabs (All, Passes & QR, Approvals, Updates)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildFilterTab('ALL', 'All Alerts', allNotifs.length),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      'TICKETS',
                      'Passes & QR 🎟️',
                      allNotifs.where((n) => n['type'] == 'ticket').length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      'APPROVALS',
                      'Host Approvals ⚡',
                      allNotifs.where((n) => n['type'] == 'approval_request').length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      'OFFERS',
                      'Show Updates 🎉',
                      allNotifs.where((n) => n['type'] != 'ticket' && n['type'] != 'approval_request').length,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Notification List
              Expanded(
                child: filteredNotifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: MiloColors.bgSurface,
                                shape: BoxShape.circle,
                                border: Border.all(color: MiloColors.border),
                              ),
                              child: const Icon(Icons.notifications_none_rounded, color: MiloColors.textMuted, size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications in this tab',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: MiloColors.textPrimary, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You will be notified when your booking or gate pass updates.',
                              style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        itemCount: filteredNotifs.length,
                        itemBuilder: (context, index) {
                          final n = filteredNotifs[index];
                          final isUnread = n['isUnread'] as bool? ?? false;
                          final type = n['type'] as String? ?? '';
                          final title = n['title'] as String? ?? 'Notification';
                          final body = n['body'] as String? ?? '';
                          final time = n['time'] as String? ?? 'Just now';

                          IconData leadingIcon = Icons.notifications_rounded;
                          Color accentColor = MiloColors.primaryLight;
                          String categoryBadge = 'ALERT';

                          if (type == 'ticket') {
                            leadingIcon = Icons.confirmation_number_rounded;
                            accentColor = const Color(0xFF10B981); // Emerald
                            categoryBadge = 'PASS';
                          } else if (type == 'approval_request') {
                            leadingIcon = Icons.currency_rupee_rounded;
                            accentColor = const Color(0xFFF59E0B); // Amber
                            categoryBadge = 'ACTION NEEDED';
                          } else if (type == 'community') {
                            leadingIcon = Icons.hub_rounded;
                            accentColor = const Color(0xFF8B5CF6); // Purple
                            categoryBadge = 'COMMUNITY';
                          }

                          return GestureDetector(
                            onTap: () {
                              // Play subtle haptic feedback
                              JhoomoNotificationToneService.instance.playJhoomoChime(withHaptic: true);

                              if (type == 'ticket') {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTicketsScreen()));
                              } else if (type == 'approval_request') {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const OrganizerDashboardScreen()));
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isUnread ? MiloColors.bgSurface : MiloColors.bgSurface.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isUnread ? accentColor.withValues(alpha: 0.45) : MiloColors.border,
                                  width: isUnread ? 1.4 : 1.0,
                                ),
                                boxShadow: isUnread
                                    ? [
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.08),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leading circular badge with icon
                                  Container(
                                    width: 42,
                                    height: 42,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Icon(leadingIcon, color: accentColor, size: 20),
                                  ),

                                  // Details Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w800,
                                                  color: MiloColors.textPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: accentColor.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                                              ),
                                              child: Text(
                                                categoryBadge,
                                                style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: accentColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          body,
                                          style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.4),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              time,
                                              style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                                            ),
                                            if (type == 'ticket' || type == 'approval_request')
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    type == 'ticket' ? 'View Pass' : 'Review & Approve',
                                                    style: GoogleFonts.inter(
                                                      color: accentColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(Icons.chevron_right_rounded, size: 14, color: accentColor),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(String id, String label, int count) {
    final isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MiloColors.primary : MiloColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MiloColors.primaryLight : MiloColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MiloColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : MiloColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : MiloColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : MiloColors.textMuted,
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
