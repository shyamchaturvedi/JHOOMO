import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/milo_test_gateway.dart';
import '../theme/milo_theme.dart';

/// Sandbox checkout sheet for Milo Pay (test payment gateway).
class MiloTestGatewayCheckout extends StatefulWidget {
 final double amount;
 final String eventName;
 final Map<String, String> metadata;

 const MiloTestGatewayCheckout({
 super.key,
 required this.amount,
 required this.eventName,
 this.metadata = const {},
 });

 /// Opens the sandbox checkout. Returns the payment result, or null if
 /// the user dismissed the sheet.
 static Future<TestGatewayPaymentResult?> show(
 BuildContext context, {
 required double amount,
 required String eventName,
 Map<String, String> metadata = const {},
 }) {
 return showModalBottomSheet<TestGatewayPaymentResult>(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (ctx) => MiloTestGatewayCheckout(
 amount: amount,
 eventName: eventName,
 metadata: metadata,
 ),
 );
 }

 @override
 State<MiloTestGatewayCheckout> createState() => _MiloTestGatewayCheckoutState();
}

class _MiloTestGatewayCheckoutState extends State<MiloTestGatewayCheckout> {
 String _method = 'card';
 bool _processing = false;
 String? _error;

 final _cardController = TextEditingController(text: '4111 1111 1111 1111');
 final _expiryController = TextEditingController(text: '12/28');
 final _cvvController = TextEditingController(text: '123');
 final _nameController = TextEditingController(text: 'SAHIL KUMAR');
 final _upiController = TextEditingController(text: MiloTestGateway.successUpi);

 @override
 void dispose() {
 _cardController.dispose();
 _expiryController.dispose();
 _cvvController.dispose();
 _nameController.dispose();
 _upiController.dispose();
 super.dispose();
 }

 Future<void> _pay() async {
 setState(() {
 _error = null;
 _processing = true;
 });
 HapticFeedback.mediumImpact();
 try {
 final order = await MiloTestGateway.createOrder(
 amount: widget.amount,
 metadata: {
 'event': widget.eventName,
 ...widget.metadata,
 },
 );
 final result = await MiloTestGateway.capture(
 order: order,
 method: _method,
 cardNumber: _method == 'card' ? _cardController.text : null,
 upiVpa: _method == 'upi' ? _upiController.text : null,
 );
 if (!mounted) return;
 if (result.success) {
 Navigator.pop(context, result);
 } else {
 setState(() {
 _processing = false;
 _error = result.message;
 });
 HapticFeedback.heavyImpact();
 }
 } catch (e) {
 if (!mounted) return;
 setState(() {
 _processing = false;
 _error = 'Gateway error: $e';
 });
 }
 }

