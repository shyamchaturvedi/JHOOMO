import 'wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import 'edit_profile_screen.dart';
import 'your_bookings_screen.dart';
import 'privacy_shield_screen.dart';
import 'settings_screen.dart';
import 'help_center_screen.dart';
import 'legal_policy_screen.dart';
import 'community/single_community_hub_screen.dart';
import 'organizer/bms_list_your_show_portal_screen.dart';
import 'organizer/organizer_dashboard_screen.dart';
import 'promoter/become_influencer_promoter_screen.dart';
import 'promoter/promoter_dashboard_screen.dart';
import 'auth/bms_phone_login_screen.dart';
import '../services/milo_auth_service.dart';
import '../services/milo_session_service.dart';

class ProfileSafetyScreen extends StatefulWidget {
  const ProfileSafetyScreen({super.key});

  @override
  State<ProfileSafetyScreen> createState() => _ProfileSafetyScreenState();
}

class _ProfileSafetyScreenState extends State<ProfileSafetyScreen> {
  @override
  Widget build(BuildContext context) {
    final role = MiloSessionService.currentRole;
    final isOrganizer = role == MiloRole.organizer;
    final isPromoter = role == MiloRole.promoter;
    final isCustomer = role == MiloRole.customer;
    final hasWorkHub = isOrganizer || isPromoter;

    return Scaffold(
      backgroundColor: JhoomoTokens.surface,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Top Title 
            Text(
              'My Profile',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: JhoomoTokens.onSurface,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 16),

            // User Identity Card 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: JhoomoTokens.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: JhoomoTokens.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: JhoomoTokens.surfaceContainerLow,
                              child: const Icon(Icons.person, color: JhoomoTokens.primary),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                MiloSessionService.userNameNotifier.value.isNotEmpty
                                    ? MiloSessionService.userNameNotifier.value
                                    : 'Sahil',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: JhoomoTokens.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: JhoomoTokens.primary, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MiloSessionService.currentUserPhone.isNotEmpty
                              ? '+91 ${MiloSessionService.currentUserPhone}'
                              : '+91 98765 43210',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: JhoomoTokens.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verified JHOOMO Member',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: JhoomoTokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: JhoomoTokens.primary, size: 20),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (hasWorkHub) ...[
              Text(
                'My Work',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: JhoomoTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: JhoomoTokens.outline),
                ),
                child: Column(
                  children: [
                    if (isOrganizer)
                      _buildMenuItem(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Organizer Dashboard',
                        subtitle: 'Events, sales, check-ins & payout summary',
                        iconColor: const Color(0xFFE11D48),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
                          );
                        },
                      ),
                    if (isOrganizer && isPromoter)
                      const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                    if (isPromoter)
                      _buildMenuItem(
                        icon: Icons.insights_rounded,
                        title: 'Influencer Dashboard',
                        subtitle: 'Promo links, clicks, sales & earnings',
                        iconColor: const Color(0xFF9333EA),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PromoterDashboardScreen()),
                          );
                        },
                      ),
                    if (isPromoter)
                      const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                    if (isPromoter)
                      _buildMenuItem(
                        icon: Icons.add_photo_alternate_rounded,
                        title: 'Create Community Post',
                        subtitle: 'Post updates to the events community',
                        iconColor: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SingleCommunityHubScreen()),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (isCustomer) ...[
              Text(
                'Partner & Grow with JHOOMO',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: JhoomoTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: JhoomoTokens.outline),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.event_available_rounded,
                      title: 'List Your Show',
                      subtitle: 'Host events, sell tickets & manage gates DIY',
                      iconColor: const Color(0xFFE11D48),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BMSListYourShowPortalScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                    _buildMenuItem(
                      icon: Icons.campaign_rounded,
                      title: 'Become an Influencer / Promoter',
                      subtitle: 'Promote shows, get custom links & earn payouts',
                      iconColor: const Color(0xFF9333EA),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BecomeInfluencerPromoterScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Primary Account Actions 
            Text(
              'My Account',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: JhoomoTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: JhoomoTokens.outline),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Your Bookings & Purchases',
                    subtitle: 'View booking history, passes & purchases',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const YourBookingsScreen()));
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Personal Details',
                    subtitle: 'Update name, email & city',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Saved Events & Wishlist',
                    subtitle: 'Quick access to bookmarked events',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()));
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.shield_outlined,
                    title: 'Privacy & Safety Shield',
                    subtitle: 'Ghost mode, blocklist & DPDP controls',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyShieldScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Policies & Transparency
            Text(
              'Policies & Transparency',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: JhoomoTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: JhoomoTokens.outline),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.assignment_outlined,
                    title: 'Terms of Service',
                    subtitle: 'Ticketing, entry & platform usage rules',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPolicyScreen(
                            title: 'Terms of Service',
                            policyType: 'terms',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy & DPDP Notice',
                    subtitle: 'How your data is stored, used & protected',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPolicyScreen(
                            title: 'Privacy Policy',
                            policyType: 'privacy',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.currency_rupee_rounded,
                    title: 'Refund & Cancellation Policy',
                    subtitle: '100% refund rules & dispute resolution',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPolicyScreen(
                            title: 'Refund & Cancellation Policy',
                            policyType: 'refund_policy',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.storefront_outlined,
                    title: 'Organizer Terms & Payout Rules',
                    subtitle: 'Host responsibilities, fees & safe payouts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPolicyScreen(
                            title: 'Organizer Terms',
                            policyType: 'organizer_terms',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preferences & Support 
            Text(
              'App Settings',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: JhoomoTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: JhoomoTokens.outline),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.tune_rounded,
                    title: 'App Settings & Preferences',
                    subtitle: 'Notifications, language, legal & delete account',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notification Settings',
                    subtitle: 'Manage booking alerts & event reminders',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  const Divider(height: 1, color: JhoomoTokens.outlineVariant),
                  _buildMenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Centre & FAQs',
                    subtitle: 'Support chat, refunds & disputes',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dedicated Session & Logout Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFEE2E2)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                            const SizedBox(width: 10),
                            Text(
                              'Sign Out?',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: JhoomoTokens.onSurface),
                            ),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to log out of JHOOMO? You can easily sign back in anytime with your phone number.',
                          style: GoogleFonts.inter(fontSize: 13, color: JhoomoTokens.textSecondary, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await MiloAuthService.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const BMSPhoneLoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Out of Account',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Safely sign out from this device',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: JhoomoTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFF87171), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (iconColor ?? JhoomoTokens.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? JhoomoTokens.primary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor ?? JhoomoTokens.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11, color: JhoomoTokens.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: JhoomoTokens.textMuted),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }
}
