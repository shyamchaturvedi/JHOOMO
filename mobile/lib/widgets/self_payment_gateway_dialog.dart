import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/milo_theme.dart';
import '../services/payment_approval_service.dart';
import '../screens/my_tickets_screen.dart';

class SelfPaymentGatewayDialog extends StatefulWidget {
  final EventModel event;
  final TicketTier tier;
  final int quantity;
  final double totalAmount;

  const SelfPaymentGatewayDialog({
    super.key,
    required this.event,
    required this.tier,
    required this.quantity,
    required this.totalAmount,
  });

  static Future<void> show(
    BuildContext context, {
    required EventModel event,
    required TicketTier tier,
    required int quantity,
    required double totalAmount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelfPaymentGatewayDialog(
        event: event,
        tier: tier,
        quantity: quantity,
        totalAmount: totalAmount,
      ),
    );
  }

  @override
  State<SelfPaymentGatewayDialog> createState() => _SelfPaymentGatewayDialogState();
}

class _SelfPaymentGatewayDialogState extends State<SelfPaymentGatewayDialog> {
  final _utrController = TextEditingController();
  final _nameController = TextEditingController(text: 'Sahil (Verified Member)');
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _noteController = TextEditingController();

  bool _isProofUploaded = true;
  final String _proofFileName = 'upi_payment_screenshot.jpg';
  bool _isSubmitting = false;
  String? _validationError;

  // Derive an organizer UPI ID based on event
  String get _organizerUpiId {
    final clean = widget.event.organizerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$clean@okhdfcbank';
  }

