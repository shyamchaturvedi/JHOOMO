import '../services/milo_razorpay_service.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/milo_theme.dart';
import '../services/milo_api.dart';
import '../services/milo_session_service.dart';
import '../services/payment_approval_service.dart';
import '../screens/my_tickets_screen.dart';
import '../screens/chat/universal_broadcast_channel_screen.dart';

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
  bool _isProcessing = false;
  int _secondsRemaining = 599; // 10-Minute BMS Inventory Lock Timer
  Timer? _countdownTimer;

  final _nameController =
      TextEditingController(text: MiloSessionService.currentUserName);
  final _phoneController =
      TextEditingController(text: MiloSessionService.currentUserPhone);

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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _formattedTimer {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _triggerRazorpayCheckout() async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final amountPaise = (widget.totalAmount * 100).toInt();

      // Try server order creation if backend is reachable
      String? orderId;
      try {
        final booking = await MiloApi.instance.createBooking(
          eventId: widget.event.id,
          items: [
            {'tierId': widget.tier.id, 'qty': widget.quantity},
          ],
          referralCode: widget.referralCode,
        );
        orderId = booking['orderId']?.toString();
      } catch (err) {
        debugPrint('MiloApi createBooking note (using client test checkout): $err');
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Launch official Razorpay Checkout SDK dialog
      MiloRazorpayService.instance.openCheckout(
        context: context,
        event: widget.event,
        tier: widget.tier,
        quantity: widget.quantity,
        amountPaise: amountPaise,
        orderId: orderId,
        attendeeName: _nameController.text.trim(),
        attendeePhone: _phoneController.text.trim(),
        onSuccess: (response) async {
          if (!mounted) return;
          final paymentId = response.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
          final name = _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : MiloSessionService.currentUserName;
          final phone = _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : MiloSessionService.currentUserPhone;

          await PaymentApprovalService.instance.submitPaymentApprovalRequest(
            event: widget.event,
            tier: widget.tier,
            quantity: widget.quantity,
            totalAmount: widget.totalAmount,
            utrNumber: paymentId,
            attendeeName: name.isNotEmpty ? name : 'Verified Guest',
            attendeePhone: phone.isNotEmpty ? phone : '+91 9876543210',
            note: 'Razorpay Payment ID: $paymentId',
            paymentMethod: 'RAZORPAY',
          );
          if (!mounted) return;
          Navigator.pop(context);
          _showInstantConfirmationModal();
        },
        onError: (response) {
          _showError(
              'Payment cancelled / failed (${response.code}): ${response.message ?? 'Cancelled by user'}');
        },
        onExternalWallet: (response) {
          debugPrint('External wallet selected: ${response.walletName}');
        },
      );
    } on MiloApiException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Could not process payment. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
          message,
          style: GoogleFonts.inter(
              color: Colors.redAccent, fontWeight: FontWeight.w600),
        ),
      ),
    );
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
            border: Border.all(
                color: MiloColors.emerald.withValues(alpha: 0.5), width: 1.5),
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
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                'Booking Confirmed',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MiloColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Payment successful. Your QR tickets are ready in My Tickets.',
                style: GoogleFonts.inter(
                    color: MiloColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiloColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MyTicketsScreen()));
                  },
                  child: Text('View My Tickets',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          color: MiloColors.textPrimary,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE11D48)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UniversalBroadcastChannelScreen(
                          type: BroadcastType.eventOrganizer,
                          channelTitle:
                              widget.event.title + ' • Official Broadcast',
                          channelSubtitle: 'Verified Organizer Channel',
                          ownerName: widget.event.organizerName.isNotEmpty
                              ? widget.event.organizerName
                              : 'Event Host',
                          ownerHandle: '@' +
                              widget.event.organizerName
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'\s+'), ''),
                          ownerAvatar: widget.event.imageUrl,
                          ownerUid: 'org_' + widget.event.id,
                          event: widget.event,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.campaign_rounded,
                      color: Color(0xFFE11D48), size: 16),
                  label: Text('Open Event Broadcast Channel',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE11D48),
                          fontSize: 12)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MiloColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: MiloColors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: MiloColors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Passes Locked for You: $_formattedTimer mins remaining',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: MiloColors.amber),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: MiloColors.amber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formattedTimer,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black),
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
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: MiloColors.textPrimary),
                          ),
                          Text(
                            '${widget.quantity}x ${widget.tier.name} • ${widget.event.venue}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: MiloColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₹${widget.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: MiloColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                GestureDetector(
                  onTap: _isProcessing ? null : _triggerRazorpayCheckout,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Pay Now • ₹${widget.totalAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),

                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const Center(
                      child: CircularProgressIndicator(
                          color: MiloColors.primary, strokeWidth: 2.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
