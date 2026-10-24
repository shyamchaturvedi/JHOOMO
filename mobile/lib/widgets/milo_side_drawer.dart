import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/milo_session_service.dart';
import '../services/milo_auth_service.dart';
import '../services/payment_approval_service.dart';
import '../theme/milo_theme.dart';
import '../screens/my_tickets_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/legal_policy_screen.dart';
import '../screens/auth/login_router.dart';
import '../screens/auth/phone_login_screen.dart';
import '../screens/community/single_community_hub_screen.dart';
import '../screens/organizer/list_your_show_screen.dart';
import '../screens/promoter/become_influencer_promoter_screen.dart';
import '../screens/promoter/promoter_dashboard_screen.dart';
import 'app_logo.dart';

class MiloSideDrawer extends StatelessWidget {
 final void Function(int)? onSelectTab;
 final String city;

 const MiloSideDrawer({super.key, this.onSelectTab, this.city = 'Lucknow'});

 void _closeThen(BuildContext context, Widget screen) {
 Navigator.of(context).pop();
 Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
 }

 void _closeThenTab(BuildContext context, int index) {
 Navigator.of(context).pop();
 onSelectTab?.call(index);
 }

 @override
 Widget build(BuildContext context) {
 final role = MiloSessionService.currentRole;
 final name = MiloSessionService.currentUserName.isNotEmpty
 ? MiloSessionService.currentUserName
 : 'Jhoomo Guest';
 final phone = MiloSessionService.currentUserPhone;
 final isOrganizer = role == MiloRole.organizer;
 final isPromoter = role == MiloRole.promoter;
 final isCustomer = role == MiloRole.customer;
 final ticketCount = PaymentApprovalService.instance.userTickets.length;

 return Drawer(
 backgroundColor: MiloColors.bg,
 width: MediaQuery.of(context).size.width * 0.82,
 child: SafeArea(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildHeader(context, name, phone, city),
 Expanded(
 child: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 children: [
 _sectionLabel('Browse'),
 _tile(
 context,
 icon: Icons.home_rounded,
 title: 'Home',
 onTap: () => _closeThenTab(context, 0),
 ),
 _tile(
 context,
 icon: Icons.explore_rounded,
 title: 'Explore Events',
 onTap: () => _closeThenTab(context, 1),
 ),
 _tile(
 context,
 icon: Icons.hub_rounded,
 title: 'Community Feed',
 onTap: () => _closeThenTab(context, 2),
 ),
 const SizedBox(height: 6),
 _sectionLabel('My Account'),
 _tile(
 context,
 icon: Icons.confirmation_number_rounded,
 title: 'My Tickets',
 trailing: ticketCount > 0 ? '$ticketCount' : null,
 onTap: () => _closeThen(context, const MyTicketsScreen()),
 ),
 _tile(
 context,
 icon: Icons.favorite_rounded,
 title: 'My Wishlist',
 onTap: () => _closeThen(context, const WishlistScreen()),
 ),
 _tile(
 context,
 icon: Icons.notifications_rounded,
 title: 'Notifications',
 onTap: () => _closeThen(context, const NotificationsScreen()),
 ),
 _tile(
 context,
 icon: Icons.shield_rounded,
 title: 'Profile & Safety',
 onTap: () => _closeThenTab(context, 4),
 ),
 const SizedBox(height: 6),
 if (isCustomer) ...[
 _sectionLabel('Partners'),
 _tile(
 context,
 icon: Icons.campaign_rounded,
 title: 'List Your Show',
 subtitle: 'Host events & earn as an organizer',
 accent: true,
 onTap: () => _closeThen(context, const ListYourShowScreen()),
 ),
 _tile(
 context,
 icon: Icons.campaign_rounded,
 title: 'Become an Influencer',
 subtitle: 'Promote shows & earn from referral links',
 onTap: () => _closeThen(context, const BecomeInfluencerPromoterScreen()),
 ),
 ],
 if (isOrganizer) ...[
 _sectionLabel('My Work'),
 _tile(
 context,
 icon: Icons.dashboard_customize_rounded,
 title: 'Organizer Dashboard',
 onTap: () {
 Navigator.of(context).pop();
 LoginRouter.go(context, MiloRole.organizer);
 },
 ),
 ],
 if (isPromoter) ...[
 _sectionLabel('My Work'),
 _tile(
 context,
 icon: Icons.insights_rounded,
 title: 'Influencer Dashboard',
 subtitle: 'Links, clicks, sales & earnings',
 onTap: () => _closeThen(context, const PromoterDashboardScreen()),
 ),
 _tile(
 context,
 icon: Icons.add_photo_alternate_rounded,
 title: 'Create Community Post',
 onTap: () => _closeThen(context, const SingleCommunityHubScreen()),
 ),
 ],
 _tile(
 context,
 icon: Icons.support_agent_rounded,
 title: 'Help & Support',
 onTap: () => _closeThen(context, const LegalPolicyScreen(title: 'Help & Support', policyType: 'refund_policy')),
 ),
 _tile(
 context,
 icon: Icons.description_rounded,
 title: 'Terms & Privacy',
 onTap: () => _closeThen(context, const LegalPolicyScreen(title: 'Terms & Privacy', policyType: 'terms')),
 ),
 const SizedBox(height: 10),
 _logoutTile(context),
 _switchAccountTile(context),
 const SizedBox(height: 16),
 Center(
 child: Column(
 children: [
 const MiloAppLogo(size: 28, showText: true, showTagline: false),
 const SizedBox(height: 6),
 Text(
 'v1.0.0 • Made in India ',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildHeader(BuildContext context, String name, String phone, String city) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
 decoration: const BoxDecoration(
 gradient: MiloGradients.darkCard,
 border: Border(bottom: BorderSide(color: MiloColors.border)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 52,
 height: 52,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: MiloGradients.primaryBrand,
 boxShadow: [
 BoxShadow(color: MiloColors.primaryGlow, blurRadius: 14),
 ],
 ),
 child: Center(
 child: Text(
 name.isNotEmpty ? name.characters.first.toUpperCase() : 'M',
 style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
 ),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 name,
 style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 if (phone.isNotEmpty) ...[
 const SizedBox(height: 2),
 Text(
 '+91 $phone',
 style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary),
 ),
 ],
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 children: [
 const Icon(Icons.location_on_rounded, size: 15, color: MiloColors.primaryLight),
 const SizedBox(width: 6),
 Text(
 '$city, India',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textPrimary),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.18),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 MiloSessionService.getRoleDisplayName(MiloSessionService.currentRole).split(' ').first,
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.primaryLight),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _sectionLabel(String label) {
 return Padding(
 padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
 child: Text(
 label.toUpperCase(),
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: MiloColors.textMuted, letterSpacing: 1.2),
 ),
 );
 }

 Widget _tile(
 BuildContext context, {
 required IconData icon,
 required String title,
 String? subtitle,
 String? trailing,
 bool accent = false,
 required VoidCallback onTap,
 }) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 2),
 child: Material(
 color: accent ? MiloColors.primary.withValues(alpha: 0.14) : Colors.transparent,
 borderRadius: BorderRadius.circular(14),
 child: InkWell(
 borderRadius: BorderRadius.circular(14),
 onTap: onTap,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 child: Row(
 children: [
 Icon(icon, size: 20, color: accent ? MiloColors.primaryLight : MiloColors.textSecondary),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: accent ? FontWeight.w800 : FontWeight.w700,
 color: accent ? MiloColors.primaryLight : MiloColors.textPrimary,
 ),
 ),
 if (subtitle != null) ...[
 const SizedBox(height: 1),
 Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 ],
 ],
 ),
 ),
 if (trailing != null)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.rose,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(trailing, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
 )
 else if (accent)
 const Icon(Icons.arrow_forward_rounded, size: 16, color: MiloColors.primaryLight)
 else
 const Icon(Icons.chevron_right_rounded, size: 18, color: MiloColors.textMuted),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _logoutTile(BuildContext context) {
 return _tile(
 context,
 icon: Icons.logout_rounded,
 title: 'Logout',
 onTap: () async {
 Navigator.of(context).pop();
 await MiloAuthService.instance.signOut();
 await MiloSessionService.logout();
 if (!context.mounted) return;
 Navigator.pushAndRemoveUntil(
 context,
 MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
 (route) => false,
 );
 },
 );
 }

 Widget _switchAccountTile(BuildContext context) {
 return _tile(
 context,
 icon: Icons.switch_account_rounded,
 title: 'Switch Account',
 onTap: () async {
 Navigator.of(context).pop();
 await MiloAuthService.instance.signOut();
 await MiloSessionService.logout();
 if (!context.mounted) return;
 Navigator.pushAndRemoveUntil(
 context,
 MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
 (route) => false,
 );
 },
 );
 }
}
