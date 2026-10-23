import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../models/models.dart';
import 'refund_request_screen.dart';

/// S-15 · Ticket Detail & Dynamic QR
/// Shows large high-contrast QR, rotating 30-second token ring,
/// watermark, booking ref, status badge, directions, and download/refund actions.
class TicketDetailScreen extends StatefulWidget {
 final BookedTicket ticket;

 const TicketDetailScreen({super.key, required this.ticket});

 @override
 State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
 with TickerProviderStateMixin {
 late AnimationController _ringCtrl;
 late AnimationController _qrPulseCtrl;
 late Animation<double> _ringProgress;
 late Animation<double> _qrGlow;
 Timer? _refreshTimer;
 int _secondsLeft = 30;
 String _tokenSuffix = ''; // rotates every 30s

 @override
 void initState() {
 super.initState();

 // Rotating token ring (30-second countdown)
 _ringCtrl = AnimationController(
 vsync: this,
 duration: const Duration(seconds: 30),
 );
 _ringProgress = Tween<double>(begin: 1.0, end: 0.0).animate(_ringCtrl);
 _ringCtrl.forward();

 // QR glow pulse
 _qrPulseCtrl = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 2000),
 )..repeat(reverse: true);
 _qrGlow = Tween<double>(begin: 0.3, end: 0.7).animate(
 CurvedAnimation(parent: _qrPulseCtrl, curve: Curves.easeInOutSine),
 );

 _tokenSuffix = _generateToken();

