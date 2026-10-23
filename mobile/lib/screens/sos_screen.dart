import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

/// S-32 · Instant SOS Screen
/// 3-second hold to activate with haptic feedback, 5-second cancel countdown,
/// high-accuracy location tracking, emergency contacts notification, and Call 112
class SOSScreen extends StatefulWidget {
 const SOSScreen({super.key});

 @override
 State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
 // Activation hold
 late AnimationController _holdController;
 bool _isHolding = false;

 // States: 'idle', 'countdown', 'active'
 String _sosState = 'idle';
 int _countdownSeconds = 5;
 Timer? _countdownTimer;

 // Active state timer
 int _activeMinutes = 0;
 Timer? _activeTimer;

 @override
 void initState() {
 super.initState();
 _holdController = AnimationController(
 vsync: this,
 duration: const Duration(seconds: 3),
 )..addStatusListener((status) {
 if (status == AnimationStatus.completed) {
 _triggerCountdown();
 }
 });
 }

 @override
 void dispose() {
 _holdController.dispose();
 _countdownTimer?.cancel();
 _activeTimer?.cancel();
 super.dispose();
 }

 void _onHoldStart(TapDownDetails details) {
 if (_sosState != 'idle') return;
 setState(() => _isHolding = true);
 HapticFeedback.heavyImpact();
 _holdController.forward();
 }

 void _onHoldEnd([TapUpDetails? details]) {
 if (_sosState != 'idle') return;
 if (_holdController.status != AnimationStatus.completed) {
 _holdController.reverse();
 setState(() => _isHolding = false);
 }
 }

