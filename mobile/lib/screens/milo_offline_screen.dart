import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class MiloOfflineScreen extends StatefulWidget {
 final Future<bool> Function()? onRetry;
 final VoidCallback? onBypass;

 const MiloOfflineScreen({
 super.key,
 this.onRetry,
 this.onBypass,
 });

 @override
 State<MiloOfflineScreen> createState() => _MiloOfflineScreenState();
}

class _MiloOfflineScreenState extends State<MiloOfflineScreen>
 with SingleTickerProviderStateMixin {
 bool _isChecking = false;
 late AnimationController _pulseController;

 @override
 void initState() {
 super.initState();
 _pulseController = AnimationController(
 vsync: this,
 duration: const Duration(seconds: 2),
 )..repeat(reverse: true);
 }

 @override
 void dispose() {
 _pulseController.dispose();
 super.dispose();
 }

 Future<void> _handleRetry() async {
 if (_isChecking) return;
 setState(() => _isChecking = true);

 bool reconnected = false;
 if (widget.onRetry != null) {
 try {
 reconnected = await widget.onRetry!();
 } catch (_) {
 reconnected = false;
 }
 } else {
 await Future.delayed(const Duration(milliseconds: 1200));
 }

 if (!mounted) return;
 setState(() => _isChecking = false);

 if (reconnected) {
 Navigator.of(context).pop(true);
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 'Still unable to reach Milo servers. Please check your network.',
 style: GoogleFonts.inter(
 color: MiloColors.rose,
 fontWeight: FontWeight.w600,
 fontSize: 12,
 ),
 ),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 body: SafeArea(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 32),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Spacer(flex: 2),

 // BMS Offline Phone + Caution Triangle Illustration
 AnimatedBuilder(
 animation: _pulseController,
 builder: (context, child) {
 final scale = 1.0 + (_pulseController.value * 0.04);
 return Transform.scale(
 scale: scale,
 child: Container(
 width: 180,
 height: 220,
 decoration: BoxDecoration(
 color: const Color(0xFFF8F9FA),
 borderRadius: BorderRadius.circular(32),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.04),
 blurRadius: 20,
 offset: const Offset(0, 10),
 ),
 ],
 ),
 child: Stack(
 alignment: Alignment.center,
 children: [
 // Phone frame
 Container(
 width: 130,
 height: 190,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(
 color: const Color(0xFFE5E7EB),
 width: 2.5,
 ),
 ),
 child: Column(
 children: [
 const SizedBox(height: 8),
 Container(
 width: 32,
 height: 4,
 decoration: BoxDecoration(
 color: const Color(0xFFD1D5DB),
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 const Spacer(),
 // Warning Triangle Icon
 Container(
 width: 64,
 height: 64,
 decoration: BoxDecoration(
 color: const Color(0xFFFEF3C7),
 shape: BoxShape.circle,
 border: Border.all(
 color: const Color(0xFFFDE68A),
 width: 2,
 ),
 ),
 child: const Icon(
 Icons.warning_amber_rounded,
 color: Color(0xFFD97706),
 size: 38,
 ),
 ),
 const Spacer(),
 Container(
 width: 40,
 height: 3,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB),
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 const SizedBox(height: 10),
 ],
 ),
 ),
 // Subtle Red notification dot on phone top
 Positioned(
 top: 26,
 right: 36,
 child: Container(
 width: 8,
 height: 8,
 decoration: const BoxDecoration(
 color: Color(0xFFDC2626),
 shape: BoxShape.circle,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),

 const SizedBox(height: 36),

 // Title
 Text(
 'Are you offline?',
 style: GoogleFonts.inter(
 fontSize: 22,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF1F2937),
 letterSpacing: -0.5,
 ),
 ),

 const SizedBox(height: 12),

 // Subtitle
 Text(
 'Your internet might be unstable.\nPlease try again. (Error code: 1002).',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w400,
 color: const Color(0xFF6B7280),
 height: 1.45,
 ),
 ),

 const SizedBox(height: 32),

 // Try Again button
 TextButton(
 onPressed: _isChecking ? null : _handleRetry,
 style: TextButton.styleFrom(
 padding: const EdgeInsets.symmetric(
 horizontal: 24,
 vertical: 12,
 ),
 ),
 child: _isChecking
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: Color(0xFFE11D48),
 ),
 )
 : Text(
 'Try Again',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: const Color(0xFFE11D48),
 ),
 ),
 ),

 const Spacer(flex: 3),

 if (widget.onBypass != null)
 TextButton(
 onPressed: widget.onBypass,
 child: Text(
 'Continue in Offline Demo Mode →',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF9CA3AF),
 ),
 ),
 ),
 const SizedBox(height: 12),
 ],
 ),
 ),
 ),
 );
 }
}