  void _copyUpiId() {
    Clipboard.setData(ClipboardData(text: _organizerUpiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MiloColors.bgSurface,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 20),
            const SizedBox(width: 8),
            Text('UPI ID Copied: $_organizerUpiId',
                style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirectUpiApp() async {
    final upiUri = Uri.parse(
      'upi://pay?pa=$_organizerUpiId&pn=${Uri.encodeComponent(widget.event.organizerName)}&am=${widget.totalAmount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Ticket for ${widget.event.title}")}',
    );

    try {
      if (await canLaunchUrl(upiUri)) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      } else {
        _copyUpiId();
      }
    } catch (_) {
      _copyUpiId();
    }
  }

  void _submitForApproval() {
    final utr = _utrController.text.trim();
    if (utr.isEmpty) {
      setState(() => _validationError = 'Please enter the 12-digit UTR / UPI Reference ID');
      return;
    }
    if (utr.length < 8) {
      setState(() => _validationError = 'UTR number must be at least 8-12 digits');
      return;
    }

    setState(() {
      _validationError = null;
      _isSubmitting = true;
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      PaymentApprovalService.instance.submitPaymentApprovalRequest(
        event: widget.event,
        tier: widget.tier,
        quantity: widget.quantity,
        totalAmount: widget.totalAmount,
        utrNumber: utr,
        attendeeName: _nameController.text.trim(),
        attendeePhone: _phoneController.text.trim(),
        organizerUpiId: _organizerUpiId,
        proofImageUrl: _isProofUploaded ? 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400&q=80' : null,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close gateway sheet

      // Show confirmation dialog
      _showSubmittedSuccessSheet();
    });
  }

  void _showSubmittedSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface.withValues(alpha: 0.98),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: MiloColors.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: MiloGradients.primaryBrand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: MiloColors.primary.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Payment Submitted to Organizer! ⏳',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: MiloColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your payment proof (UTR: ${_utrController.text}) has been routed to "${widget.event.organizerName}". As soon as they verify, your entry QR code pass will unlock automatically.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MiloColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiloColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
                        );
                      },
                      child: Text(
                        'View My Passes & Status 🎟️',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.bg, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                // Modal Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MiloColors.primaryLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Top Banner: Self Payment Gateway
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: MiloGradients.primaryBrand,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Self Payment Gateway',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MiloColors.emerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: MiloColors.emerald, width: 0.8),
                                ),
                                child: Text('0% FEE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
                              ),
                            ],
                          ),
                          Text(
                            'Direct Organizer UPI • Manual Approval Flow',
                            style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Order Payable Summary Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MiloColors.bgCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MiloColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.event.title,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('${widget.tier.name} × ${widget.quantity} Passes',
                              style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textSecondary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('AMOUNT TO PAY',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: MiloColors.primaryLight, letterSpacing: 0.8)),
                          Text('₹${widget.totalAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: MiloColors.primaryLight)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Step 1: Scan & Pay to Organizer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MiloColors.primary.withValues(alpha: 0.15),
                        MiloColors.bgCard,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // High-res Stylized QR Code Badge
                          Container(
                            width: 100,
                            height: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: MiloColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(
                                  'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=$_organizerUpiId%26pn=${Uri.encodeComponent(widget.event.organizerName)}%26am=${widget.totalAmount.toStringAsFixed(0)}',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.black87),
                                      Text('SCAN UPI', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: MiloColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bolt, color: Colors.white, size: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Organizer info & Copy Action
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'STEP 1: PAY ORGANIZER',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: MiloColors.primaryLight, letterSpacing: 1),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: MiloColors.emerald, size: 12),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.event.organizerName,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // UPI ID Pill
                                GestureDetector(
                                  onTap: _copyUpiId,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: MiloColors.bgSurface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: MiloColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _organizerUpiId,
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.copy_rounded, color: MiloColors.primaryLight, size: 14),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Scan QR or copy UPI ID into GPay / PhonePe / Paytm / BHIM',
                                  style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quick App Launcher Button
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: MiloColors.primaryLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: MiloColors.primary.withValues(alpha: 0.1),
                          ),
                          onPressed: _openDirectUpiApp,
                          icon: const Icon(Icons.open_in_new_rounded, size: 15, color: MiloColors.primaryLight),
                          label: Text(
                            'Open Installed UPI Apps (PhonePe / GPay)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: MiloColors.primaryLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Step 2: Verification Details
                Text(
                  'STEP 2: SUBMIT PAYMENT PROOF',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: MiloColors.primaryLight, letterSpacing: 1),
                ),
                const SizedBox(height: 10),

                // 12-Digit UTR Input (Mandatory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: MiloColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _validationError != null ? MiloColors.rose : MiloColors.glassBorder,
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _utrController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.pin_rounded, color: MiloColors.primaryLight, size: 20),
                      hintText: 'Enter 12-Digit UTR / Transaction Ref ID',
                      hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12, letterSpacing: 0),
                      border: InputBorder.none,
                      suffixIcon: TextButton(
                        onPressed: () {
                          // Quick sample paste for easy testing
                          setState(() {
                            _utrController.text = '${DateTime.now().millisecondsSinceEpoch}'.substring(1);
                          });
                        },
                        child: Text('PASTE DEMO', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
                      ),
                    ),
                  ),
                ),
                if (_validationError != null) ...[
                  const SizedBox(height: 6),
                  Text(_validationError!, style: GoogleFonts.inter(color: MiloColors.rose, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 10),

                // Screenshot Attachment Simulator
                GestureDetector(
                  onTap: () {
                    setState(() => _isProofUploaded = !_isProofUploaded);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: MiloColors.bgSurface,
                        content: Text(
                          _isProofUploaded ? '📎 Payment screenshot attached successfully!' : 'Proof removed',
                          style: GoogleFonts.inter(color: MiloColors.textPrimary),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isProofUploaded ? MiloColors.emerald.withValues(alpha: 0.12) : MiloColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isProofUploaded ? MiloColors.emerald : MiloColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isProofUploaded ? Icons.check_circle_rounded : Icons.add_photo_alternate_outlined,
                          color: _isProofUploaded ? MiloColors.emerald : MiloColors.primaryLight,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isProofUploaded ? 'Payment Proof Attached: $_proofFileName' : 'Upload Payment Screenshot / Receipt',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _isProofUploaded ? MiloColors.emerald : MiloColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Organizer will inspect this screenshot before approving',
                                style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: MiloColors.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isProofUploaded ? 'Change' : 'Browse',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.primaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Attendee WhatsApp / Phone for verification notification
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: MiloColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MiloColors.border),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.phone_iphone_rounded, color: MiloColors.primaryLight, size: 20),
                      hintText: 'WhatsApp / Phone Number for Pass updates',
                      hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit to Organizer Action Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiloColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: MiloColors.primaryGlow,
                    ),
                    onPressed: _isSubmitting ? null : _submitForApproval,
                    child: _isSubmitting
                        ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, color: MiloColors.bg, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Submit for Organizer Approval • ₹${widget.totalAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.bg, fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '🛡️ Organizer will receive an instant approval request on their dashboard.',
                    style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
