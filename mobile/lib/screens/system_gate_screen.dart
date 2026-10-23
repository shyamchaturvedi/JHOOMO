import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import 'organizer/qr_scanner_screen.dart';

/// S-50 · Force Update / Maintenance Screen
/// Handles:
/// 1. 'force_update': installed version < min_app_version with mandatory Play Store / App Store CTA
/// 2. 'maintenance': server undergoing scheduled upgrade with estimated completion time
/// Allows gate staff to continue scanning if allowStaffGate is enabled
class SystemGateScreen extends StatelessWidget {
 final String mode; // 'force_update' | 'maintenance'
 final String? message;
 final String? eta;
 final bool allowStaffGate;

 const SystemGateScreen({
 super.key,
 required this.mode,
 this.message,
 this.eta,
 this.allowStaffGate = true,
 });

 @override
 Widget build(BuildContext context) {
 final isForceUpdate = mode == 'force_update';

 return PopScope(
 canPop: false, // Prevent bypassing update/maintenance lock
 child: Scaffold(
 backgroundColor: MiloColors.bgSurface,
 body: SafeArea(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Spacer(),
 Container(
 width: 100,
 height: 100,
 decoration: BoxDecoration(
 color: (isForceUpdate ? MiloColors.primary : Colors.amber)
 .withValues(alpha: 0.15),
 shape: BoxShape.circle,
 border: Border.all(
 color: (isForceUpdate ? MiloColors.primary : Colors.amber)
 .withValues(alpha: 0.4),
 width: 2,
 ),
 ),
 child: Icon(
 isForceUpdate ? Icons.system_update_rounded : Icons.build_circle_rounded,
 color: isForceUpdate ? MiloColors.primaryLight : Colors.amber,
 size: 52,
 ),
 ),
 const SizedBox(height: 28),
 Text(
 isForceUpdate ? 'Update Required' : 'Under Scheduled Maintenance',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 22,
 fontWeight: FontWeight.w800,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 message ??
 (isForceUpdate
 ? 'A new version of Milo is required to continue enjoying live bookings, gate passes, and verified Social Radar features.'
 : 'Milo core services are currently undergoing an optimization update to ensure high-speed ticketing.'),
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 color: Colors.white70,
 fontSize: 14,
 height: 1.5,
 ),
 ),
 if (eta != null && !isForceUpdate) ...[
 const SizedBox(height: 16),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: Colors.white10,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 'Estimated back online: $eta',
 style: GoogleFonts.inter(
 color: Colors.amber,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 const Spacer(),

 // Primary CTA
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 onPressed: () {
 if (isForceUpdate) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Redirecting to Google Play Store / App Store...'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Checking service health... please wait.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: isForceUpdate ? MiloColors.primary : Colors.white24,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 elevation: 0,
 ),
 child: Text(
 isForceUpdate ? 'Update Milo on Play Store' : 'Check Status Again',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
 ),
 ),
 ),

 // Staff gate bypass if allowed
 if (!isForceUpdate && allowStaffGate) ...[
 const SizedBox(height: 14),
 TextButton.icon(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const QRScannerScreen()),
 );
 },
 icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: MiloColors.accentGreen),
 label: Text(
 'Continue Gate Scanning (Staff Mode)',
 style: GoogleFonts.inter(
 color: MiloColors.accentGreen,
 fontSize: 13,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 const SizedBox(height: 10),
 ],
 ),
 ),
 ),
 ),
 );
 }
}
