import '../services/milo_razorpay_service.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/milo_theme.dart';
import '../services/payment_approval_service.dart';
import '../services/milo_promoter_tracking_service.dart';
import '../screens/my_tickets_screen.dart';
import '../screens/chat/universal_broadcast_channel_screen.dart';
import 'milo_test_gateway_checkout.dart';

enum PaymentMode { instantBms, directUpi, cashAtGate }

class MiloBmsPaymentSheet extends StatefulWidget {
 final EventModel event;
 final TicketTier tier;
 final int quantity;
 final double totalAmount;
 final String? referralCode;

 const MiloBmsPaymentSheet({
 super.key,
 required this.event,
 required this.tier,
 required this.quantity,
 required this.totalAmount,
 this.referralCode,
 });

 static Future<void> show(
 BuildContext context, {
 required EventModel event,
 required TicketTier tier,
 required int quantity,
 required double totalAmount,
 String? referralCode,
 }) {
 return showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (context) => MiloBmsPaymentSheet(
 event: event,
 tier: tier,
 quantity: quantity,
 totalAmount: totalAmount,
 referralCode: referralCode,
 ),
 );
 }

 @override
 State<MiloBmsPaymentSheet> createState() => _MiloBmsPaymentSheetState();
}

class _MiloBmsPaymentSheetState extends State<MiloBmsPaymentSheet> {
 PaymentMode _selectedMode = PaymentMode.instantBms;
 bool _isProcessing = false;
 int _secondsRemaining = 599; // 10-Minute BMS Inventory Lock Timer
 Timer? _countdownTimer;

 // Manual UPI Controllers
 final _utrController = TextEditingController();
 final _nameController = TextEditingController(text: 'Sahil (Verified Member)');
 final _phoneController = TextEditingController(text: '+91 98765 43210');
 String? _validationError;

 String get _organizerUpiId =>
 '${widget.event.organizerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.milo@okhdfcbank';

