import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/payment_approval_service.dart';
import 'my_tickets_screen.dart';

/// BookMyShow Style "Your Bookings & Purchases" Screen
class YourBookingsScreen extends StatefulWidget {
  const YourBookingsScreen({super.key});

  @override
  State<YourBookingsScreen> createState() => _YourBookingsScreenState();
}

class _YourBookingsScreenState extends State<YourBookingsScreen> {
  late List<BookedTicket> _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = List.from(PaymentApprovalService.instance.userTickets);
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
      backgroundColor: const Color(0xFFF1F5F9), // BMS soft gray-blue background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Bookings & Purchases',
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: _tickets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 64, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings yet',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your movie & event passes will appear here.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _tickets.length + 1,
              itemBuilder: (context, index) {
                // Bottom end footer
                if (index == _tickets.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'You have no more bookings',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                final ticket = _tickets[index];
                final isFailed = ticket.status == 'REJECTED';
                final isPending = ticket.status == 'PENDING_APPROVAL';

                // Display order date (e.g. "Ordered on: 08 Jun, 2026 at 04:05:18 PM")
                final orderedDate = ticket.bookingTime.isNotEmpty
                    ? ticket.bookingTime
                    : '22 Aug, 2026 at 12:07:51 PM';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BMS "Ordered on: Date" timestamp label
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          text: 'Ordered on: ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: orderedDate,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // BMS Purchase Card Item
                    GestureDetector(
                      onTap: () {
                        // Open the full M-Ticket QR Card screen for this ticket
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyTicketsScreen(initialBooking: ticket),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Card Top: Thumbnail + Title + Venue + M-Ticket / Pickup Label
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Poster
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      ticket.event.imageUrl,
                                      width: 68,
                                      height: 94,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 68,
                                        height: 94,
                                        color: const Color(0xFFCBD5E1),
                                        child: const Icon(Icons.movie_rounded, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Event Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ticket.event.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFF0F172A),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isFailed ? 'Pickup' : 'M-Ticket',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF64748B),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          ticket.event.category,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ticket.event.date,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF0F172A),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${ticket.event.venue}, ${ticket.event.city}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${ticket.quantity} ticket(S): ${ticket.bookingId.substring(0, ticket.bookingId.length > 5 ? 5 : ticket.bookingId.length).toUpperCase()}',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF0F172A),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              ticket.tier.name.toUpperCase(),
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF0F172A),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(height: 1, color: Color(0xFFF1F5F9)),

                            // Card Bottom: Status Pill (FAILED / FINISHED / ACTIVE) + Message
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  if (isFailed) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB91C1C),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'FAILED',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'We did not receive your payment.',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ] else if (isPending) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PENDING',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Payment approval in progress by Host.',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF475569),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'CONFIRMED',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Tap to view your M-Ticket pass & QR',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
