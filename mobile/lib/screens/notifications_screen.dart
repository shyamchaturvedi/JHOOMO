import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_approval_service.dart';
import '../theme/milo_theme.dart';
import 'my_tickets_screen.dart';
import 'organizer/organizer_dashboard_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PaymentApprovalService.instance,
      builder: (context, _) {
        final notifications = PaymentApprovalService.instance.notifications;

        return Scaffold(
          backgroundColor: MiloColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Notifications 🔔',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: notifications.isEmpty
              ? Center(
                  child: Text('No notifications yet', style: GoogleFonts.inter(color: MiloColors.textMuted)),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isUnread = n['isUnread'] as bool? ?? false;
                    final type = n['type'] as String? ?? '';

                    return GestureDetector(
                      onTap: () {
                        if (type == 'ticket') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTicketsScreen()));
                        } else if (type == 'approval_request') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const OrganizerDashboardScreen()));
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isUnread ? MiloColors.bgSurface : MiloColors.bgSurface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isUnread ? MiloColors.primaryLight.withValues(alpha: 0.5) : MiloColors.border,
                            width: isUnread ? 1.2 : 1.0,
                          ),
                          boxShadow: isUnread
                              ? [
                                  BoxShadow(
                                    color: MiloColors.primary.withValues(alpha: 0.08),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 4, right: 12),
                              decoration: BoxDecoration(
                                color: isUnread ? MiloColors.primaryLight : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n['title'] as String,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 14),
                                        ),
                                      ),
                                      if (type == 'approval_request')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: MiloColors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('ACTION REQUIRED', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: MiloColors.amber)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n['body'] as String,
                                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    n['time'] as String,
                                    style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10),
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
        );
      },
    );
  }
}