 // Refresh token every 30s
 _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
 if (mounted) {
 setState(() {
 _tokenSuffix = _generateToken();
 _secondsLeft = 30;
 _ringCtrl.reset();
 _ringCtrl.forward();
 });
 }
 });

 // Countdown display
 Timer.periodic(const Duration(seconds: 1), (t) {
 if (!mounted) {
 t.cancel();
 return;
 }
 setState(() {
 _secondsLeft = (_secondsLeft - 1).clamp(0, 30);
 });
 });
 }

 String _generateToken() {
 const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
 final rng = Random();
 return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
 }

 @override
 void dispose() {
 _ringCtrl.dispose();
 _qrPulseCtrl.dispose();
 _refreshTimer?.cancel();
 super.dispose();
 }

 Color get _statusColor {
 switch (widget.ticket.status) {
 case 'CONFIRMED':
 return const Color(0xFF16A34A);
 case 'PENDING_APPROVAL':
 return MiloColors.amber;
 case 'REJECTED':
 return MiloColors.primary;
 default:
 return MiloColors.textMuted;
 }
 }

 String get _statusLabel {
 switch (widget.ticket.status) {
 case 'CONFIRMED':
 return widget.ticket.checkedIn ? 'CHECKED IN ' : 'VALID ';
 case 'PENDING_APPROVAL':
 return 'PENDING APPROVAL';
 case 'REJECTED':
 return 'REJECTED';
 default:
 return widget.ticket.status;
 }
 }

 @override
 Widget build(BuildContext context) {
 final ticket = widget.ticket;
 final event = ticket.event;

 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'My Ticket',
 style: GoogleFonts.outfit(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 leading: IconButton(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MiloColors.textPrimary),
 ),
 actions: [
 IconButton(
 onPressed: () {},
 icon: const Icon(Icons.share_rounded, color: MiloColors.textPrimary),
 ),
 ],
 ),
 body: SingleChildScrollView(
 padding: const EdgeInsets.symmetric(horizontal: 20),
 child: Column(
 children: [
 // Ticket Card 
 Container(
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(
 color: _statusColor.withValues(alpha: 0.3),
 width: 1.5,
 ),
 boxShadow: [
 BoxShadow(
 color: _statusColor.withValues(alpha: 0.15),
 blurRadius: 20,
 offset: const Offset(0, 6),
 ),
 ],
 ),
 child: Column(
 children: [
 // Event info header
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 MiloColors.primary.withValues(alpha: 0.15),
 Colors.transparent,
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 event.title,
 style: GoogleFonts.outfit(
 fontSize: 20,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 8),
 _InfoRow(icon: Icons.calendar_today_rounded, text: '${event.date} · ${event.time}'),
 const SizedBox(height: 4),
 _InfoRow(icon: Icons.location_on_rounded, text: event.venue),
 const SizedBox(height: 12),
 // Status badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: _statusColor.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: _statusColor.withValues(alpha: 0.4),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 8,
 height: 8,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: _statusColor,
 ),
 ),
 const SizedBox(width: 8),
 Text(
 _statusLabel,
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: _statusColor,
 letterSpacing: 0.5,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),

 // Perforated divider
 _PerforatedDivider(color: _statusColor.withValues(alpha: 0.2)),

 // QR Section
 if (ticket.status == 'CONFIRMED') ...[
 Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 children: [
 Text(
 'Scan at the gate',
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.textMuted,
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: 16),

 // QR + rotating ring
 AnimatedBuilder(
 animation: Listenable.merge([_ringCtrl, _qrPulseCtrl]),
 builder: (_, __) => Stack(
 alignment: Alignment.center,
 children: [
 // Glow
 Container(
 width: 220,
 height: 220,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: MiloColors.primary.withValues(alpha: _qrGlow.value * 0.3),
 blurRadius: 40,
 spreadRadius: 10,
 ),
 ],
 ),
 ),

 // White QR background
 Container(
 width: 200,
 height: 200,
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 ),
 padding: const EdgeInsets.all(12),
 child: _MockQRPainter(
 data: 'MILO1.${ticket.bookingId}.$_tokenSuffix',
 ),
 ),

 // Rotating progress ring
 SizedBox(
 width: 220,
 height: 220,
 child: CircularProgressIndicator(
 value: _ringProgress.value,
 strokeWidth: 3,
 backgroundColor: MiloColors.bgCard,
 valueColor: AlwaysStoppedAnimation<Color>(
 _ringProgress.value > 0.3
 ? MiloColors.primary
 : MiloColors.amber,
 ),
 ),
 ),

 // Countdown text
 Positioned(
 bottom: 8,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bg,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 'Refreshes in ${_secondsLeft}s',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: MiloColors.textMuted,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 12),
 // Watermark
 Text(
 '${ticket.attendeeName} • ${ticket.attendeePhone.replaceRange(3, 8, '*****')}',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: MiloColors.textMuted,
 letterSpacing: 0.5,
 ),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 ] else ...[
 Padding(
 padding: const EdgeInsets.all(20),
 child: Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 'QR code will appear once your booking is confirmed by the organizer.',
 style: GoogleFonts.inter(
 fontSize: 13,
 color: MiloColors.amber,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 ),
 ),
 ),
 ],

 // Perforated divider bottom
 _PerforatedDivider(color: _statusColor.withValues(alpha: 0.2)),

 // Ticket info rows
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
 child: Column(
 children: [
 _TicketInfoRow(label: 'Booking ID', value: ticket.bookingId),
 _TicketInfoRow(label: 'Tier', value: ticket.tier.name),
 _TicketInfoRow(label: 'Quantity', value: '${ticket.quantity} ticket${ticket.quantity > 1 ? 's' : ''}'),
 _TicketInfoRow(label: 'Amount Paid', value: '₹${ticket.totalAmount.toStringAsFixed(0)}'),
 _TicketInfoRow(label: 'Booked on', value: ticket.bookingTime),
 _TicketInfoRow(label: 'Payment', value: ticket.paymentMethod.replaceAll('_', ' ')),
 ],
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 20),

 // Actions
 Column(
 children: [
 _ActionButton(
 icon: Icons.directions_rounded,
 label: 'Get Directions',
 color: MiloColors.cyan,
 onTap: () {},
 ),
 const SizedBox(height: 10),
 _ActionButton(
 icon: Icons.download_rounded,
 label: 'Download PDF Ticket',
 color: MiloColors.textSecondary,
 onTap: () {},
 ),
 const SizedBox(height: 10),
 if (ticket.status == 'CONFIRMED' && !ticket.checkedIn)
 _ActionButton(
 icon: Icons.cancel_outlined,
 label: 'Request Cancellation & Refund',
 color: MiloColors.primary,
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => RefundRequestScreen(ticket: ticket),
 ),
 ),
 ),
 ],
 ),

 const SizedBox(height: 32),
 ],
 ),
 ),
 );
 }
}

class _InfoRow extends StatelessWidget {
 final IconData icon;
 final String text;
 const _InfoRow({required this.icon, required this.text});

 @override
 Widget build(BuildContext context) => Row(
 children: [
 Icon(icon, size: 14, color: MiloColors.textMuted),
 const SizedBox(width: 6),
 Flexible(
 child: Text(
 text,
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary),
 ),
 ),
 ],
 );
}

