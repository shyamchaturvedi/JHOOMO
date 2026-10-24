import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import 'bms_do_it_yourself_screen.dart';

/// S-41 · KYC Status & Resubmission Screen
/// Vertical timeline: Submitted -> Automated checks -> Jhoomo review -> Approved
/// Handles 'needs_info' with flagged fields, admin remarks, and edit & resubmit CTA
class KycStatusScreen extends StatefulWidget {
 final String status; // 'submitted', 'auto_verified', 'approved', 'needs_info', 'rejected'

 const KycStatusScreen({
 super.key,
 this.status = 'auto_verified',
 });

 @override
 State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
 @override
 Widget build(BuildContext context) {
 final isAutoVerified = widget.status == 'auto_verified';
 final isApproved = widget.status == 'approved';
 final isNeedsInfo = widget.status == 'needs_info';

 return Scaffold(
 backgroundColor: MiloColors.bgSurface,
 appBar: AppBar(
 backgroundColor: MiloColors.bgSurface,
 elevation: 0,
 title: Text(
 'KYC Verification Status',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 body: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
 children: [
 // Header summary badge
 Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 isApproved || isAutoVerified
 ? MiloColors.accentGreen.withValues(alpha: 0.15)
 : Colors.amber.withValues(alpha: 0.15),
 Colors.black26,
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isApproved || isAutoVerified
 ? MiloColors.accentGreen.withValues(alpha: 0.4)
 : Colors.amber.withValues(alpha: 0.4),
 ),
 ),
 child: Row(
 children: [
 Icon(
 isApproved || isAutoVerified
 ? Icons.verified_user_rounded
 : Icons.hourglass_top_rounded,
 color: isApproved || isAutoVerified ? MiloColors.accentGreen : Colors.amber,
 size: 36,
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isApproved
 ? 'KYC Fully Approved (L2)'
 : (isAutoVerified
 ? 'Auto-Verified (Drafts Unlocked)'
 : 'Review in Progress'),
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 isApproved
 ? 'Your bank account is linked. All ticket payouts and live sales enabled.'
 : (isAutoVerified
 ? 'PAN & Bank penny-drop matched! You can create events. Payouts unlock in 24h.'
 : 'Our compliance team is verifying legal documentation.'),
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.3),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 28),

 Text(
 'VERIFICATION PROGRESS TIMELINE',
 style: GoogleFonts.inter(
 color: Colors.white38,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 ),
 ),
 const SizedBox(height: 16),

 _buildTimelineStep(
 title: '1. KYC Details Submitted',
 subtitle: 'PAN, POC contact, and bank account details received',
 isDone: true,
 isCurrent: false,
 ),
 _buildTimelineStep(
 title: '2. Automated System Checks',
 subtitle: 'PAN database matching & ₹1 bank penny-drop verification',
 isDone: true,
 isCurrent: isAutoVerified && !isApproved,
 ),
 _buildTimelineStep(
 title: '3. Jhoomo Operations & Legal Review (L2)',
 subtitle: 'Final compliance sign-off for safe payout gateway',
 isDone: isApproved,
 isCurrent: isAutoVerified && !isApproved,
 ),
 _buildTimelineStep(
 title: '4. Fully Unlocked Organizer',
 subtitle: 'Instant T+1 ticket revenue payouts deposited directly to HDFC Bank',
 isDone: isApproved,
 isCurrent: false,
 isLast: true,
 ),

 const SizedBox(height: 28),

 // Action button
 if (isNeedsInfo) ...[
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.redAccent.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Remark from Compliance Desk:',
 style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 4),
 Text(
 'Name on PAN card slightly differs from beneficiary account name. Please upload official business proof or updated cancelled cheque.',
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 SizedBox(
 width: double.infinity,
 height: 48,
 child: ElevatedButton.icon(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const BMSDoItYourselfScreen()),
 );
 },
 icon: const Icon(Icons.edit_note_rounded),
 label: const Text('Edit & Resubmit Details'),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 ] else ...[
 SizedBox(
 width: double.infinity,
 height: 48,
 child: OutlinedButton(
 onPressed: () => Navigator.pop(context),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white,
 side: const BorderSide(color: Colors.white24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 child: const Text('Back to Organizer Studio'),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildTimelineStep({
 required String title,
 required String subtitle,
 required bool isDone,
 required bool isCurrent,
 bool isLast = false,
 }) {
 return Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Column(
 children: [
 Container(
 width: 24,
 height: 24,
 decoration: BoxDecoration(
 color: isDone
 ? MiloColors.accentGreen
 : (isCurrent ? Colors.amber : Colors.white12),
 shape: BoxShape.circle,
 ),
 child: Icon(
 isDone ? Icons.check : (isCurrent ? Icons.sync : Icons.circle),
 color: Colors.white,
 size: 14,
 ),
 ),
 if (!isLast)
 Container(
 width: 2,
 height: 48,
 color: isDone ? MiloColors.accentGreen.withValues(alpha: 0.5) : Colors.white12,
 ),
 ],
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: GoogleFonts.inter(
 color: isDone || isCurrent ? Colors.white : Colors.white38,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 subtitle,
 style: GoogleFonts.inter(
 color: isDone || isCurrent ? Colors.white60 : Colors.white24,
 fontSize: 12,
 ),
 ),
 const SizedBox(height: 16),
 ],
 ),
 ),
 ],
 );
 }
}
