import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import 'bms_phone_login_screen.dart';

class OnboardingScreen extends StatefulWidget {
 const OnboardingScreen({super.key});

 @override
 State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
 final PageController _pageController = PageController();
 int _currentPage = 0;

 final List<Map<String, dynamic>> _slides = [
 {
 'type': 'ticket',
 'title': 'Grand Shows & Dandiya\nNights',
 'description':
 'Book passes for Dandiya nights, DJ concerts, Standup comedy, College fests & Kitty brunches with seat-tier pricing and instant QR entry.',
 },
 {
 'type': 'radar',
 'title': 'Consent-First Social Radar',
 'description':
 'Discover verified attendees going to your booked shows before you arrive. Form festival squads, carpools, or wave hello without ever exposing your phone number.',
 },
 {
 'type': 'gate',
 'title': 'Locked Gate Security &\nSafety',
 'description':
 'Enjoy screenshot-proof HMAC dynamic QR tickets, guaranteed escrow protection, and 1-tap SOS safety features for complete peace of mind at every venue.',
 },
 ];

 void _onNext() {
 if (_currentPage < _slides.length - 1) {
 _pageController.nextPage(
 duration: const Duration(milliseconds: 350),
 curve: Curves.easeInOutCubic,
 );
 } else {
 _navigateToLogin();
 }
 }

