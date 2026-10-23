import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../config.dart';
import '../services/payment_approval_service.dart';
import '../theme/milo_theme.dart';

class MyTicketsScreen extends StatefulWidget {
  final BookedTicket? initialBooking;

  const MyTicketsScreen({super.key, this.initialBooking});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late List<BookedTicket> _tickets;
  final Set<String> _reviewedTicketIds = {};
  final Set<String> _expandedDetails = {};

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
                  Text('Book your first event pass on JHOOMO!', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _tickets.length,
              itemBuilder: (context, index) {
                final ticket = _tickets[index];
                final isExpanded = _expandedDetails.contains(ticket.bookingId);
                final isPending = ticket.status == 'PENDING_APPROVAL';
                final isRejected = ticket.status == 'REJECTED';

                // Calculation breakdown
                final basePrice = ticket.tier.price * ticket.quantity;
                final gst = (basePrice * 0.18);
                final convenienceFee = (basePrice > 0 ? 30.0 : 0.0);
                final discount = (ticket.quantity >= 3 ? (basePrice * 0.10) : 0.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    children: [
                      // Top Action Bar: SHARE YOUR TICKET
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 6, right: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF1E293B),
                                    content: Text(
                                      '🎟️ Milo Verified Pass copied: "${ticket.event.title} (${ticket.tier.name}) • Pass Link: ${MiloConfig.passLink(ticket.bookingId)}"',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.share_outlined, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SHARE YOUR TICKET',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? const Color(0xFFFEF3C7)
                                    : (isRejected ? const Color(0xFFFFE4E6) : const Color(0xFFD1FAE5)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isPending
                                    ? 'VERIFICATION PENDING ⏳'
                                    : (isRejected ? 'REJECTED ❌' : 'VERIFIED PASS ✅'),
                                style: GoogleFonts.inter(
                                  color: isPending
                                      ? const Color(0xFFB45309)
                                      : (isRejected ? const Color(0xFFE11D48) : const Color(0xFF047857)),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── MAIN BMS WHITE TICKET CARD ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 1. Top Section: Poster + Title + Details + Vertical M-Ticket
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event Poster Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          ticket.event.imageUrl,
                                          width: 78,
                                          height: 108,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 78,
                                            height: 108,
                                            color: const Color(0xFFE2E8F0),
                                            child: const Icon(Icons.event_seat_rounded, color: Colors.grey),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            color: const Color(0xFFE11D48),
                                            child: Text(
                                              'Live Pass',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Event Information
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ticket.event.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF0F172A),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${ticket.event.category} • ${ticket.tier.name}',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          ticket.event.date,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF1E293B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${ticket.event.venue}, ${ticket.event.city}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 11,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // BMS Vertical "M-Ticket" Label
                                  RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      'M-Ticket',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Interactive Toggle Pill: "Tap for support, details & more actions"
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedDetails.remove(ticket.bookingId);
                                    } else {
                                      _expandedDetails.add(ticket.bookingId);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isExpanded ? 'Tap to hide details' : 'Tap for support, details & more actions',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF475569),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: const Color(0xFF475569),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 3. BMS Perforated Notch Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: MiloColors.bg,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                                    ),
                                  ),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Flex(
                                          direction: Axis.horizontal,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: List.generate(
                                            (constraints.constrainWidth() / 8).floor(),
                                            (_) => const SizedBox(
                                              width: 4,
                                              height: 1.2,
                                              child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE2E8F0))),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    width: 14,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: MiloColors.bg,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 4. BMS QR Code & Seating / Tier Section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                              child: isPending
                                  ? Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.lock_clock_rounded, size: 36, color: Color(0xFFD97706)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'PASS LOCKED • VERIFICATION PENDING',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFB45309),
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'UTR: ${ticket.utrNumber.isNotEmpty ? ticket.utrNumber : '329184729104'} dispatched to ${ticket.event.organizerName}. QR will unlock on approval.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(color: const Color(0xFF78350F), fontSize: 11),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            height: 34,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                                              label: Text(
                                                'Simulate Host Approval (Demo Unlock)',
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                              ),
                                              onPressed: () {
                                                final req = PaymentApprovalService.instance.approvalRequests.firstWhere(
                                                  (r) => r.bookingId == ticket.bookingId,
                                                  orElse: () => PaymentApprovalService.instance.approvalRequests.first,
                                                );
                                                PaymentApprovalService.instance.approveRequest(req.id);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: const Color(0xFF047857),
                                                    content: Text('🎉 Pass approved by Organizer! QR unlocked.',
                                                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : isRejected
                                      ? Column(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFE4E6),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'YOUR BOOKING HAS FAILED',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFFBE123C),
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Transaction could not be completed in session time. If any money has been debited it will be refunded shortly to the original payment mode.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF881337),
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: const Color(0xFFBE123C), width: 1.5),
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'TRANSACTION FAILED',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFFBE123C),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '${ticket.quantity} Ticket(s) • ${ticket.tier.name.toUpperCase()}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            // Crisp Scannable QR Code
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: QrImageView(
                                                data: ticket.qrData.isNotEmpty ? ticket.qrData : 'JHOOMO_PASS_${ticket.bookingId}',
                                                version: QrVersions.auto,
                                                size: 104,
                                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                            const SizedBox(width: 16),

                                            // BMS Ticket Details (AUDI / Pass Tier + Count + Booking ID)
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${ticket.quantity} Ticket(s)',
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF64748B),
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    ticket.tier.name.toUpperCase(),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF0F172A),
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'ENTRY GATE 01 • FAST-TRACK',
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF475569),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'BOOKING ID: ${ticket.bookingId.toUpperCase()}',
                                                      style: GoogleFonts.robotoMono(
                                                        color: const Color(0xFF0F172A),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                            ),

                            // 5. Expandable Support / Actions Strip
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Connecting to JHOOMO 24x7 Event Help Desk... 🎧'),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.headset_mic_outlined, size: 18, color: Color(0xFF475569)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Contact support',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF334155),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // 6. BMS Cancellation Policy Strip
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              color: const Color(0xFFF8FAFC),
                              child: Text(
                                'Cancellation unavailable : cut-off time of 20 minutes before showtime has passed',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),

                            // 7. Expanded Breakdown (Net Ticket Price, GST, Convenience Fee)
                            if (isExpanded)
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                color: const Color(0xFFF8FAFC),
                                child: Column(
                                  children: [
                                    _buildPriceRow('Net Ticket(s) Price', '₹ ${basePrice.toStringAsFixed(2)}'),
                                    const SizedBox(height: 6),
                                    _buildPriceRow('GST (18%)', '₹ ${gst.toStringAsFixed(2)}'),
                                    const SizedBox(height: 6),
                                    _buildPriceRow('Convenience fee', '₹ ${convenienceFee.toStringAsFixed(2)}'),
                                    if (discount > 0) ...[
                                      const SizedBox(height: 6),
                                      _buildPriceRow('Discount', '- ₹ ${discount.toStringAsFixed(2)}', isDiscount: true),
                                    ],
                                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                                  ],
                                ),
                              ),

                            // 8. Total Amount Footer Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF1E293B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${ticket.totalAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF0F172A),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── BMS RATE BUTTON ──
                      if (_reviewedTicketIds.contains(ticket.bookingId))
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Review & Rating Submitted! ⭐ (Thank You)',
                                  style: GoogleFonts.inter(color: const Color(0xFF047857), fontSize: 13, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => _showPostEventReviewDialog(ticket),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star_border_rounded, size: 20, color: Color(0xFF1E293B)),
                                const SizedBox(width: 8),
                                Text(
                                  'Rate Event & Host',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // Share & Save Offline Bar
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.share_outlined, size: 15, color: MiloColors.primaryLight),
                              label: Text('Share Pass', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: MiloColors.primaryLight),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: MiloColors.bgSurface,
                                    content: Text(
                                      '🎟️ Milo Verified Pass copied: "${ticket.event.title} (${ticket.tier.name}) • Booked on JHOOMO: ${MiloConfig.passLink(ticket.bookingId)}"',
                                      style: GoogleFonts.inter(color: MiloColors.primaryLight),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.wallet, size: 15, color: MiloColors.bg),
                              label: Text('Save Offline', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w700, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MiloColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
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
                );
              },
            ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: isDiscount ? const Color(0xFF10B981) : const Color(0xFF1E293B),
            fontSize: 12,
            fontWeight: isDiscount ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