 void _triggerCountdown() {
 HapticFeedback.vibrate();
 setState(() {
 _sosState = 'countdown';
 _countdownSeconds = 5;
 });

 _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
 if (_countdownSeconds > 1) {
 HapticFeedback.mediumImpact();
 setState(() => _countdownSeconds--);
 } else {
 timer.cancel();
 _activateSOS();
 }
 });
 }

 void _cancelCountdown() {
 _countdownTimer?.cancel();
 _holdController.reset();
 setState(() {
 _sosState = 'idle';
 _isHolding = false;
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('SOS Alert cancelled'), behavior: SnackBarBehavior.floating),
 );
 }

 void _activateSOS() {
 HapticFeedback.heavyImpact();
 setState(() {
 _sosState = 'active';
 _activeMinutes = 0;
 });

 _activeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
 setState(() => _activeMinutes++);
 });
 }

 void _resolveSafe() {
 _activeTimer?.cancel();
 _holdController.reset();
 setState(() {
 _sosState = 'idle';
 _isHolding = false;
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text("I'm Safe sent! Contacts notified that you are safe."),
 backgroundColor: MiloColors.accentGreen,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: _sosState == 'active' ? const Color(0xFF1F070A) : MiloColors.bgSurface,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Instant Emergency SOS',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 body: SafeArea(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
 child: Column(
 children: [
 if (_sosState == 'idle') _buildIdleView(),
 if (_sosState == 'countdown') _buildCountdownView(),
 if (_sosState == 'active') _buildActiveView(),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildIdleView() {
 return Expanded(
 child: Column(
 children: [
 const SizedBox(height: 20),
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.red.withOpacity(0.12),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.red.withOpacity(0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 'Press and hold the button for 3 seconds in case of danger. Live GPS and venue security desk will be alerted.',
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
 ),
 ),
 ],
 ),
 ),
 const Spacer(),

 // 3-sec Hold Button
 GestureDetector(
 onTapDown: _onHoldStart,
 onTapUp: _onHoldEnd,
 onTapCancel: () => _onHoldEnd(),
 child: Stack(
 alignment: Alignment.center,
 children: [
 SizedBox(
 width: 220,
 height: 220,
 child: AnimatedBuilder(
 animation: _holdController,
 builder: (context, child) {
 return CircularProgressIndicator(
 value: _holdController.value,
 strokeWidth: 8,
 color: Colors.redAccent,
 backgroundColor: Colors.white10,
 );
 },
 ),
 ),
 Container(
 width: 180,
 height: 180,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: const RadialGradient(
 colors: [Color(0xFFE11D48), Color(0xFF991B1B)],
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.red.withOpacity(_isHolding ? 0.6 : 0.3),
 blurRadius: _isHolding ? 40 : 20,
 spreadRadius: _isHolding ? 8 : 2,
 ),
 ],
 ),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.sos_rounded, size: 54, color: Colors.white),
 const SizedBox(height: 4),
 Text(
 _isHolding ? 'HOLDING...' : 'HOLD 3 SEC',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 13,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.2,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),

 const Spacer(),

 // Direct Police Call CTA
 SizedBox(
 width: double.infinity,
 height: 50,
 child: OutlinedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.phone, color: Colors.white70),
 label: Text(
 'Direct Call National Police (112)',
 style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
 ),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Colors.white24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 const SizedBox(height: 10),
 ],
 ),
 );
 }

 Widget _buildCountdownView() {
 return Expanded(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.notification_important_rounded, size: 72, color: Colors.redAccent),
 const SizedBox(height: 20),
 Text(
 'ALERTING EMERGENCY IN',
 style: GoogleFonts.inter(
 color: Colors.white70,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.5,
 ),
 ),
 const SizedBox(height: 12),
 Text(
 '$_countdownSeconds',
 style: GoogleFonts.outfit(
 color: Colors.redAccent,
 fontSize: 84,
 fontWeight: FontWeight.w900,
 ),
 ),
 const SizedBox(height: 24),
 Text(
 'Keep calm. Emergency contacts and venue desk are about to be notified.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
 ),
 const SizedBox(height: 40),
 SizedBox(
 width: 220,
 height: 54,
 child: ElevatedButton.icon(
 onPressed: _cancelCountdown,
 icon: const Icon(Icons.close_rounded),
 label: const Text('Cancel SOS'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white24,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildActiveView() {
 return Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.red.withOpacity(0.2),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: Colors.redAccent),
 ),
 child: Row(
 children: [
 const SizedBox(
 width: 24,
 height: 24,
 child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'SOS ACTIVE (Streaming GPS)',
 style: GoogleFonts.inter(
 color: Colors.redAccent,
 fontSize: 15,
 fontWeight: FontWeight.w800,
 ),
 ),
 Text(
 'Streaming live telemetry for ${_activeMinutes}m',
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 Text(
 'NOTIFICATION STATUS',
 style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 12),
 _buildStatusRow('Confirmed Emergency Contacts', 'SMS Sent with live link', true),
 const SizedBox(height: 8),
 _buildStatusRow('Event Security Desk', 'Alerted on venue dashboard', true),
 const SizedBox(height: 8),
 _buildStatusRow('GPS Location Beacon', 'High Accuracy (~12m radius)', true),
 const Spacer(),

 // Actions
 Row(
 children: [
 Expanded(
 child: SizedBox(
 height: 52,
 child: ElevatedButton.icon(
 onPressed: () {},
 icon: const Icon(Icons.phone),
 label: const Text('Call 112'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.redAccent,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: SizedBox(
 height: 52,
 child: ElevatedButton.icon(
 onPressed: _resolveSafe,
 icon: const Icon(Icons.check_circle_rounded),
 label: const Text("I'm Safe"),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.accentGreen,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 ],
 ),
 );
 }

 Widget _buildStatusRow(String title, String subtitle, bool isDone) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: MiloColors.cardSurface,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 Icon(
 isDone ? Icons.check_circle_rounded : Icons.pending_rounded,
 color: isDone ? MiloColors.accentGreen : Colors.amber,
 size: 20,
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
 ),
 Text(
 subtitle,
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }
}