 void _navigateToLogin() {
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (context) => const BMSPhoneLoginScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 final isLast = _currentPage == _slides.length - 1;

 return Scaffold(
 backgroundColor: Colors.white,
 body: Stack(
 children: [
 // Soft Top Ambient Blush Gradient 
 Positioned(
 top: 0,
 left: 0,
 right: 0,
 height: 280,
 child: Container(
 decoration: const BoxDecoration(
 gradient: LinearGradient(
 colors: [
 Color(0xFFFFEFF2),
 Color(0xFFFFF8F9),
 Colors.white,
 ],
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 ),
 ),
 ),
 ),

 SafeArea(
 child: Column(
 children: [
 // Top Navigation (Skip / Log In) 
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 child: Align(
 alignment: Alignment.topRight,
 child: GestureDetector(
 onTap: _navigateToLogin,
 child: Text(
 isLast ? 'Log In' : 'Skip',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF1E293B),
 ),
 ),
 ),
 ),
 ),

 // Centered Onboarding Slide Carousel 
 Expanded(
 child: PageView.builder(
 controller: _pageController,
 onPageChanged: (idx) => setState(() => _currentPage = idx),
 itemCount: _slides.length,
 itemBuilder: (context, index) {
 final slide = _slides[index];
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 32),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 // Visual Graphic Badge Circle 
 _buildSlideGraphic(slide['type'] as String),
 const SizedBox(height: 48),

 // Slide Title 
 Text(
 slide['title'] as String,
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 24,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 letterSpacing: -0.6,
 height: 1.25,
 ),
 ),
 const SizedBox(height: 16),

 // Slide Description 
 Text(
 slide['description'] as String,
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w400,
 color: const Color(0xFF64748B),
 height: 1.55,
 ),
 ),
 ],
 ),
 );
 },
 ),
 ),

 // Page Indicator Dots 
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: List.generate(_slides.length, (idx) {
 final active = _currentPage == idx;
 return AnimatedContainer(
 duration: const Duration(milliseconds: 250),
 margin: const EdgeInsets.symmetric(horizontal: 3),
 width: active ? 24 : 6,
 height: 6,
 decoration: BoxDecoration(
 color: active ? JhoomoTokens.primary : const Color(0xFFE2E8F0),
 borderRadius: BorderRadius.circular(3),
 ),
 );
 }),
 ),
 const SizedBox(height: 32),

 // Bottom Action Button (Next → / Get Started ) 
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24),
 child: SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton(
 onPressed: _onNext,
 style: ElevatedButton.styleFrom(
 backgroundColor: JhoomoTokens.primary,
 foregroundColor: Colors.white,
 elevation: 8,
 shadowColor: JhoomoTokens.primary.withValues(alpha: 0.35),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 ),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text(
 isLast ? 'Get Started ' : 'Next',
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 if (!isLast) ...[
 const SizedBox(width: 8),
 const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
 ],
 ],
 ),
 ),
 ),
 ),

 if (isLast) ...[
 const SizedBox(height: 14),
 GestureDetector(
 onTap: _navigateToLogin,
 child: RichText(
 text: TextSpan(
 children: [
 TextSpan(
 text: 'Already have an account? ',
 style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
 ),
 TextSpan(
 text: 'Log In',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.primary,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 const SizedBox(height: 24),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // Visual Graphic Circle Renderer matching exact uploaded designs
 Widget _buildSlideGraphic(String type) {
 if (type == 'ticket') {
 return Container(
 width: 170,
 height: 170,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7F8),
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.08),
 blurRadius: 28,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Center(
 child: Stack(
 alignment: Alignment.center,
 children: [
 // VIP Ticket Graphic
 Container(
 width: 84,
 height: 48,
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 colors: [Color(0xFFE11D48), Color(0xFFFF3366)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(10),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.35),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Center(
 child: Container(
 width: 32,
 height: 8,
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.4),
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ),
 ),
 // Gold Star Overlay
 Positioned(
 bottom: 50,
 child: Container(
 padding: const EdgeInsets.all(4),
 decoration: const BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(color: Colors.black12, blurRadius: 6),
 ],
 ),
 child: const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 28),
 ),
 ),
 ],
 ),
 ),
 );
 } else if (type == 'radar') {
 return SizedBox(
 width: 220,
 height: 220,
 child: Stack(
 alignment: Alignment.center,
 children: [
 // Outer Concentric Sonar Rings
 Container(
 width: 210,
 height: 210,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFFFE0E8), width: 1),
 ),
 ),
 Container(
 width: 170,
 height: 170,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFFFCCD9), width: 1.2),
 ),
 ),
 Container(
 width: 130,
 height: 130,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(color: const Color(0xFFFFB3C6), width: 1.2),
 ),
 ),
 // Center Pink Beacon Box
 Container(
 width: 68,
 height: 68,
 decoration: BoxDecoration(
 gradient: const LinearGradient(
 colors: [Color(0xFFE11D48), Color(0xFFFF3366)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(18),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.35),
 blurRadius: 16,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Center(
 child: Container(
 width: 24,
 height: 24,
 decoration: const BoxDecoration(
 color: Colors.white,
 shape: BoxShape.circle,
 ),
 ),
 ),
 ),
 // Floating attendee avatars
 Positioned(
 top: 50,
 left: 60,
 child: Container(
 width: 28,
 height: 28,
 decoration: const BoxDecoration(color: Color(0xFFFFEEF2), shape: BoxShape.circle),
 child: const Icon(Icons.person, color: Color(0xFFE11D48), size: 16),
 ),
 ),
 Positioned(
 bottom: 54,
 right: 60,
 child: Container(
 width: 28,
 height: 28,
 decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
 child: const Icon(Icons.person, color: Color(0xFF10B981), size: 16),
 ),
 ),
 ],
 ),
 );
 } else {
 // Gate Security with QR and Shield Lock
 return Container(
 width: 180,
 height: 180,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF7F8),
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.08),
 blurRadius: 28,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Center(
 child: Stack(
 clipBehavior: Clip.none,
 children: [
 // Dark QR Scanner card
 Container(
 width: 86,
 height: 86,
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: const Color(0xFF1E293B),
 borderRadius: BorderRadius.circular(20),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.25),
 blurRadius: 14,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1E293B), size: 36),
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
 const SizedBox(width: 3),
 Text('VERIFIED', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white70)),
 ],
 ),
 ],
 ),
 ),
 // Crimson Lock Tag
 Positioned(
 bottom: -6,
 right: -8,
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: JhoomoTokens.primary,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.white, width: 2),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.4),
 blurRadius: 8,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
 ),
 ),
 ],
 ),
 ),
 );
 }
 }
}