class _TicketInfoRow extends StatelessWidget {
 final String label;
 final String value;
 const _TicketInfoRow({required this.label, required this.value});

 @override
 Widget build(BuildContext context) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 6),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label, style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textMuted)),
 Text(
 value,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: MiloColors.textPrimary,
 ),
 ),
 ],
 ),
 );
}

class _ActionButton extends StatelessWidget {
 final IconData icon;
 final String label;
 final Color color;
 final VoidCallback onTap;

 const _ActionButton({
 required this.icon,
 required this.label,
 required this.color,
 required this.onTap,
 });

 @override
 Widget build(BuildContext context) => GestureDetector(
 onTap: onTap,
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: color.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 Icon(icon, size: 18, color: color),
 const SizedBox(width: 12),
 Text(
 label,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: color,
 ),
 ),
 const Spacer(),
 Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.5)),
 ],
 ),
 ),
 );
}

/// Perforated ticket divider
class _PerforatedDivider extends StatelessWidget {
 final Color color;
 const _PerforatedDivider({required this.color});

 @override
 Widget build(BuildContext context) {
 return Row(
 children: [
 Container(
 width: 20,
 height: 20,
 decoration: BoxDecoration(
 color: MiloColors.bg,
 borderRadius: const BorderRadius.only(
 topRight: Radius.circular(10),
 bottomRight: Radius.circular(10),
 ),
 ),
 ),
 Expanded(
 child: CustomPaint(
 painter: _DashedLinePainter(color: color),
 child: const SizedBox(height: 1),
 ),
 ),
 Container(
 width: 20,
 height: 20,
 decoration: BoxDecoration(
 color: MiloColors.bg,
 borderRadius: const BorderRadius.only(
 topLeft: Radius.circular(10),
 bottomLeft: Radius.circular(10),
 ),
 ),
 ),
 ],
 );
 }
}

class _DashedLinePainter extends CustomPainter {
 final Color color;
 const _DashedLinePainter({required this.color});

 @override
 void paint(Canvas canvas, Size size) {
 final paint = Paint()
 ..color = color
 ..strokeWidth = 1.5
 ..style = PaintingStyle.stroke;
 const dashW = 8.0;
 const gapW = 6.0;
 double x = 0;
 while (x < size.width) {
 canvas.drawLine(Offset(x, 0), Offset(x + dashW, 0), paint);
 x += dashW + gapW;
 }
 }

 @override
 bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

/// A simple mock QR code painted with Flutter (no package required for display)
class _MockQRPainter extends StatelessWidget {
 final String data;
 const _MockQRPainter({required this.data});

 @override
 Widget build(BuildContext context) {
 // Use a pattern-based pseudo-QR for demo; production uses `qr_flutter`
 return CustomPaint(
 painter: _QRPainter(data: data),
 );
 }
}

class _QRPainter extends CustomPainter {
 final String data;

 _QRPainter({required this.data});

 @override
 void paint(Canvas canvas, Size size) {
 final paint = Paint()..color = Colors.black;
 final rng = Random(data.hashCode);
 const grid = 25;
 final cell = size.width / grid;

 // Corner position markers (always drawn)
 void drawMarker(double ox, double oy) {
 // Outer square
 paint.color = Colors.black;
 canvas.drawRect(Rect.fromLTWH(ox * cell, oy * cell, 7 * cell, 7 * cell), paint);
 paint.color = Colors.white;
 canvas.drawRect(
 Rect.fromLTWH((ox + 1) * cell, (oy + 1) * cell, 5 * cell, 5 * cell),
 paint,
 );
 paint.color = Colors.black;
 canvas.drawRect(
 Rect.fromLTWH((ox + 2) * cell, (oy + 2) * cell, 3 * cell, 3 * cell),
 paint,
 );
 }

 drawMarker(0, 0);
 drawMarker(grid - 7, 0);
 drawMarker(0, grid - 7);

 // Data cells
 for (int row = 0; row < grid; row++) {
 for (int col = 0; col < grid; col++) {
 // Skip marker zones
 if ((row < 8 && col < 8) ||
 (row < 8 && col >= grid - 8) ||
 (row >= grid - 8 && col < 8)) {
 continue;
 }

 if (rng.nextBool()) {
 paint.color = Colors.black;
 canvas.drawRect(
 Rect.fromLTWH(col * cell, row * cell, cell, cell),
 paint,
 );
 }
 }
 }
 }

 @override
 bool shouldRepaint(_QRPainter old) => old.data != data;
}
