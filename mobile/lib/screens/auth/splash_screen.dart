import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import 'onboarding_screen.dart';

import '../../services/milo_session_service.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_db_service.dart';
import '../../services/payment_approval_service.dart';
import 'login_router.dart';

class SplashScreen extends StatefulWidget {
 const SplashScreen({super.key});

 @override
 State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
 late AnimationController _logoController;
 late Animation<double> _logoScale;
 late Animation<double> _logoOpacity;
 late Animation<double> _taglineSlide;
 late Animation<double> _taglineOpacity;

 late AnimationController _glowController;
 late Animation<double> _glowRadius;
 late Animation<double> _sonarRing;
 late Animation<double> _sonarOpacity;

 @override
 void initState() {
 super.initState();

 // 1. Logo scale & entrance choreography
 _logoController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1400),
 );

 _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
 CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
 );

 _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
 );

 _taglineSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
 CurvedAnimation(parent: _logoController, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
 );

 _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(parent: _logoController, curve: const Interval(0.5, 0.95, curve: Curves.easeIn)),
 );

 // 2. Ambient ambient sonar pulse
 _glowController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 2200),
 )..repeat();

 _glowRadius = Tween<double>(begin: 0.9, end: 1.25).animate(
 CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
 );

 _sonarRing = Tween<double>(begin: 0.8, end: 2.1).animate(
 CurvedAnimation(parent: _glowController, curve: Curves.easeOutQuad),
 );

 _sonarOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
 CurvedAnimation(parent: _glowController, curve: Curves.easeOutQuad),
 );

 _logoController.forward();
 _navigateNext();
 }

 Future<void> _navigateNext() async {
 await Future.delayed(const Duration(milliseconds: 2400));
 await MiloSessionService.initSession();

 MiloDbService.instance.ensureSeeded();
 PaymentApprovalService.instance.init();

 try {
 if (!MiloSessionService.isLoggedInNotifier.value) {
 await MiloAuthService.instance.restoreSession();
 } else {
 final role = await MiloAuthService.instance.fetchRole();
 if (role != null && role != MiloSessionService.currentRoleNotifier.value) {
 await MiloSessionService.updateRole(role);
 }
 }
 } catch (e) {
 debugPrint('Splash Firebase restore note: $e');
 }

 if (!mounted) return;

 if (MiloSessionService.isLoggedInNotifier.value) {
 Navigator.pushReplacement(
 context,
 PageRouteBuilder(
 transitionDuration: const Duration(milliseconds: 550),
 pageBuilder: (_, animation, __) => FadeTransition(
 opacity: animation,
 child: LoginRouter.targetForRole(MiloSessionService.currentRoleNotifier.value),
 ),
 ),
 );
 } else {
 Navigator.pushReplacement(
 context,
 PageRouteBuilder(
 transitionDuration: const Duration(milliseconds: 550),
 pageBuilder: (_, animation, __) => FadeTransition(
 opacity: animation,
 child: const OnboardingScreen(),
 ),
 ),
 );
 }
 }

 @override
 void dispose() {
 _logoController.dispose();
 _glowController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 body: Stack(
 fit: StackFit.expand,
 children: [
 // Soft Top Ambient Blush Gradient 
 Positioned(
 top: 0,
 left: 0,
 right: 0,
 height: 380,
 child: Container(
 decoration: const BoxDecoration(
 gradient: LinearGradient(
 colors: [
 Color(0xFFFFEEF2),
 Color(0xFFFFF7F9),
 Colors.white,
 ],
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 ),
 ),
 ),
 ),

 // Centered Breathing Sonar Ring & Logo 
 Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 AnimatedBuilder(
 animation: Listenable.merge([_logoController, _glowController]),
 builder: (context, _) {
 return Stack(
 alignment: Alignment.center,
 children: [
 // Sonar ring
 Container(
 width: 140 * _sonarRing.value,
 height: 140 * _sonarRing.value,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(
 color: JhoomoTokens.primary.withValues(alpha: _sonarOpacity.value),
 width: 1.5,
 ),
 ),
 ),

 // Soft Ambient Glow
 Container(
 width: 120 * _glowRadius.value,
 height: 120 * _glowRadius.value,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.22),
 blurRadius: 40,
 spreadRadius: 8,
 ),
 ],
 ),
 ),

 // 3D App Icon Badge
 Transform.scale(
 scale: _logoScale.value,
 child: Opacity(
 opacity: _logoOpacity.value,
 child: Container(
 width: 110,
 height: 110,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(30),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.38),
 blurRadius: 28,
 offset: const Offset(0, 10),
 ),
 BoxShadow(
 color: const Color(0xFFFF6A00).withValues(alpha: 0.25),
 blurRadius: 20,
 offset: const Offset(4, 4),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(30),
 child: Image.asset(
 'assets/icons/jhoomo_clean_badge.png',
 width: 110,
 height: 110,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Image.asset(
 'assets/icons/jhoomo_app_icon.png',
 width: 110,
 height: 110,
 fit: BoxFit.cover,
 ),
 ),
 ),
 ),
 ),
 ),
 ],
 );
 },
 ),
 const SizedBox(height: 28),

 // Animated Brand Wordmark & Tagline 
 AnimatedBuilder(
 animation: _logoController,
 builder: (context, _) {
 return Opacity(
 opacity: _taglineOpacity.value,
 child: Transform.translate(
 offset: Offset(0, _taglineSlide.value),
 child: Column(
 children: [
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 'Jhoo',
 style: GoogleFonts.inter(
 fontSize: 34,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 letterSpacing: -1.2,
 ),
 ),
 Text(
 'mo',
 style: GoogleFonts.inter(
 fontSize: 34,
 fontWeight: FontWeight.w900,
 color: JhoomoTokens.primary,
 letterSpacing: -1.2,
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 'Milna Aasaan • Pal Yaadgaar • Data Aapka',
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF64748B),
 letterSpacing: 0.3,
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),
 ],
 ),
 ),

 // Bottom Powered by Enterprise Security Label 
 Positioned(
 bottom: 34,
 left: 0,
 right: 0,
 child: Center(
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF94A3B8)),
 const SizedBox(width: 5),
 Text(
  'Protected by Jhoomo SafePay & Privacy Shield',
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w500,
 color: const Color(0xFF94A3B8),
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}
