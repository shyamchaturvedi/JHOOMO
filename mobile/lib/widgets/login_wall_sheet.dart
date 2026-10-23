import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../screens/auth/bms_phone_login_screen.dart';

/// S-07 · Login Wall Bottom Sheet
/// Shown when a Guest user taps a gated action (Book, Wishlist, Radar, Chat, Profile)
/// Stores pendingAction and resumes after auth completes.
class LoginWallSheet extends StatelessWidget {
 final String? pendingAction; // e.g. 'book:evt_123:tier_9'
 final String? message;

 const LoginWallSheet({
 super.key,
 this.pendingAction,
 this.message,
 });

 static Future<void> show(
 BuildContext context, {
 String? pendingAction,
 String? message,
 }) {
 return showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (_) => LoginWallSheet(
 pendingAction: pendingAction,
 message: message,
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Container(
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
 border: Border.all(color: MiloColors.glassBorder, width: 1.2),
 ),
 child: SafeArea(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Drag handle
 Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: MiloColors.textMuted.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 const SizedBox(height: 24),

 // Lock icon with glow
 Container(
 width: 72,
 height: 72,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: const LinearGradient(
 colors: [Color(0xFFE53945), Color(0xFF8B1019)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 boxShadow: [
 BoxShadow(
 color: MiloColors.primary.withValues(alpha: 0.45),
 blurRadius: 24,
 spreadRadius: 2,
 ),
 ],
 ),
 child: const Icon(
 Icons.lock_rounded,
 color: Colors.white,
 size: 32,
 ),
 ),
 const SizedBox(height: 16),

 Text(
 'Login to continue',
 style: GoogleFonts.outfit(
 fontSize: 22,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 message ?? 'Create an account or log in to\naccess tickets, events & people.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 14,
 color: MiloColors.textSecondary,
 height: 1.5,
 ),
 ),
 const SizedBox(height: 28),

 // Feature pills
 Wrap(
 spacing: 8,
 runSpacing: 8,
 alignment: WrapAlignment.center,
 children: [
 _FeaturePill(icon: Icons.confirmation_number_rounded, label: 'Book Tickets'),
 _FeaturePill(icon: Icons.people_rounded, label: 'Meet People'),
 _FeaturePill(icon: Icons.favorite_rounded, label: 'Wishlist'),
 _FeaturePill(icon: Icons.chat_bubble_rounded, label: 'Chat'),
 ],
 ),
 const SizedBox(height: 28),

 // Login with OTP CTA
 SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton.icon(
 onPressed: () {
 Navigator.pop(context);
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => BMSPhoneLoginScreen(pendingAction: pendingAction),
 ),
 );
 },
 icon: const Icon(Icons.phone_android_rounded, size: 20),
 label: Text(
 'Login with OTP',
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14),
 ),
 elevation: 0,
 ),
 ),
 ),
 const SizedBox(height: 12),

 // Google sign in
 SizedBox(
 width: double.infinity,
 height: 54,
 child: OutlinedButton.icon(
 onPressed: () {
 Navigator.pop(context);
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => BMSPhoneLoginScreen(pendingAction: pendingAction),
 ),
 );
 },
 icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
 label: Text(
 'Continue with Google',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w600,
 ),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: MiloColors.textPrimary,
 side: BorderSide(
 color: MiloColors.textMuted.withValues(alpha: 0.4),
 ),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14),
 ),
 ),
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'By continuing, you agree to our Terms & Privacy Policy',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 11,
 color: MiloColors.textMuted,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}

class _FeaturePill extends StatelessWidget {
 final IconData icon;
 final String label;

 const _FeaturePill({required this.icon, required this.label});

 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder, width: 1),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(icon, size: 14, color: MiloColors.primaryLight),
 const SizedBox(width: 5),
 Text(
 label,
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: MiloColors.textSecondary,
 ),
 ),
 ],
 ),
 );
 }
}
