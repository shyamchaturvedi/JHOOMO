import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/milo_session_service.dart';
import '../../theme/milo_theme.dart';
import 'bms_list_your_show_portal_screen.dart';
import 'organizer_dashboard_screen.dart';

class ListYourShowScreen extends StatefulWidget {
 const ListYourShowScreen({super.key});

 @override
 State<ListYourShowScreen> createState() => _ListYourShowScreenState();
}

class _ListYourShowScreenState extends State<ListYourShowScreen> {
 bool _activating = false;

 bool get _isOrganizer => MiloSessionService.currentRole == MiloRole.organizer;

 Future<void> _becomeOrganizer() async {
 if (_activating) return;
 setState(() => _activating = true);

 await Future<void>.delayed(const Duration(milliseconds: 150));

 if (!mounted) return;
 setState(() => _activating = false);

 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const BMSListYourShowPortalScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 title: Text(
 'List Your Show',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 18),
 ),
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
 children: [
 _buildHero(),
 const SizedBox(height: 24),
 _sectionTitle('Why host on Jhoomo? '),
 const SizedBox(height: 12),
 _benefitCard(
 Icons.payments_rounded,
 MiloColors.emerald,
 'Instant settlements',
 'Collect payments via UPI / self gateway and get secure safe-payment payouts with transparent 5% platform fee.',
 ),
 _benefitCard(
 Icons.qr_code_scanner_rounded,
 MiloColors.cyan,
 'QR gate check-in',
 'Assign gate staff with secure passcodes. Every ticket is scanned and validated at the gate in real time.',
 ),
 _benefitCard(
 Icons.trending_up_rounded,
 MiloColors.amber,
 'Sell more with promoters',
 'Turn on influencer referral links and pay only on real confirmed sales — zero upfront cost.',
 ),
 _benefitCard(
 Icons.campaign_rounded,
 MiloColors.primaryLight,
 'Reach local audiences',
 'Your show is featured on the Jhoomo Explore feed to thousands of nearby attendees.',
 ),
 const SizedBox(height: 24),
 _sectionTitle('How it works '),
 const SizedBox(height: 12),
 _step(1, 'Complete organizer verification', 'PAN, business email and bank account checks are done by Jhoomo KYC before hosting.'),
 _step(2, 'List your show', 'Add title, venue, date and tiered ticket pricing.'),
 _step(3, 'Add your gate staff', 'Assign staff and hand them their unique gate passcode.'),
 _step(4, 'Go live & get paid', 'Track sales in real time and receive settlements.'),
 const SizedBox(height: 28),
 SizedBox(
 width: double.infinity,
 height: 56,
 child: ElevatedButton.icon(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 elevation: 6,
 shadowColor: MiloColors.primaryGlow,
 ),
 onPressed: _activating ? null : (_isOrganizer ? () {
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
 );
 } : _becomeOrganizer),
 icon: _activating
 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
 : Icon(
 _isOrganizer ? Icons.dashboard_customize_rounded : Icons.add_business_rounded,
 color: Colors.white,
 size: 20,
 ),
 label: Text(
 _isOrganizer ? 'Open Organizer Dashboard' : 'Become an Organizer ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15),
 ),
 ),
 ),
 const SizedBox(height: 12),
 Center(
 child: Text(
 'You can always switch back to the customer app anytime.',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildHero() {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 gradient: MiloGradients.primaryBrand,
 borderRadius: BorderRadius.circular(24),
 boxShadow: [
 BoxShadow(color: MiloColors.primaryGlow, blurRadius: 24, offset: const Offset(0, 8)),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 'FOR ORGANIZERS & HOSTS',
 style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
 ),
 ),
 const SizedBox(height: 14),
 Text(
 'Host your next\nbig show on Jhoomo ',
 style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
 ),
 const SizedBox(height: 10),
 Text(
 'Dandiya nights, concerts, comedy, college fests — list your event and manage everything from bookings to gate entry.',
 style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.4),
 ),
 ],
 ),
 );
 }

 Widget _sectionTitle(String title) {
 return Text(
 title,
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 );
 }

 Widget _benefitCard(IconData icon, Color color, String title, String body) {
 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(9),
 decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
 child: Icon(icon, color: color, size: 20),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 3),
 Text(body, style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.4)),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _step(int n, String title, String body) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 14),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 width: 28,
 height: 28,
 decoration: const BoxDecoration(color: MiloColors.primary, shape: BoxShape.circle),
 child: Center(
 child: Text('$n', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 2),
 Text(body, style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted, height: 1.4)),
 ],
 ),
 ),
 ],
 ),
 );
 }
}
