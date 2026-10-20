import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../config.dart';
import '../services/payment_approval_service.dart';
import '../theme/milo_theme.dart';
import '../widgets/app_logo.dart';

class MyTicketsScreen extends StatefulWidget {
  final BookedTicket? initialBooking;

  const MyTicketsScreen({super.key, this.initialBooking});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late List<BookedTicket> _tickets;
  final Set<String> _reviewedTicketIds = {};

  void _showPostEventReviewDialog(BookedTicket ticket) {
    int selectedStars = 5;
    final Set<String> selectedCompliments = {'Punctual ⏱️', 'Great Vibe 😎'};
    final feedbackController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: MiloColors.glassBorder),
              ),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MiloColors.amber.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rate_rounded, color: MiloColors.amber, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rate Your Experience ⭐',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
                              ),
                              Text(
                                '${ticket.event.title} • Hosted by ${ticket.event.organizerName}',
                                style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Star Rating Bar (1 to 5 stars)
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          final isFilled = star <= selectedStars;
                          return IconButton(
                            iconSize: 36,
                            icon: Icon(
                              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFilled ? MiloColors.amber : MiloColors.textMuted,
                            ),
                            onPressed: () {
                              setModalState(() => selectedStars = star);
                            },
                          );
                        }),
                      ),
                    ),
                    Center(
                      child: Text(
                        selectedStars == 5
                            ? 'Outstanding Experience! 🌟'
                            : selectedStars >= 4
                                ? 'Great Meetup! 👍'
                                : selectedStars >= 3
                                    ? 'Average Experience 😐'
                                    : 'Needs Improvement 👎',
                        style: GoogleFonts.inter(
                          color: selectedStars >= 4 ? MiloColors.emerald : MiloColors.amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rapido Style Compliment Badges
                    Text('Give Host / Organizer Badges:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textPrimary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Punctual ⏱️',
                        'Great Vibe 😎',
                        'Safe & Secure 🛡️',
                        'Super Organized 📋',
                        'Fun Games 🎉',
                        'Friendly Crowd 🤝',
                      ].map((badge) {
                        final isSelected = selectedCompliments.contains(badge);
                        return FilterChip(
                          label: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? MiloColors.bg : MiloColors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: MiloColors.primaryLight,
                          backgroundColor: MiloColors.bgCard,
                          checkmarkColor: MiloColors.bg,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedCompliments.add(badge);
                              } else {
                                selectedCompliments.remove(badge);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Written Review Box
                    TextField(
                      controller: feedbackController,
                      style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Share public feedback about crowd, music, management or host...',
                        hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: MiloColors.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: MiloColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: MiloColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MiloColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _reviewedTicketIds.add(ticket.bookingId);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: MiloColors.bgSurface,
                              content: Text(
                                '🎉 Thank you! Your $selectedStars★ review & reputation badges were submitted!',
                                style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Submit Rating & Feedback 🚀',
                          style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tickets = List.from(PaymentApprovalService.instance.userTickets);
    if (widget.initialBooking != null && !_tickets.any((t) => t.bookingId == widget.initialBooking!.bookingId)) {
      _tickets.insert(0, widget.initialBooking!);
    }
    PaymentApprovalService.instance.addListener(_onPaymentUpdated);
  }

  void _onPaymentUpdated() {
    if (mounted) {
      setState(() {
        _tickets = List.from(PaymentApprovalService.instance.userTickets);
      });
    }
  }

  @override
  void dispose() {
    PaymentApprovalService.instance.removeListener(_onPaymentUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Event Passes', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18)),
        leading: widget.initialBooking != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: _tickets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 64, color: MiloColors.textMuted),
                  const SizedBox(height: 16),
                  Text('No tickets yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text('Book your first Garba or party pass!', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _tickets.length,
              itemBuilder: (context, index) {
                final ticket = _tickets[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: MiloColors.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: MiloColors.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: MiloColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Event Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MiloColors.bgCard,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const MiloAppLogo(size: 26, showText: true, showTagline: false),
                                Builder(builder: (context) {
                                  final isPending = ticket.status == 'PENDING_APPROVAL';
                                  final isRejected = ticket.status == 'REJECTED';
                                  final color = isPending
                                      ? MiloColors.amber
                                      : (isRejected ? MiloColors.rose : MiloColors.emerald);
                                  final label = isPending
                                      ? 'PENDING APPROVAL ⏳'
                                      : (isRejected ? 'REJECTED ❌' : 'VERIFIED PASS ✅');
                                  final icon = isPending
                                      ? Icons.hourglass_top_rounded
                                      : (isRejected ? Icons.cancel_rounded : Icons.check_circle);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: color),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, color: color, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          label,
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Pass Booking ID: #${ticket.bookingId}',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: MiloColors.textMuted),
                                  ),
                                ),
                                if (ticket.utrNumber.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MiloColors.bgSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: MiloColors.border),
                                    ),
                                    child: Text(
                                      'UTR: ${ticket.utrNumber}',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              ticket.event.title,
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: MiloColors.rose, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${ticket.event.venue}, ${ticket.event.city}',
                                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Dotted Ticket Divider
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: MiloColors.bg,
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Flex(
                                  direction: Axis.horizontal,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    (constraints.constrainWidth() / 10).floor(),
                                    (_) => const SizedBox(
                                      width: 5,
                                      height: 1.5,
                                      child: DecoratedBox(decoration: BoxDecoration(color: MiloColors.border)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: MiloColors.bg,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                            ),
                          ),
                        ],
                      ),

                      // Ticket Details & Glowing QR Section
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Pass Category', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                                    Text(ticket.tier.name, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('Quantity', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                                    Text('${ticket.quantity} Person(s)', style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Date', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
                                    Text(ticket.event.date.split(',')[0], style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // QR Container (Locked for PENDING_APPROVAL, Active for CONFIRMED)
                            if (ticket.status == 'PENDING_APPROVAL')
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: MiloColors.bgSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: MiloColors.amber.withValues(alpha: 0.6), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MiloColors.amber.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: MiloColors.amber.withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: MiloColors.amber.withValues(alpha: 0.5)),
                                      ),
                                      child: const Icon(Icons.lock_clock_rounded, size: 36, color: MiloColors.amber),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'PASS LOCKED • VERIFICATION PENDING',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: MiloColors.amber,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your Self UPI payment (UTR: ${ticket.utrNumber.isNotEmpty ? ticket.utrNumber : '329184729104'}) has been dispatched to ${ticket.event.organizerName}. This entry QR code will unlock as soon as the host taps Approve.',
                                      style: GoogleFonts.inter(
                                        color: MiloColors.textSecondary,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),
                                    // Quick Demo Approve Action
                                    SizedBox(
                                      width: double.infinity,
                                      height: 38,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: MiloColors.emerald),
                                          backgroundColor: MiloColors.emerald.withValues(alpha: 0.12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          final req = PaymentApprovalService.instance.approvalRequests.firstWhere(
                                            (r) => r.bookingId == ticket.bookingId,
                                            orElse: () => PaymentApprovalService.instance.approvalRequests.first,
                                          );
                                          PaymentApprovalService.instance.approveRequest(req.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: MiloColors.bgSurface,
                                              content: Text('🎉 Pass approved by Organizer! QR unlocked.',
                                                  style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.flash_on_rounded, size: 16, color: MiloColors.emerald),
                                        label: Text(
                                          'Simulate Host Approval (Demo Instant Unlock)',
                                          style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (ticket.status == 'REJECTED')
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: MiloColors.bgSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: MiloColors.rose, width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.cancel_rounded, size: 48, color: MiloColors.rose),
                                    const SizedBox(height: 10),
                                    Text('PAYMENT FLAGGED BY ORGANIZER',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: MiloColors.rose)),
                                    const SizedBox(height: 6),
                                    Text(
                                      ticket.rejectionReason.isNotEmpty
                                          ? ticket.rejectionReason
                                          : 'UTR not found in host bank statement. Please contact host or re-submit.',
                                      style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: MiloColors.primaryLight.withValues(alpha: 0.25),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black),
                                        const SizedBox(height: 6),
                                        Text(
                                          'SCAN AT VENUE GATE',
                                          style: GoogleFonts.inter(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Show this QR at the venue entrance for fast-track entry. Do not share screenshot.',
                                    style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            // Post Event Review & Rate Host Button
                            if (_reviewedTicketIds.contains(ticket.bookingId))
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: MiloColors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Review & Rating Submitted! ⭐ (Thank You)',
                                      style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.star_rounded, size: 18, color: MiloColors.amber),
                                  label: Text(
                                    'Rate Event & Host ⭐ (Post-Event Review)',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MiloColors.bgCard,
                                    side: BorderSide(color: MiloColors.amber.withValues(alpha: 0.6)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => _showPostEventReviewDialog(ticket),
                                ),
                              ),
                            const SizedBox(height: 14),
                            const Center(
                              child: MiloBrandedWatermark(label: 'Verified Milo Fast-Track Gate Pass 🎟️'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.share_outlined, size: 16, color: MiloColors.primaryLight),
                                    label: Text('Share Pass', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: MiloColors.primaryLight),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: MiloColors.bgSurface,
                                          content: Text(
                                            '🎟️ Milo Verified Pass copied: "${ticket.event.title} (${ticket.tier.name}) • Booked on Milo App: ${MiloConfig.passLink(ticket.bookingId)}"',
                                            style: GoogleFonts.inter(color: MiloColors.primaryLight),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.wallet, size: 16, color: MiloColors.bg),
                                    label: Text('Save Offline', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w700, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MiloColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Ticket saved offline to Device Secure Storage! 📱')),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