 @override
 Widget build(BuildContext context) {
 return ClipRRect(
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
 child: Container(
 padding: EdgeInsets.fromLTRB(
 22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 24),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.98),
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 border: Border.all(color: MiloColors.glassBorder, width: 1.2),
 ),
 child: SingleChildScrollView(
 physics: const BouncingScrollPhysics(),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Center(
 child: Container(
 width: 44,
 height: 4,
 decoration: BoxDecoration(
 color: MiloColors.textMuted.withValues(alpha: 0.4),
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 ),
 const SizedBox(height: 14),

 // Sandbox banner
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.cyan.withValues(alpha: 0.10),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.cyan.withValues(alpha: 0.4)),
 ),
 child: Row(
 children: [
 const Icon(Icons.science_outlined, color: MiloColors.cyan, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(MiloTestGateway.brandName,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary)),
 Text('No real money is charged. Test mode only.',
 style: GoogleFonts.inter(
 fontSize: 11, color: MiloColors.textSecondary)),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.amber,
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text('TEST',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w900,
 color: Colors.black)),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),

 // Amount row
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(widget.eventName,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary)),
 Text(MiloTestGateway.brandName,
 style:
 GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 ],
 ),
 ),
 Text('₹${widget.amount.toStringAsFixed(0)}',
 style: GoogleFonts.inter(
 fontSize: 24,
 fontWeight: FontWeight.w900,
 color: MiloColors.primary)),
 ],
 ),
 const SizedBox(height: 18),

 // Method tabs
 Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(children: [
 Expanded(
 child: _tab('card', ' Card', 'Visa / RuPay / Mastercard'),
 ),
 Expanded(child: _tab('upi', ' UPI', 'GPay / PhonePe / Paytm')),
 ]),
 ),
 const SizedBox(height: 16),

 if (_method == 'card') ...[
 _field('Card Number', _cardController, Icons.credit_card_rounded,
 hint: '4111 1111 1111 1111'),
 const SizedBox(height: 12),
 Row(children: [
 Expanded(
 child: _field('Expiry', _expiryController, Icons.calendar_month_rounded,
 hint: 'MM/YY')),
 const SizedBox(width: 12),
 Expanded(
 child: _field('CVV', _cvvController, Icons.lock_rounded,
 hint: '123', obscure: true)),
 ]),
 const SizedBox(height: 12),
 _field('Name on Card', _nameController, Icons.person_rounded),
 ] else ...[
 _field('UPI ID', _upiController, Icons.alternate_email_rounded,
 hint: MiloTestGateway.successUpi),
 const SizedBox(height: 10),
 Text(
 'Tip: use ${MiloTestGateway.failUpi} to simulate a failed payment.',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
 ),
 ],

 if (_error != null) ...[
 const SizedBox(height: 12),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.rose.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.rose.withValues(alpha: 0.5)),
 ),
 child: Row(children: [
 const Icon(Icons.error_outline_rounded, color: MiloColors.rose, size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(_error!,
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.rose,
 fontWeight: FontWeight.w700)),
 ),
 ]),
 ),
 ],

 const SizedBox(height: 14),

 // Sandbox rules
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: Text(
 'Sandbox rules — Card ${MiloTestGateway.successCard} → Success · '
 'Card ${MiloTestGateway.declineCard} → Declined · '
 'UPI ${MiloTestGateway.successUpi} → Success',
 style: GoogleFonts.inter(fontSize: 10.5, color: MiloColors.textMuted, height: 1.5),
 ),
 ),
 const SizedBox(height: 16),

 SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 elevation: 6,
 shadowColor: MiloColors.primaryGlow,
 ),
 onPressed: _processing ? null : _pay,
 child: _processing
 ? Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(
 strokeWidth: 2.2, color: MiloColors.bg),
 ),
 const SizedBox(width: 12),
 Text('Contacting gateway…',
 style: GoogleFonts.inter(
 fontWeight: FontWeight.w800, color: MiloColors.bg)),
 ],
 )
 : Text('Pay ₹${widget.amount.toStringAsFixed(0)} (Test)',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w900,
 color: MiloColors.bg)),
 ),
 ),
 const SizedBox(height: 8),
 Center(
 child: Text(
 'Secured by Milo Pay Sandbox · PCI-style test flow',
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _tab(String value, String title, String subtitle) {
 final selected = _method == value;
 return GestureDetector(
 onTap: () => setState(() {
 _method = value;
 _error = null;
 }),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(vertical: 10),
 decoration: BoxDecoration(
 color: selected ? MiloColors.primary : Colors.transparent,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Column(children: [
 Text(title,
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w900,
 color: selected ? MiloColors.textPrimary : MiloColors.textSecondary)),
 Text(subtitle,
 style: GoogleFonts.inter(
 fontSize: 9,
 color: selected ? Colors.white70 : MiloColors.textMuted)),
 ]),
 ),
 );
 }

 Widget _field(
 String label,
 TextEditingController controller,
 IconData icon, {
 String? hint,
 bool obscure = false,
 }) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 TextField(
 controller: controller,
 obscureText: obscure,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: MiloColors.textPrimary,
 letterSpacing: 0.8),
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
 border: InputBorder.none,
 isDense: true,
 prefixIcon: Icon(icon, size: 16, color: MiloColors.textMuted),
 prefixIconConstraints: const BoxConstraints(minWidth: 30),
 ),
 ),
 ],
 ),
 );
 }
}
