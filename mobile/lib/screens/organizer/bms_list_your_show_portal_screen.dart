import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/milo_session_service.dart';
import 'bms_do_it_yourself_screen.dart';
import 'organizer_dashboard_screen.dart';
import 'kyc_status_screen.dart';

class BMSListYourShowPortalScreen extends StatelessWidget {
 const BMSListYourShowPortalScreen({super.key});

 bool get _isAlreadyOrganizer =>
 MiloSessionService.currentRole == MiloRole.organizer;

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 backgroundColor: Colors.white,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
 onPressed: () => Navigator.pop(context),
 ),
 title: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFE11D48),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 'my',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text(
 'Do It Yourself',
 style: GoogleFonts.inter(
 fontSize: 18,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 ),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () {
 if (_isAlreadyOrganizer) {
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
 );
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const BMSDoItYourselfScreen()),
 );
 }
 },
 child: Text(
 _isAlreadyOrganizer ? 'Dashboard' : 'Sign in',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF2563EB),
 ),
 ),
 ),
 const SizedBox(width: 8),
 ],
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
 children: [
 // Hero Heading
 Text(
 'Benefits of using Do It Yourself our\nnew event management tool',
 style: GoogleFonts.inter(
 fontSize: 20,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 height: 1.35,
 ),
 ),
 const SizedBox(height: 28),

 // Benefit 1: Quick & Easy Registration (BMS Screen 4 & 5 Exact)
 _buildFeatureCard(
 icon: Icons.laptop_chromebook_rounded,
 badgeColor: const Color(0xFFE11D48),
 title: 'Quick & easy registration',
 description:
 'Complete your registration with just your PAN card and bank details.',
 ),
 const SizedBox(height: 24),

 // Benefit 2: Take events live superfast
 _buildFeatureCard(
 icon: Icons.timer_outlined,
 badgeColor: const Color(0xFF2563EB),
 title: 'Take your events live superfast!',
 description:
 'Publish your event within just 15 minutes! Add event details, dates and ticket and BAM! Your event is ready.',
 ),
 const SizedBox(height: 24),

 // Benefit 3: Monitor analytics & insights
 _buildFeatureCard(
 icon: Icons.analytics_outlined,
 badgeColor: const Color(0xFF059669),
 title: 'Monitor analytics & insights',
 description:
 'Track event sales, daily ticketing, get daily insights and more in real time.',
 ),
 const SizedBox(height: 24),

 // Benefit 4: Dedicated Gate Staff Scanner
 _buildFeatureCard(
 icon: Icons.qr_code_scanner_rounded,
 badgeColor: const Color(0xFFD97706),
 title: 'Add & delegate gate staff',
 description:
 'Assign gate scanners for each entrance with a 6-digit PIN. Real-time ticket validation with duplicate entry prevention.',
 ),

 const SizedBox(height: 36),

 // Primary CTA
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB), // BMS Blue
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 ),
 onPressed: () {
 if (_isAlreadyOrganizer) {
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
 );
 } else {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const BMSDoItYourselfScreen()),
 );
 }
 },
 child: Text(
 _isAlreadyOrganizer
 ? 'Go to Organizer Dashboard '
 : 'Get Started with DIY Portal →',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 ),
 ),
 const SizedBox(height: 12),

 // Secondary KYC Status CTA
 SizedBox(
 width: double.infinity,
 height: 48,
 child: OutlinedButton.icon(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const KycStatusScreen()),
 );
 },
 icon: const Icon(Icons.history_rounded, size: 18, color: Color(0xFF2563EB)),
 label: Text(
 'Check KYC Verification Status',
 style: GoogleFonts.inter(
 color: const Color(0xFF2563EB),
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 const SizedBox(height: 16),

 Center(
 child: Text(
 'Incase of any query, please write to\nbd@jhoomo.app',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 12,
 color: const Color(0xFF64748B),
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildFeatureCard({
 required IconData icon,
 required Color badgeColor,
 required String title,
 required String description,
 }) {
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Column(
 children: [
 Container(
 width: 60,
 height: 60,
 decoration: BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Icon(icon, color: badgeColor, size: 30),
 ),
 const SizedBox(height: 14),
 Text(
 title,
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 description,
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 13,
 color: const Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 ],
 ),
 );
 }
}
