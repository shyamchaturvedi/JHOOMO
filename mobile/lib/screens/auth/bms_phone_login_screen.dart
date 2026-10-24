import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/milo_theme.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'login_router.dart';
import 'otp_verification_screen.dart';
import 'profile_setup_screen.dart';

class BMSPhoneLoginScreen extends StatefulWidget {
 final dynamic pendingAction;
 const BMSPhoneLoginScreen({super.key, this.pendingAction});

 @override
 State<BMSPhoneLoginScreen> createState() => _BMSPhoneLoginScreenState();
}

class _BMSPhoneLoginScreenState extends State<BMSPhoneLoginScreen> {
 final TextEditingController _phoneController = TextEditingController();
 bool _isLoading = false;

 void _sendOTP() async {
 final phone = _phoneController.text.trim();
 if (phone.length < 10) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please enter a valid 10-digit mobile number'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 return;
 }

 setState(() => _isLoading = true);

 final auth = MiloAuthService.instance;
 if (!auth.isPhoneAuthAvailable) {
 if (mounted) {
 setState(() => _isLoading = false);
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => OTPVerificationScreen(phoneNumber: phone, demoMode: true),
 ),
 );
 }
 return;
 }

 final error = await auth.sendOtp(
 phone: phone,
 onCodeSent: () {
 if (!mounted) return;
 setState(() => _isLoading = false);
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => OTPVerificationScreen(phoneNumber: phone),
 ),
 );
 },
 onError: (message) {
 if (!mounted) return;
 setState(() => _isLoading = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
 );
 },
 onAutoVerified: (user) async {
 if (!mounted) return;
 setState(() => _isLoading = false);
 await _afterSignedIn(phone);
 },
 );

 if (error != null && mounted) {
 setState(() => _isLoading = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
 );
 }
 }

 void _loginWithGoogle() async {
 setState(() => _isLoading = true);
 try {
 final credential = await MiloAuthService.instance.signInWithGoogle();
 if (!mounted) return;
 setState(() => _isLoading = false);
  if (credential != null && credential.user != null) {
  await _afterSignedIn(credential.user!.phoneNumber ?? '');
  }
 } catch (e) {
 if (!mounted) return;
 setState(() => _isLoading = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Google Sign-In failed: $e'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }

  Future<void> _afterSignedIn(String phone) async {
  if (!mounted) return;
  final hasProfile = await MiloAuthService.instance.hasProfile();
  if (!mounted) return;
  if (hasProfile) {
  await MiloAuthService.instance.restoreSession();
  if (!mounted) return;
  LoginRouter.go(context, MiloSessionService.currentRoleNotifier.value);
  return;
  }
  Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => ProfileSetupScreen(phoneNumber: phone)),
  );
  }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Center(
 child: SingleChildScrollView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(horizontal: 28),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // JHOOMO 3D Dancing Logo Badge 
 Container(
 width: 80,
 height: 80,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.38),
 blurRadius: 24,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(24),
 child: Image.asset(
 'assets/icons/jhoomo_clean_badge.png',
 width: 80,
 height: 80,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Image.asset(
 'assets/icons/jhoomo_app_icon.png',
 width: 80,
 height: 80,
 fit: BoxFit.cover,
 ),
 ),
 ),
 ),
 const SizedBox(height: 18),

 // JHOOMO Clean Typography 
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text(
 'Jhoo',
 style: GoogleFonts.inter(
 fontSize: 32,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 letterSpacing: -1.0,
 ),
 ),
 Text(
 'mo',
 style: GoogleFonts.inter(
 fontSize: 32,
 fontWeight: FontWeight.w900,
 color: JhoomoTokens.primary,
 letterSpacing: -1.0,
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 'Milna Aasaan • Pal Yaadgaar',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF64748B),
 ),
 ),
 const SizedBox(height: 36),

 // Smart Phone Input Field 
 Container(
 height: 54,
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFE2E8F0)),
 ),
 child: Row(
 children: [
 const SizedBox(width: 16),
 const Icon(Icons.phone_iphone_rounded, color: Color(0xFFE11D48), size: 18),
 const SizedBox(width: 8),
 Text(
 '+91',
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF0F172A),
 ),
 ),
 Container(
 width: 1,
 height: 24,
 margin: const EdgeInsets.symmetric(horizontal: 12),
 color: const Color(0xFFCBD5E1),
 ),
 Expanded(
 child: TextField(
 controller: _phoneController,
 keyboardType: TextInputType.phone,
 maxLength: 10,
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF0F172A),
 letterSpacing: 1.5,
 ),
 decoration: InputDecoration(
 counterText: '',
 border: InputBorder.none,
 hintText: 'Enter Mobile Number',
 hintStyle: GoogleFonts.inter(
 color: const Color(0xFF94A3B8),
 fontSize: 14,
 fontWeight: FontWeight.w500,
 letterSpacing: 0,
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),

 // Continue Button (Smart Primary Action) 
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 onPressed: _isLoading ? null : _sendOTP,
 style: ElevatedButton.styleFrom(
 backgroundColor: JhoomoTokens.primary,
 foregroundColor: Colors.white,
 elevation: 4,
 shadowColor: JhoomoTokens.primary.withValues(alpha: 0.35),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 ),
 ),
 child: _isLoading
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
 )
 : Text(
 'Continue with Phone →',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 ),
 ),
 const SizedBox(height: 24),

 // Minimal Divider 
 Row(
 children: [
 const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 child: Text(
 'OR',
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF94A3B8),
 ),
 ),
 ),
 const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
 ],
 ),
 const SizedBox(height: 20),

 // Google 1-Tap Login 
 SizedBox(
 width: double.infinity,
 height: 52,
 child: OutlinedButton(
 onPressed: _isLoading ? null : _loginWithGoogle,
 style: OutlinedButton.styleFrom(
 backgroundColor: const Color(0xFFF8FAFC),
 side: const BorderSide(color: Color(0xFFE2E8F0)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 ),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Image.network(
 'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
 width: 22,
 height: 22,
 errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 26, color: Color(0xFF4285F4)),
 ),
 const SizedBox(width: 10),
 Text(
 'Continue with Google',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF0F172A),
 ),
 ),
 ],
 ),
 ),
 ),
 const SizedBox(height: 36),

 // Minimal Legal Terms 
 Text(
                    'By continuing, you agree to JHOOMO Terms & Privacy Policy',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: const Color(0xFF94A3B8),
 ),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }
}
