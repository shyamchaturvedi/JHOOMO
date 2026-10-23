import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

/// S-28 · Privacy Shield Controls Screen
/// Toggles: Ghost Mode, Incognito Attendance, Mutual Requests Only, Face-verified badge,
/// Data download, Blocked users, and Account deletion
class PrivacyShieldScreen extends StatefulWidget {
 const PrivacyShieldScreen({super.key});

 @override
 State<PrivacyShieldScreen> createState() => _PrivacyShieldScreenState();
}

class _PrivacyShieldScreenState extends State<PrivacyShieldScreen> {
 bool _ghostMode = false;
 bool _incognitoAttendance = false;
 bool _mutualRequestsOnly = true;
 bool _readReceipts = true;
 bool _showFaceBadge = true;

 final List<String> _blockedUsers = [
 'Rohan K. (Blocked on 12 Oct)',
 'Vikram S. (Blocked on 28 Sep)',
 ];

 void _unblock(int index) {
 final name = _blockedUsers[index];
 setState(() => _blockedUsers.removeAt(index));
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('$name unblocked'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 void _requestDataDownload() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Your data archive is being prepared. Download link will be sent to your registered email/SMS within 24h.'),
 backgroundColor: MiloColors.accentGreen,
 behavior: SnackBarBehavior.floating,
 ),
 );
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
 'Privacy Shield',
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
 // Banner
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: JhoomoTokens.primary.withValues(alpha: 0.2)),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.05),
 blurRadius: 14,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: JhoomoTokens.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(Icons.security_rounded, color: JhoomoTokens.primary, size: 24),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Total Consent Architecture',
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 15,
 fontWeight: FontWeight.w800,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Your phone number, exact GPS, and email are never revealed to anyone on Jhoomo.',
 style: GoogleFonts.inter(
 color: JhoomoTokens.textSecondary,
 fontSize: 12,
 height: 1.35,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 _buildSectionHeader('DISCOVERY & RADAR'),
 _buildSwitchTile(
 title: 'Ghost Mode',
 subtitle: 'Pause Radar presence everywhere. You will vanish from all attendee lists instantly.',
 value: _ghostMode,
 icon: Icons.visibility_off_rounded,
 onChanged: (v) => setState(() => _ghostMode = v),
 ),
 _buildSwitchTile(
 title: 'Incognito Attendance',
 subtitle: 'Never appear in public ticket-holder counts or attendee avatars for events.',
 value: _incognitoAttendance,
 icon: Icons.person_off_rounded,
 onChanged: (v) => setState(() => _incognitoAttendance = v),
 ),
 _buildSwitchTile(
 title: 'Mutual-Interest Requests Only',
 subtitle: 'Only attendees sharing ≥ 1 common interest can send you connection requests.',
 value: _mutualRequestsOnly,
 icon: Icons.handshake_outlined,
 onChanged: (v) => setState(() => _mutualRequestsOnly = v),
 ),

 const SizedBox(height: 20),
 _buildSectionHeader('CHAT & PROFILE SIGNALS'),
 _buildSwitchTile(
 title: 'Read Receipts',
 subtitle: 'Show double blue ticks when you read direct messages in chat.',
 value: _readReceipts,
 icon: Icons.done_all_rounded,
 onChanged: (v) => setState(() => _readReceipts = v),
 ),
 _buildSwitchTile(
 title: 'Show Face-Verified Badge',
 subtitle: 'Display green verified checkmark next to your name on Radar and chat.',
 value: _showFaceBadge,
 icon: Icons.verified_user_rounded,
 onChanged: (v) => setState(() => _showFaceBadge = v),
 ),

 const SizedBox(height: 20),
 _buildSectionHeader('BLOCKED USERS (${_blockedUsers.length})'),
 if (_blockedUsers.isEmpty)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Text(
 'No blocked users.',
 style: GoogleFonts.inter(color: JhoomoTokens.textMuted, fontSize: 13),
 ),
 )
 else
 ..._blockedUsers.asMap().entries.map((entry) {
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: JhoomoTokens.outline),
 ),
 child: Row(
 children: [
 const Icon(Icons.block, size: 18, color: JhoomoTokens.textMuted),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 entry.value,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
 ),
 ),
 TextButton(
 onPressed: () => _unblock(entry.key),
 child: Text(
 'Unblock',
 style: GoogleFonts.inter(color: JhoomoTokens.primary, fontSize: 12, fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 );
 }),

 const SizedBox(height: 20),
 _buildSectionHeader('DATA & COMPLIANCE (DPDP ACT 2023)'),
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
 color: JhoomoTokens.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: const Icon(Icons.download_rounded, color: JhoomoTokens.primary, size: 20),
 ),
 title: Text(
 'Download My Data Archive',
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 14, fontWeight: FontWeight.w700),
 ),
 subtitle: Text(
 'Receive a secure ZIP archive of all your tickets, messages, and profile logs.',
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11),
 ),
 trailing: const Icon(Icons.chevron_right, color: JhoomoTokens.textMuted),
 onTap: _requestDataDownload,
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

 Widget _buildSwitchTile({
 required String title,
 required String subtitle,
 required bool value,
 required IconData icon,
 required ValueChanged<bool> onChanged,
 }) {
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
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
 secondary: Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: (value ? JhoomoTokens.primary : JhoomoTokens.textMuted).withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, color: value ? JhoomoTokens.primary : JhoomoTokens.textMuted, size: 20),
 ),
 title: Text(
 title,
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 subtitle: Text(
 subtitle,
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11, height: 1.3),
 ),
 value: value,
 activeThumbColor: Colors.white,
 activeTrackColor: JhoomoTokens.primary,
 onChanged: onChanged,
 ),
 );
 }
}