 @override
 void initState() {
 super.initState();
 _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
 if (_secondsRemaining > 0 && mounted) {
 setState(() => _secondsRemaining--);
 } else {
 timer.cancel();
 }
 });
 }

 @override
 void dispose() {
 _countdownTimer?.cancel();
 _utrController.dispose();
 _nameController.dispose();
 _phoneController.dispose();
 super.dispose();
 }

 String get _formattedTimer {
 final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
 final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
 return '$m:$s';
 }

 
  void _triggerRazorpayCheckout() {
    HapticFeedback.mediumImpact();
    MiloRazorpayService.instance.openCheckout(
      context: context,
      event: widget.event,
      tier: widget.tier,
      quantity: widget.quantity,
      totalAmount: widget.totalAmount,
      attendeeName: _nameController.text.trim(),
      attendeePhone: _phoneController.text.trim(),
      onSuccess: (response) {
        Navigator.pop(context); // close sheet
        PaymentApprovalService.instance.submitPaymentApprovalRequest(
          event: widget.event,
          tier: widget.tier,
          quantity: widget.quantity,
          totalAmount: widget.totalAmount,
          utrNumber: response.paymentId ?? 'RZP_${DateTime.now().millisecondsSinceEpoch}',
          attendeeName: _nameController.text.trim(),
          attendeePhone: _phoneController.text.trim(),
          organizerUpiId: 'milo.pay@razorpay',
          proofImageUrl: null,
          note: 'Verified online via Razorpay (Payment ID: ${response.paymentId})',
          paymentMethod: 'RAZORPAY',
          autoConfirm: true,
        );

        if (widget.referralCode != null && widget.referralCode!.isNotEmpty) {
          MiloPromoterTrackingService.instance.recordTicketSaleFromReferral(
            referralCode: widget.referralCode!,
            eventId: widget.event.id,
            eventTitle: widget.event.title,
            tierName: widget.tier.name,
            quantity: widget.quantity,
            totalAmount: widget.totalAmount,
            buyerName: _nameController.text.trim(),
          );
        }

        _showInstantConfirmationModal();
      },
      onError: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              'Payment Cancelled / Failed (${response.code}): ${response.message}',
              style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
      onExternalWallet: (response) {
        debugPrint('External wallet: ${response.walletName}');
      },
    );
  }

  Future<void> _triggerInstantBmsPayment(String appName) async {
 HapticFeedback.mediumImpact();

 // Milo Pay — sandbox gateway checkout (test mode, no real money).
 final result = await MiloTestGatewayCheckout.show(
 context,
 amount: widget.totalAmount,
 eventName: widget.event.title,
 metadata: {
 'wallet': appName,
 'tier': widget.tier.name,
 'quantity': widget.quantity.toString(),
 },
 );

 if (!mounted) return;
 if (result == null) return; // user dismissed checkout
 if (!result.success) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Payment failed: ${result.message}',
 style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w700)),
 ),
 );
 return;
 }

 Navigator.pop(context); // Close payment sheet

 // Instant confirmed ticket via verified gateway payment
 PaymentApprovalService.instance.submitPaymentApprovalRequest(
 event: widget.event,
 tier: widget.tier,
 quantity: widget.quantity,
 totalAmount: widget.totalAmount,
 utrNumber: result.paymentId,
 attendeeName: _nameController.text.trim(),
 attendeePhone: _phoneController.text.trim(),
 organizerUpiId: 'milo.pay@icici',
 proofImageUrl: null,
 note: 'Auto-verified via $appName — Milo Pay sandbox payment ${result.orderId}',
 paymentMethod: 'MILO_TEST_GATEWAY',
 autoConfirm: true,
 );

 // Record Promoter / Influencer Attribution if referral applied
 if (widget.referralCode != null && widget.referralCode!.isNotEmpty) {
 MiloPromoterTrackingService.instance.recordTicketSaleFromReferral(
 referralCode: widget.referralCode!,
 eventId: widget.event.id,
 eventTitle: widget.event.title,
 tierName: widget.tier.name,
 quantity: widget.quantity,
 totalAmount: widget.totalAmount,
 buyerName: _nameController.text.trim(),
 );
 }

 _showInstantConfirmationModal();
 }

 void _triggerPayAtGateCash() {
 setState(() => _isProcessing = true);
 HapticFeedback.lightImpact();

 Future.delayed(const Duration(milliseconds: 700), () {
 if (!mounted) return;
 setState(() => _isProcessing = false);
 Navigator.pop(context);

 PaymentApprovalService.instance.submitPaymentApprovalRequest(
 event: widget.event,
 tier: widget.tier,
 quantity: widget.quantity,
 totalAmount: widget.totalAmount,
 utrNumber: 'CASH-GATE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
 attendeeName: _nameController.text.trim(),
 attendeePhone: _phoneController.text.trim(),
 organizerUpiId: 'PAY-AT-VENUE',
 proofImageUrl: null,
 note: 'Pay at Venue Gate (Cash)',
 );

 _showGateCashReservedModal();
 });
 }

 void _submitDirectUpi() {
 final utr = _utrController.text.trim();
 if (utr.length < 8) {
 setState(() => _validationError = 'Please enter valid 8-12 digit UTR / Reference No.');
 return;
 }

 setState(() {
 _validationError = null;
 _isProcessing = true;
 });

 Future.delayed(const Duration(milliseconds: 900), () {
 if (!mounted) return;
 setState(() => _isProcessing = false);
 Navigator.pop(context);

 PaymentApprovalService.instance.submitPaymentApprovalRequest(
 event: widget.event,
 tier: widget.tier,
 quantity: widget.quantity,
 totalAmount: widget.totalAmount,
 utrNumber: utr,
 attendeeName: _nameController.text.trim(),
 attendeePhone: _phoneController.text.trim(),
 organizerUpiId: _organizerUpiId,
 proofImageUrl: null,
 note: 'Direct Host UPI Transfer Verification Pending',
 );

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 behavior: SnackBarBehavior.floating,
 content: Text('Payment proof submitted to ${widget.event.organizerName}! ',
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700)),
 ),
 );
 });
 }

 void _showInstantConfirmationModal() {
 showModalBottomSheet(
 context: context,
 backgroundColor: Colors.transparent,
 builder: (ctx) => ClipRRect(
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 child: Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.5), width: 1.5),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: const BoxDecoration(
 color: MiloColors.emerald,
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
 ),
 const SizedBox(height: 18),
 Text(
 'Instant Pass Confirmed! ',
 style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 const SizedBox(height: 6),
 Text(
                    'Payment verified via Milo Pay. Your dynamic anti-fraud QR code is ready for entry at Gate 1.',
                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Broadcast Auto-Enroll Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF1F2), Color(0xFFFFFAF9)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Joined Official Broadcast Channel',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF881337)),
                              ),
                              Text(
                                'Live gate alerts, parking maps & host updates.',
                                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9F1239)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiloColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
                      },
                      child: Text('View M-Ticket QR Pass 🎟️',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE11D48)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UniversalBroadcastChannelScreen(
                              type: BroadcastType.eventOrganizer,
                              channelTitle: widget.event.title + ' • Official Broadcast',
                              channelSubtitle: 'Verified Organizer Channel',
                              ownerName: widget.event.organizerName.isNotEmpty ? widget.event.organizerName : 'Event Host',
                              ownerHandle: '@' + widget.event.organizerName.toLowerCase().replaceAll(RegExp(r'\s+'), ''),
                              ownerAvatar: widget.event.imageUrl,
                              ownerUid: 'org_' + widget.event.id,
                              event: widget.event,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.campaign_rounded, color: Color(0xFFE11D48), size: 16),
                      label: Text('Open Event Broadcast Channel',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFFE11D48), fontSize: 12)),
                    ),
                  ),
                ],
 ),
 ),
 ),
 );
 }

 void _showGateCashReservedModal() {
 showModalBottomSheet(
 context: context,
 backgroundColor: Colors.transparent,
 builder: (ctx) => ClipRRect(
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 child: Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 border: Border.all(color: MiloColors.amber.withValues(alpha: 0.5), width: 1.5),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: const BoxDecoration(
 color: MiloColors.amber,
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.payments_rounded, color: Colors.black, size: 40),
 ),
 const SizedBox(height: 18),
 Text(
 'Spot Reserved — Pay at Gate! ',
 style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 const SizedBox(height: 6),
 Text(
 'Your ticket is held. Show this pending pass at the gate counter, pay ₹${widget.totalAmount.toStringAsFixed(0)} cash to staff, and enter.',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 24),
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 ),
 onPressed: () {
 Navigator.pop(ctx);
 Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
 },
 child: Text('Check Ticket Status ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 15)),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return ClipRRect(
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
 child: Container(
 padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 24),
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
 // Top Grab Handle
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

 // BMS 10-Minute Seat/Ticket Lock Banner
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.amber.withValues(alpha: 0.35)),
 ),
 child: Row(
 children: [
 const Icon(Icons.timer_outlined, color: MiloColors.amber, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Passes Locked for You: $_formattedTimer mins remaining',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.amber),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.amber,
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 _formattedTimer,
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 18),

 // Order Summary Header
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 widget.event.title,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 Text(
 '${widget.quantity}x ${widget.tier.name} • ${widget.event.venue}',
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Text(
 '₹${widget.totalAmount.toStringAsFixed(0)}',
 style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: MiloColors.primary),
 ),
 ],
 ),
 const SizedBox(height: 18),

 // Payment Mode Segment Switcher
 Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 children: [
 Expanded(
 child: _buildSegmentOption(
 mode: PaymentMode.instantBms,
 title: ' Milo Pay',
 subtitle: 'Test Gateway',
 ),
 ),
 Expanded(
 child: _buildSegmentOption(
 mode: PaymentMode.directUpi,
 title: ' Host UPI',
 subtitle: '0% Platform Fee',
 ),
 ),
 Expanded(
 child: _buildSegmentOption(
 mode: PaymentMode.cashAtGate,
 title: ' Pay at Gate',
 subtitle: 'Cash on Entry',
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),

 // Content depending on selected mode
 if (_selectedMode == PaymentMode.instantBms) ...[
 Text(
 'Instant 1-Tap Checkout · Milo Pay Sandbox',
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 const SizedBox(height: 4),
 Text(
 'Test mode — no real money is charged.',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.cyan),
 ),
 const SizedBox(height: 10),
  // Primary Live Razorpay Gateway
  GestureDetector(
  onTap: _triggerRazorpayCheckout,
  child: Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  decoration: BoxDecoration(
  gradient: const LinearGradient(
  colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
  BoxShadow(
  color: const Color(0xFFE11D48).withValues(alpha: 0.35),
  blurRadius: 10,
  offset: const Offset(0, 4),
  ),
  ],
  ),
  child: Row(
  children: [
  Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
  color: Colors.white.withValues(alpha: 0.2),
  borderRadius: BorderRadius.circular(10),
  ),
  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
  ),
  const SizedBox(width: 12),
  Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  'Pay with Razorpay (Live UPI & Cards)',
  style: GoogleFonts.inter(
  fontWeight: FontWeight.w800,
  color: Colors.white,
  fontSize: 14,
  ),
  ),
  Text(
  'GPay, PhonePe, Paytm, Cards & NetBanking',
  style: GoogleFonts.inter(
  fontSize: 11,
  color: Colors.white70,
  ),
  ),
  ],
  ),
  ),
  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
  ],
  ),
  ),
  ),
  const SizedBox(height: 6),
  Text(
  'Or Quick Sandbox Payment:',
  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.textMuted),
  ),
  const SizedBox(height: 6),
  _buildInstantPaymentTile('Google Pay (Sandbox)', Icons.account_balance_wallet_rounded, const Color(0xFF4285F4)),
  _buildInstantPaymentTile('PhonePe (Sandbox)', Icons.phone_android_rounded, const Color(0xFF5F259F)),
  _buildInstantPaymentTile('Paytm / CRED UPI (Sandbox)', Icons.bolt_rounded, const Color(0xFF00B9F5)),
 ] else if (_selectedMode == PaymentMode.directUpi) ...[
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Host UPI ID', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 GestureDetector(
 onTap: () {
 Clipboard.setData(ClipboardData(text: _organizerUpiId));
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('UPI ID Copied: $_organizerUpiId',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
 ),
 );
 },
 child: Text('Copy', style: GoogleFonts.inter(color: MiloColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(_organizerUpiId, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 12),
 TextField(
 controller: _utrController,
 keyboardType: TextInputType.number,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 hintText: 'Enter 12-Digit UTR Number after payment',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 filled: true,
 fillColor: MiloColors.bgSurface,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
 ),
 ),
 if (_validationError != null) ...[
 const SizedBox(height: 6),
 Text(_validationError!, style: GoogleFonts.inter(color: MiloColors.rose, fontSize: 11)),
 ],
 ],
 ),
 ),
 const SizedBox(height: 14),
 SizedBox(
 width: double.infinity,
 height: 50,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: _isProcessing ? null : _submitDirectUpi,
 child: Text('Submit UTR for Host Verification',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 ),
 ),
 ] else ...[
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.storefront_rounded, color: MiloColors.amber, size: 20),
 const SizedBox(width: 8),
 Text('Pay at Event Gate Instructions',
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 '1. Ticket will be reserved under your name.\n2. Arrive at the venue gate at least 20 minutes before start.\n3. Show booking ID to staff scanner and pay ₹${widget.totalAmount.toStringAsFixed(0)} cash.',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.4),
 ),
 ],
 ),
 ),
 const SizedBox(height: 14),
 SizedBox(
 width: double.infinity,
 height: 50,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.amber,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: _isProcessing ? null : _triggerPayAtGateCash,
 child: Text('Reserve & Pay Cash at Venue',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.black)),
 ),
 ),
 ],

 if (_isProcessing) ...[
 const SizedBox(height: 16),
 const Center(child: CircularProgressIndicator(color: MiloColors.primary, strokeWidth: 2.5)),
 ],
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildSegmentOption({required PaymentMode mode, required String title, required String subtitle}) {
 final isSelected = _selectedMode == mode;
 return GestureDetector(
 onTap: () {
 HapticFeedback.selectionClick();
 setState(() => _selectedMode = mode);
 },
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary : Colors.transparent,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Column(
 children: [
 Text(
 title,
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 color: isSelected ? MiloColors.textPrimary : MiloColors.textSecondary,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 2),
 Text(
 subtitle,
 style: GoogleFonts.inter(
 fontSize: 9,
 color: isSelected ? Colors.white70 : MiloColors.textMuted,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildInstantPaymentTile(String name, IconData icon, Color color) {
 return GestureDetector(
 onTap: () => _triggerInstantBmsPayment(name),
 child: Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(icon, color: color, size: 18),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Text(name,
 style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: MiloColors.textPrimary, fontSize: 13)),
 ),
 const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: MiloColors.textMuted),
 ],
 ),
 ),
 );
 }
}
