import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

/// S-31 · Simulate Fake Call
/// 100% local — setup screen + full-screen incoming call UI
class FakeCallScreen extends StatefulWidget {
 const FakeCallScreen({super.key});

 @override
 State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
 String _callerName = 'Mom';
 int _delaySeconds = 0; // 0 = Now, 10, 30, 60, 300
 bool _callActive = false;
 bool _inCall = false;
 Timer? _callTimer;
 Timer? _inCallTimer;
 int _callDuration = 0;

 final _customNameController = TextEditingController();

 final _presets = ['Mom', 'Dad', 'Boss', 'Best Friend', 'Doctor', 'Custom'];
 final _delays = [
 {'label': 'Now', 'seconds': 0},
 {'label': '10 sec', 'seconds': 10},
 {'label': '30 sec', 'seconds': 30},
 {'label': '1 min', 'seconds': 60},
 {'label': '5 min', 'seconds': 300},
 ];

 void _startFakeCall() {
 HapticFeedback.heavyImpact();
 setState(() => _callActive = true);
 _callTimer = Timer(Duration(seconds: _delaySeconds), () {
 if (mounted) setState(() => _inCall = false);
 _showIncomingCall();
 });
 }

 void _showIncomingCall() {
 setState(() => _inCall = false);
 showGeneralDialog(
 context: context,
 barrierDismissible: false,
 pageBuilder: (_, __, ___) => _IncomingCallScreen(
 callerName: _callerName,
 onAccept: () {
 Navigator.pop(context);
 _startInCall();
 },
 onDecline: () {
 Navigator.pop(context);
 setState(() => _callActive = false);
 },
 ),
 );
 }

 void _startInCall() {
 setState(() {
 _inCall = true;
 _callDuration = 0;
 });
 _inCallTimer = Timer.periodic(const Duration(seconds: 1), (_) {
 if (mounted) setState(() => _callDuration++);
 });
 }

 void _endCall() {
 _inCallTimer?.cancel();
 setState(() {
 _inCall = false;
 _callActive = false;
 _callDuration = 0;
 });
 HapticFeedback.mediumImpact();
 }

 String _formatDuration(int s) {
 final m = s ~/ 60;
 final sec = s % 60;
 return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
 }

 @override
 void dispose() {
 _callTimer?.cancel();
 _inCallTimer?.cancel();
 _customNameController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 if (_inCall) return _buildInCallScreen();

 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Fake Call Setup ',
 style: GoogleFonts.outfit(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 leading: IconButton(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MiloColors.textPrimary),
 ),
 ),
 body: SingleChildScrollView(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Safety info banner
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.primary.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.security_rounded, color: MiloColors.primaryLight, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Works 100% offline. Nothing is stored or sent to anyone.',
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 24),

 Text('Caller Name', style: _labelStyle),
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _presets.map((name) {
 final isSelected = _callerName == name;
 return GestureDetector(
 onTap: () {
 setState(() => _callerName = name);
 if (name == 'Custom') {
 showDialog(
 context: context,
 builder: (_) => AlertDialog(
 backgroundColor: MiloColors.bgSurface,
 title: Text('Custom Caller', style: GoogleFonts.outfit(color: MiloColors.textPrimary)),
 content: TextField(
 controller: _customNameController,
 style: GoogleFonts.inter(color: MiloColors.textPrimary),
 decoration: const InputDecoration(hintText: 'Enter name'),
 ),
 actions: [
 TextButton(
 onPressed: () {
 if (_customNameController.text.isNotEmpty) {
 setState(() => _callerName = _customNameController.text);
 }
 Navigator.pop(context);
 },
 child: Text('OK', style: GoogleFonts.inter(color: MiloColors.primary)),
 ),
 ],
 ),
 );
 }
 },
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary.withValues(alpha: 0.15) : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: isSelected ? MiloColors.primary : MiloColors.border,
 width: isSelected ? 1.5 : 1,
 ),
 ),
 child: Text(
 name,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
 color: isSelected ? MiloColors.primaryLight : MiloColors.textSecondary,
 ),
 ),
 ),
 );
 }).toList(),
 ),

 const SizedBox(height: 24),

 Text('Call Delay', style: _labelStyle),
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _delays.map((d) {
 final isSelected = _delaySeconds == d['seconds'];
 return GestureDetector(
 onTap: () => setState(() => _delaySeconds = d['seconds'] as int),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary.withValues(alpha: 0.15) : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: isSelected ? MiloColors.primary : MiloColors.border,
 width: isSelected ? 1.5 : 1,
 ),
 ),
 child: Text(
 d['label'] as String,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
 color: isSelected ? MiloColors.primaryLight : MiloColors.textSecondary,
 ),
 ),
 ),
 );
 }).toList(),
 ),

 const SizedBox(height: 40),

 // Trigger button
 Center(
 child: GestureDetector(
 onTap: _callActive ? null : _startFakeCall,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 width: 140,
 height: 140,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: const LinearGradient(
 colors: [Color(0xFF16A34A), Color(0xFF15803D)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF16A34A).withValues(alpha: _callActive ? 0.2 : 0.5),
 blurRadius: 30,
 spreadRadius: 8,
 ),
 ],
 ),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.phone_rounded, color: Colors.white, size: 40),
 const SizedBox(height: 6),
 Text(
 _callActive ? 'Calling…' : 'Start Call',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ],
 ),
 ),
 ),
 ),

 const SizedBox(height: 20),

 if (_callerName.isNotEmpty)
 Center(
 child: Text(
 '"$_callerName" will call you${_delaySeconds == 0 ? ' now' : ' in ${_delays.firstWhere((d) => d['seconds'] == _delaySeconds)['label']}'}',
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textMuted),
 textAlign: TextAlign.center,
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildInCallScreen() {
 return Scaffold(
 backgroundColor: const Color(0xFF1A2634),
 body: SafeArea(
 child: Column(
 children: [
 const SizedBox(height: 60),
 Text(
 _callerName,
 style: GoogleFonts.outfit(
 fontSize: 32,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 _formatDuration(_callDuration),
 style: GoogleFonts.inter(fontSize: 18, color: Colors.white70),
 ),
 const Spacer(),
 // Controls row
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
 children: [
 _CallControlBtn(icon: Icons.mic_off_rounded, label: 'Mute'),
 _CallControlBtn(icon: Icons.volume_up_rounded, label: 'Speaker'),
 _CallControlBtn(icon: Icons.dialpad_rounded, label: 'Keypad'),
 ],
 ),
 const SizedBox(height: 40),
 // End call button
 GestureDetector(
 onTap: _endCall,
 child: Container(
 width: 72,
 height: 72,
 decoration: const BoxDecoration(
 shape: BoxShape.circle,
 color: Color(0xFFDC2626),
 ),
 child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
 ),
 ),
 const SizedBox(height: 50),
 ],
 ),
 ),
 );
 }

 TextStyle get _labelStyle => GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: MiloColors.textPrimary,
 );
}

