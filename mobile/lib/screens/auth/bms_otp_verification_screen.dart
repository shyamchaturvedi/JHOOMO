import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'login_router.dart';
import 'profile_setup_screen.dart';

class BMSOTPVerificationScreen extends StatefulWidget {
 final String phoneNumber;
 final bool demoMode;

 const BMSOTPVerificationScreen({
 super.key,
 required this.phoneNumber,
 this.demoMode = false,
 });

 @override
 State<BMSOTPVerificationScreen> createState() => _BMSOTPVerificationScreenState();
}

class _BMSOTPVerificationScreenState extends State<BMSOTPVerificationScreen> {
 final List<TextEditingController> _controllers =
 List.generate(6, (_) => TextEditingController());
 final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

 int _resendCountdown = 25;
 Timer? _timer;
 bool _isVerifying = false;
 bool _navigated = false;

 @override
 void initState() {
 super.initState();
 _startCountdown();
 }

 void _startCountdown() {
 _timer?.cancel();
 setState(() => _resendCountdown = 25);
 _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
 if (_resendCountdown > 0) {
 setState(() => _resendCountdown--);
 } else {
 timer.cancel();
 }
 });
 }

 @override
 void dispose() {
 _timer?.cancel();
 for (final c in _controllers) {
 c.dispose();
 }
 for (final f in _focusNodes) {
 f.dispose();
 }
 super.dispose();
 }

 Future<void> _verifyOTP() async {
 final otp = _controllers.map((c) => c.text).join();
 if (otp.length < 6) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please enter all 6 digits of the OTP'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 return;
 }

 setState(() => _isVerifying = true);

 String? error;
 if (widget.demoMode) {
 await Future.delayed(const Duration(milliseconds: 600));
 error = null;
 } else {
 error = await MiloAuthService.instance.verifyOtp(otp);
 }

 if (!mounted) return;
 if (error != null) {
 setState(() => _isVerifying = false);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
 );
 return;
 }
 await _afterVerified();
 }

 Future<void> _afterVerified() async {
 if (_navigated || !mounted) return;
 _navigated = true;

 final hasProfile = await MiloAuthService.instance.hasProfile();
 if (!mounted) return;
 if (hasProfile) {
 await MiloAuthService.instance.restoreSession();
 if (!mounted) return;
 LoginRouter.go(context, MiloSessionService.currentRoleNotifier.value);
 } else {
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(
 builder: (context) => ProfileSetupScreen(phoneNumber: widget.phoneNumber),
 ),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 backgroundColor: Colors.white,
 elevation: 0,
 centerTitle: true,
 title: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
  'jhoomo',
 style: GoogleFonts.inter(
 fontSize: 22,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF111827),
 letterSpacing: -0.5,
 ),
 ),
 Container(
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFE11D48),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 'LIVE',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 ),
 Text(
 'events',
 style: GoogleFonts.inter(
 fontSize: 22,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF111827),
 letterSpacing: -0.5,
 ),
 ),
 ],
 ),
 ),
 body: SafeArea(
 child: Column(
 children: [
 // Top BMS Illustration Card: Popcorn, Ticket, Bell, Credit Card
 Expanded(
 flex: 4,
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 24),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(
 width: 220,
 height: 130,
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(24),
 ),
 child: Stack(
 alignment: Alignment.center,
 children: [
 Positioned(
 left: 20,
 child: Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFFFFF1F2),
 borderRadius: BorderRadius.circular(16),
 ),
 child: const Icon(
 Icons.movie_filter_rounded,
 size: 54,
 color: Color(0xFFE11D48),
 ),
 ),
 ),
 Positioned(
 right: 24,
 child: Container(
 width: 80,
 height: 52,
 decoration: BoxDecoration(
 color: const Color(0xFF38BDF8),
 borderRadius: BorderRadius.circular(10),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0284C7).withValues(alpha: 0.2),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: const Icon(Icons.credit_card, color: Colors.white, size: 28),
 ),
 ),
 Positioned(
 top: 14,
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: const BoxDecoration(
 color: Color(0xFFFDE68A),
 shape: BoxShape.circle,
 ),
 child: const Icon(
 Icons.notifications_active_rounded,
 color: Color(0xFFD97706),
 size: 20,
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'Get updates on upcoming\nmovies and events you like',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF1F2937),
 height: 1.35,
 ),
 ),
 ],
 ),
 ),
 ),

 // Bottom OTP Sheet
 Expanded(
 flex: 5,
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 16,
 offset: const Offset(0, -4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // Back link
 GestureDetector(
 onTap: () => Navigator.pop(context),
 child: Row(
 children: [
 const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF111827)),
 const SizedBox(width: 6),
 Text(
 'Back',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 18),

 Text(
 'OTP Verification',
 style: GoogleFonts.inter(
 fontSize: 22,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Enter OTP sent to +91 ${widget.phoneNumber}',
 style: GoogleFonts.inter(
 fontSize: 13,
 color: const Color(0xFF6B7280),
 fontWeight: FontWeight.w500,
 ),
 ),
 const SizedBox(height: 28),

 // 6 Rounded Red-Bordered OTP Inputs
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: List.generate(6, (index) {
 final isFocused = _focusNodes[index].hasFocus;
 final hasValue = _controllers[index].text.isNotEmpty;
 return Container(
 width: 44,
 height: 52,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(
 color: (isFocused || hasValue)
 ? const Color(0xFFE11D48)
 : const Color(0xFFD1D5DB),
 width: (isFocused || hasValue) ? 1.5 : 1,
 ),
 ),
 child: Center(
 child: TextField(
 controller: _controllers[index],
 focusNode: _focusNodes[index],
 keyboardType: TextInputType.number,
 textAlign: TextAlign.center,
 maxLength: 1,
 style: GoogleFonts.inter(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF111827),
 ),
 decoration: const InputDecoration(
 counterText: '',
 border: InputBorder.none,
 ),
 onChanged: (val) {
 if (val.isNotEmpty && index < 5) {
 _focusNodes[index + 1].requestFocus();
 } else if (val.isEmpty && index > 0) {
 _focusNodes[index - 1].requestFocus();
 }
 setState(() {});
 if (index == 5 && val.isNotEmpty) {
 _verifyOTP();
 }
 },
 ),
 ),
 );
 }),
 ),
 const SizedBox(height: 18),

 // Resend OTP in 25 seconds
 Align(
 alignment: Alignment.centerRight,
 child: _resendCountdown > 0
 ? RichText(
 text: TextSpan(
 text: 'Resend OTP in ',
 style: GoogleFonts.inter(
 fontSize: 13,
 color: const Color(0xFF6B7280),
 ),
 children: [
 TextSpan(
 text: '$_resendCountdown seconds',
 style: GoogleFonts.inter(
 fontWeight: FontWeight.w700,
 color: const Color(0xFF111827),
 ),
 ),
 ],
 ),
 )
 : InkWell(
 onTap: () {
 _startCountdown();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('New OTP sent via SMS! (Demo: any 6 digits)'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 },
 child: Text(
 'Resend OTP',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: const Color(0xFFE11D48),
 ),
 ),
 ),
 ),

 const Spacer(),

 // Submit Button
 SizedBox(
 height: 50,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFE11D48),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 ),
 onPressed: _isVerifying ? null : _verifyOTP,
 child: _isVerifying
 ? const SizedBox(
 width: 22,
 height: 22,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: Colors.white,
 ),
 )
 : Text(
 'Submit',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ),
 const SizedBox(height: 12),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
}
