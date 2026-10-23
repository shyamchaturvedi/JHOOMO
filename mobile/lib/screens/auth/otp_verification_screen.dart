import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'login_router.dart';
import 'profile_setup_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
 final String phoneNumber;
 final bool demoMode;

 const OTPVerificationScreen({
 super.key,
 required this.phoneNumber,
 this.demoMode = false,
 });

 @override
 State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
 final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
 final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
 bool _isVerifying = false;
 bool _navigated = false;
 int _secondsRemaining = 26;
 bool _canResend = false;

 @override
 void initState() {
 super.initState();
 _startTimer();
 }

 void _startTimer() {
 Future.doWhile(() async {
 await Future.delayed(const Duration(seconds: 1));
 if (!mounted) return false;
 if (_secondsRemaining > 0) {
 setState(() => _secondsRemaining--);
 return true;
 } else {
 setState(() => _canResend = true);
 return false;
 }
 });
 }

 Future<void> _verifyOTP() async {
 final otp = _controllers.map((c) => c.text).join();
 if (otp.length < 6) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Please enter complete 6-digit OTP code')),
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
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
 return;
 }
 await _afterVerified();
 }

 Future<void> _afterVerified() async {
 if (_navigated || !mounted) return;
 _navigated = true;

 // Automatically initialize/save session as Default Customer
 final uid = MiloAuthService.instance.currentUser?.uid ?? 'cust_${DateTime.now().millisecondsSinceEpoch}';
 await MiloSessionService.saveLoginSession(
 role: MiloRole.customer,
 name: 'Sahil',
 phone: widget.phoneNumber,
 uid: uid,
 );

 // Save default profile to Firestore silently in background if Firebase is active
 try {
 if (MiloAuthService.instance.currentUser != null) {
 await MiloAuthService.instance.saveProfile(
 name: 'Sahil',
 phone: widget.phoneNumber,
 age: 23,
 city: 'Lucknow',
 role: MiloRole.customer,
 );
 }
 } catch (_) {}

 if (!mounted) return;
 // Route directly to main customer app
 LoginRouter.go(context, MiloRole.customer);
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
 onPressed: () => Navigator.pop(context),
 ),
 ),
 body: SafeArea(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 28),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const SizedBox(height: 10),

 // Header Title & Phone Info 
 Text(
 'Verify Phone',
 style: GoogleFonts.inter(
 fontSize: 26,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 letterSpacing: -0.6,
 ),
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Text(
 'Code sent to +91 ${widget.phoneNumber}',
 style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
 ),
 const SizedBox(width: 8),
 GestureDetector(
 onTap: () => Navigator.pop(context),
 child: Text(
 'Edit',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.primary,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 36),

 // 6 Smart OTP Boxes 
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: List.generate(6, (index) {
 return Container(
 width: 48,
 height: 56,
 decoration: BoxDecoration(
 color: const Color(0xFFF8FAFC),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(
 color: _focusNodes[index].hasFocus
 ? JhoomoTokens.primary
 : const Color(0xFFE2E8F0),
 width: _focusNodes[index].hasFocus ? 1.8 : 1,
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
 fontSize: 22,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
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
 },
 ),
 ),
 );
 }),
 ),
 const SizedBox(height: 32),

 // Verify & Continue Button 
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 onPressed: _isVerifying ? null : _verifyOTP,
 style: ElevatedButton.styleFrom(
 backgroundColor: JhoomoTokens.primary,
 foregroundColor: Colors.white,
 elevation: 4,
 shadowColor: JhoomoTokens.primary.withValues(alpha: 0.35),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 ),
 child: _isVerifying
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
 )
 : Text(
 'Verify & Continue →',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 ),
 ),
 const SizedBox(height: 20),

 // Resend Code Minimal Timer 
 Center(
 child: _canResend
 ? GestureDetector(
 onTap: () {
 setState(() {
 _secondsRemaining = 30;
 _canResend = false;
 });
 _startTimer();
 },
 child: Text(
 'Resend SMS Code',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.primary,
 ),
 ),
 )
 : Text(
 'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}s',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF94A3B8),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}