class _CallControlBtn extends StatelessWidget {
 final IconData icon;
 final String label;
 const _CallControlBtn({required this.icon, required this.label});

 @override
 Widget build(BuildContext context) => Column(
 children: [
 Container(
 width: 56,
 height: 56,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: Colors.white.withValues(alpha: 0.15),
 ),
 child: Icon(icon, color: Colors.white, size: 24),
 ),
 const SizedBox(height: 6),
 Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
 ],
 );
}

class _IncomingCallScreen extends StatefulWidget {
 final String callerName;
 final VoidCallback onAccept;
 final VoidCallback onDecline;

 const _IncomingCallScreen({
 required this.callerName,
 required this.onAccept,
 required this.onDecline,
 });

 @override
 State<_IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<_IncomingCallScreen>
 with SingleTickerProviderStateMixin {
 late AnimationController _pulseCtrl;
 late Animation<double> _pulse;

 @override
 void initState() {
 super.initState();
 _pulseCtrl = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1200),
 )..repeat(reverse: true);
 _pulse = Tween<double>(begin: 0.9, end: 1.05).animate(
 CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine),
 );
 HapticFeedback.vibrate();
 }

 @override
 void dispose() {
 _pulseCtrl.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: const Color(0xFF0F1923),
 body: SafeArea(
 child: Column(
 children: [
 const SizedBox(height: 80),
 Text(
 'Incoming Call',
 style: GoogleFonts.inter(fontSize: 16, color: Colors.white60),
 ),
 const SizedBox(height: 20),
 AnimatedBuilder(
 animation: _pulseCtrl,
 builder: (_, child) => Transform.scale(
 scale: _pulse.value,
 child: child,
 ),
 child: CircleAvatar(
 radius: 60,
 backgroundColor: const Color(0xFF1E293B),
 child: Text(
 widget.callerName[0].toUpperCase(),
 style: GoogleFonts.outfit(
 fontSize: 48,
 fontWeight: FontWeight.w900,
 color: MiloColors.primaryLight,
 ),
 ),
 ),
 ),
 const SizedBox(height: 20),
 Text(
 widget.callerName,
 style: GoogleFonts.outfit(
 fontSize: 30,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 const Spacer(),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
 children: [
 Column(
 children: [
 GestureDetector(
 onTap: widget.onDecline,
 child: Container(
 width: 72,
 height: 72,
 decoration: const BoxDecoration(
 shape: BoxShape.circle,
 color: Color(0xFFDC2626),
 ),
 child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
 ),
 ),
 const SizedBox(height: 8),
 Text('Decline', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
 ],
 ),
 Column(
 children: [
 GestureDetector(
 onTap: widget.onAccept,
 child: Container(
 width: 72,
 height: 72,
 decoration: const BoxDecoration(
 shape: BoxShape.circle,
 color: Color(0xFF16A34A),
 ),
 child: const Icon(Icons.phone_rounded, color: Colors.white, size: 32),
 ),
 ),
 const SizedBox(height: 8),
 Text('Accept', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
 ],
 ),
 ],
 ),
 const SizedBox(height: 60),
 ],
 ),
 ),
 );
 }
}
