import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../models/models.dart';
import 'my_tickets_screen.dart';

/// S-13 · Payment Result Screen
/// Shown after Razorpay checkout returns.
/// Success: confetti + booking ref + view ticket CTA
/// Pending: live listener banner
/// Failure: retry or start over
class PaymentResultScreen extends StatefulWidget {
 final String bookingRef; // e.g. MILO-892182
 final String status; // 'success' | 'pending' | 'failed'
 final String? failureReason;
 final BookedTicket? bookedTicket;

 const PaymentResultScreen({
 super.key,
 required this.bookingRef,
 required this.status,
 this.failureReason,
 this.bookedTicket,
 });

 @override
 State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen>
 with TickerProviderStateMixin {
 late AnimationController _confettiCtrl;
 late AnimationController _badgeCtrl;
 late Animation<double> _badgeScale;
 late Animation<double> _badgeOpacity;

 final List<_ConfettiParticle> _particles = [];
 final _rng = Random();

 @override
 void initState() {
 super.initState();

 _badgeCtrl = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 700),
 );
 _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(parent: _badgeCtrl, curve: Curves.elasticOut),
 );
 _badgeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
 CurvedAnimation(parent: _badgeCtrl, curve: const Interval(0.0, 0.5)),
 );

 _confettiCtrl = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 2200),
 );

 if (widget.status == 'success') {
 _generateParticles();
 _confettiCtrl.forward();
 }

 _badgeCtrl.forward();
 }

 void _generateParticles() {
 _particles.clear();
 for (int i = 0; i < 40; i++) {
 _particles.add(_ConfettiParticle(
 x: _rng.nextDouble(),
 delay: _rng.nextDouble() * 0.5,
 speed: 0.4 + _rng.nextDouble() * 0.6,
 size: 4 + _rng.nextDouble() * 8,
 color: [
 MiloColors.primary,
 MiloColors.gold,
 MiloColors.cyan,
 MiloColors.emerald,
 Colors.white,
 ][_rng.nextInt(5)],
 angle: _rng.nextDouble() * 6.28,
 ));
 }
 }

 @override
 void dispose() {
 _badgeCtrl.dispose();
 _confettiCtrl.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: const SizedBox.shrink(),
 automaticallyImplyLeading: false,
 ),
 body: Stack(
 children: [
 // Confetti for success
 if (widget.status == 'success')
 AnimatedBuilder(
 animation: _confettiCtrl,
 builder: (_, __) {
 return CustomPaint(
 painter: _ConfettiPainter(
 particles: _particles,
 progress: _confettiCtrl.value,
 ),
 size: MediaQuery.of(context).size,
 );
 },
 ),

 SafeArea(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24),
 child: Column(
 children: [
 const SizedBox(height: 40),
 // Status badge
 AnimatedBuilder(
 animation: _badgeCtrl,
 builder: (_, __) => Transform.scale(
 scale: _badgeScale.value,
 child: Opacity(
 opacity: _badgeOpacity.value,
 child: _buildStatusBadge(),
 ),
 ),
 ),

 const SizedBox(height: 24),
 _buildStatusText(),
 const SizedBox(height: 8),
 _buildSubText(),
 const SizedBox(height: 32),

 // Booking ref card
 if (widget.status == 'success')
 _BookingRefCard(ref: widget.bookingRef),

 const Spacer(),
 _buildActions(context),
 const SizedBox(height: 28),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildStatusBadge() {
 final isSuccess = widget.status == 'success';
 final isPending = widget.status == 'pending';
 return Container(
 width: 100,
 height: 100,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: LinearGradient(
 colors: isSuccess
 ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
 : isPending
 ? [MiloColors.amber, MiloColors.amber.withValues(alpha: 0.7)]
 : [MiloColors.primary, MiloColors.primaryDark],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 boxShadow: [
 BoxShadow(
 color: (isSuccess ? MiloColors.emerald : isPending ? MiloColors.amber : MiloColors.primary)
 .withValues(alpha: 0.4),
 blurRadius: 30,
 spreadRadius: 5,
 ),
 ],
 ),
 child: Icon(
 isSuccess
 ? Icons.check_circle_outline_rounded
 : isPending
 ? Icons.hourglass_empty_rounded
 : Icons.error_outline_rounded,
 color: Colors.white,
 size: 52,
 ),
 );
 }

 Widget _buildStatusText() {
 final texts = {
 'success': 'Booking Confirmed! ',
 'pending': 'Payment Processing',
 'failed': 'Payment Failed',
 };
 return Text(
 texts[widget.status] ?? 'Done',
 style: GoogleFonts.outfit(
 fontSize: 28,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary,
 ),
 textAlign: TextAlign.center,
 );
 }

 Widget _buildSubText() {
 if (widget.status == 'success') {
 return Text(
 'Your tickets are confirmed. Have a blast! ',
 style: GoogleFonts.inter(
 fontSize: 15,
 color: MiloColors.textSecondary,
 ),
 textAlign: TextAlign.center,
 );
 }
 if (widget.status == 'pending') {
 return Column(
 children: [
 Text(
 'Don\'t pay again — we\'re confirming with your bank.\nYou\'ll get a notification once done.',
 style: GoogleFonts.inter(
 fontSize: 14,
 color: MiloColors.textSecondary,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 16),
 const LinearProgressIndicator(
 backgroundColor: Color(0x22FFFFFF),
 valueColor: AlwaysStoppedAnimation<Color>(MiloColors.amber),
 ),
 ],
 );
 }
 return Text(
 widget.failureReason ?? 'The payment was declined or timed out.\nYour money has not been debited.',
 style: GoogleFonts.inter(
 fontSize: 14,
 color: MiloColors.textSecondary,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 );
 }

 Widget _buildActions(BuildContext context) {
 if (widget.status == 'success') {
 return Column(
 children: [
 SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton.icon(
 onPressed: widget.bookedTicket != null
 ? () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => MyTicketsScreen(initialBooking: widget.bookedTicket),
 ),
 )
 : () => Navigator.pop(context),
 icon: const Icon(Icons.qr_code_rounded, size: 20),
 label: Text(
 'View Ticket',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 height: 48,
 child: OutlinedButton.icon(
 onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
 icon: const Icon(Icons.explore_rounded, size: 18),
 label: Text(
 'Explore More Events',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: MiloColors.textPrimary,
 side: BorderSide(color: MiloColors.textMuted.withValues(alpha: 0.4)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 ],
 );
 }

 if (widget.status == 'pending') {
 return SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton.icon(
 onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
 icon: const Icon(Icons.home_rounded, size: 20),
 label: Text(
 'Go to Home',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.amber,
 foregroundColor: Colors.black,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 );
 }

 // Failed
 return Column(
 children: [
 SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton.icon(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.refresh_rounded, size: 20),
 label: Text(
 'Try Again',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 const SizedBox(height: 12),
 TextButton(
 onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
 child: Text(
 'Cancel & go home',
 style: GoogleFonts.inter(
 fontSize: 14,
 color: MiloColors.textMuted,
 ),
 ),
 ),
 ],
 );
 }
}

class _BookingRefCard extends StatelessWidget {
 final String ref;
 const _BookingRefCard({required this.ref});

 @override
 Widget build(BuildContext context) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 MiloColors.primary.withValues(alpha: 0.12),
 MiloColors.emerald.withValues(alpha: 0.08),
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(
 color: MiloColors.emerald.withValues(alpha: 0.3),
 width: 1.2,
 ),
 ),
 child: Column(
 children: [
 Text(
 'Booking Reference',
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.textMuted,
 letterSpacing: 1,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 ref,
 style: GoogleFonts.outfit(
 fontSize: 26,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary,
 letterSpacing: 2,
 ),
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
 const SizedBox(width: 4),
 Text(
 'Milo Escrow Protected',
 style: GoogleFonts.inter(
 fontSize: 12,
 color: const Color(0xFF16A34A),
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}

// Confetti particles 

class _ConfettiParticle {
 final double x;
 final double delay;
 final double speed;
 final double size;
 final Color color;
 final double angle;

 const _ConfettiParticle({
 required this.x,
 required this.delay,
 required this.speed,
 required this.size,
 required this.color,
 required this.angle,
 });
}

class _ConfettiPainter extends CustomPainter {
 final List<_ConfettiParticle> particles;
 final double progress;

 const _ConfettiPainter({required this.particles, required this.progress});

 @override
 void paint(Canvas canvas, Size size) {
 for (final p in particles) {
 final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
 if (t <= 0) continue;

 final x = p.x * size.width + sin(t * 6 + p.angle) * 20;
 final y = t * p.speed * size.height * 1.2;
 final opacity = (1.0 - (t * t)).clamp(0.0, 1.0);

 final paint = Paint()
 ..color = p.color.withValues(alpha: opacity)
 ..style = PaintingStyle.fill;

 canvas.save();
 canvas.translate(x, y);
 canvas.rotate(t * p.angle * 3);
 canvas.drawRRect(
 RRect.fromRectAndRadius(
 Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
 const Radius.circular(2),
 ),
 paint,
 );
 canvas.restore();
 }
 }

 @override
 bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
