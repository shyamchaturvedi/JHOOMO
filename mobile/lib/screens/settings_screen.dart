import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../services/milo_auth_service.dart';
import 'legal_policy_screen.dart';
import 'auth/bms_phone_login_screen.dart';

/// S-35 · Settings & Account Screen
/// Notification preferences, permissions, language, terms/privacy, logout, and DPDP 30-day account deletion flow
class SettingsScreen extends StatefulWidget {
 const SettingsScreen({super.key});

 @override
 State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
 bool _notifyBookings = true;
 bool _notifyReminders = true;
 bool _notifyRadar = true;
 bool _notifyPromos = false;

 void _showDeleteAccountDialog() {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 side: const BorderSide(color: Colors.redAccent, width: 1.2),
 ),
 title: Row(
 children: [
 const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
 const SizedBox(width: 10),
 Text(
 'Delete Milo Account',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 17,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 content: Text(
 'Under DPDP Act 2023, your account will enter a 30-day grace period before permanent erasure. Any active tickets must be cancelled or refunded prior to deletion.\n\nAre you sure you wish to proceed?',
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
 ),
 ElevatedButton(
 onPressed: () {
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Account scheduled for deletion. 30-day grace countdown initiated.'),
 backgroundColor: Colors.redAccent,
 behavior: SnackBarBehavior.floating,
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.redAccent,
 foregroundColor: Colors.white,
 ),
 child: const Text('Confirm Deletion'),
 ),
 ],
 ),
 );
 }

  void _logout() async {
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
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BMSPhoneLoginScreen()),
        (route) => false,
      );
    }
  }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: JhoomoTokens.surface,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back_rounded, color: JhoomoTokens.onSurface),
 onPressed: () => Navigator.pop(context),
 ),
 title: Text(
 'Settings & Account',
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 18,
 fontWeight: FontWeight.w800,
 ),
 ),
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 children: [
 _buildSectionHeader('PUSH NOTIFICATIONS'),
 _buildSwitch(
 'Booking Confirmations & Tickets',
 'Instant updates on ticket issuance and gate entry',
 _notifyBookings,
 (v) => setState(() => _notifyBookings = v),
 ),
 _buildSwitch(
 'Event Reminders',
 'Alerts at 24h and 2h before the event starts',
 _notifyReminders,
 (v) => setState(() => _notifyReminders = v),
 ),
 _buildSwitch(
 'Radar Matches & Hellos',
 'When fellow attendees match or send you a hello',
 _notifyRadar,
 (v) => setState(() => _notifyRadar = v),
 ),
 _buildSwitch(
 'Special Offers & Festival Highlights',
 'Curated discounts on Garba, DJ nights, and shows',
 _notifyPromos,
 (v) => setState(() => _notifyPromos = v),
 ),

 const SizedBox(height: 20),
 _buildSectionHeader('PREFERENCES & PERMISSIONS'),
 _buildListTile(
 icon: Icons.language_rounded,
 title: 'Language',
 subtitle: 'English (UK / India)',
 onTap: () {},
 ),
 _buildListTile(
 icon: Icons.location_on_outlined,
 title: 'Location Permissions',
 subtitle: 'Coarse city level active',
 onTap: () {},
 ),

 const SizedBox(height: 20),
 _buildSectionHeader('LEGAL & POLICIES'),
 _buildListTile(
 icon: Icons.description_outlined,
 title: 'Terms of Service',
 subtitle: 'Customer ticketing and gate contract',
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const LegalPolicyScreen(
 title: 'Terms of Service',
 policyType: 'terms',
 ),
 ),
 ),
 ),
 _buildListTile(
 icon: Icons.privacy_tip_outlined,
 title: 'Privacy Policy & DPDP Notice',
 subtitle: 'Data processing and retention disclosures',
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => const LegalPolicyScreen(
 title: 'Privacy Policy',
 policyType: 'privacy',
 ),
 ),
 ),
 ),

 const SizedBox(height: 20),
 _buildSectionHeader('SESSION'),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: JhoomoTokens.outline),
 ),
 child: Material(
 color: Colors.transparent,
 child: ListTile(
 leading: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.orange.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.logout_rounded, color: Colors.orange, size: 20),
 ),
 title: Text(
 'Sign Out',
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 14, fontWeight: FontWeight.w700),
 ),
 subtitle: Text(
 'You can sign back in anytime with OTP',
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11),
 ),
 onTap: _logout,
 ),
 ),
 ),
 const SizedBox(height: 10),
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
 ),
 child: Material(
 color: Colors.transparent,
 child: ListTile(
 leading: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Colors.redAccent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
 ),
 title: Text(
 'Delete Account',
 style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700),
 ),
 subtitle: Text(
 'Permanent account erasure with 30-day grace',
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11),
 ),
 onTap: _showDeleteAccountDialog,
 ),
 ),
 ),
 const SizedBox(height: 36),
 ],
 ),
 );
 }

 Widget _buildSectionHeader(String title) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: Text(
 title,
 style: GoogleFonts.inter(
 color: JhoomoTokens.textSecondary,
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.1,
 ),
 ),
 );
 }

 Widget _buildSwitch(String title, String subtitle, bool val, ValueChanged<bool> onChanged) {
 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: JhoomoTokens.outline),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.02),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: SwitchListTile(
 contentPadding: EdgeInsets.zero,
 title: Text(
 title,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
 ),
 subtitle: Text(
 subtitle,
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11),
 ),
 value: val,
 activeThumbColor: Colors.white,
 activeTrackColor: JhoomoTokens.primary,
 onChanged: onChanged,
 ),
 );
 }

 Widget _buildListTile({
 required IconData icon,
 required String title,
 required String subtitle,
 required VoidCallback onTap,
 }) {
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: JhoomoTokens.outline),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.02),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Material(
 color: Colors.transparent,
 child: ListTile(
 leading: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: JhoomoTokens.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, color: JhoomoTokens.primary, size: 20),
 ),
 title: Text(
 title,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
 ),
 subtitle: Text(
 subtitle,
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11),
 ),
 trailing: const Icon(Icons.chevron_right, color: JhoomoTokens.textMuted, size: 20),
 onTap: onTap,
 ),
 ),
 );
 }
}
