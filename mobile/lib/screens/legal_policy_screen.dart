import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class LegalPolicyScreen extends StatelessWidget {
  final String title;
  final String policyType; // 'terms', 'privacy', 'organizer_terms', 'refund_policy'

  const LegalPolicyScreen({
    super.key,
    required this.title,
    required this.policyType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MiloColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gavel_rounded, color: MiloColors.primaryLight, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Milo Platform Policy',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
                          ),
                          Text(
                            'Effective Date: September 2026',
                            style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: MiloColors.border, height: 28),
                _buildContentForType(policyType),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildContentForType(String type) {
    switch (type) {
      case 'organizer_terms':
        return _buildOrganizerTerms();
      case 'privacy':
        return _buildPrivacyPolicy();
      case 'refund_policy':
        return _buildRefundPolicy();
      case 'terms':
      default:
        return _buildUserTerms();
    }
  }

  Widget _buildUserTerms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Zero-Liability Platform Marketplace Disclaimer'),
        _sectionBody(
          'Milo App is strictly a technology platform and digital discovery marketplace. Milo does NOT organize, host, manage, sponsor, or control any event, party, Dandiya night, concert, or gathering listed on the app. All event planning, legal clearances, municipal permissions, safety measures, venue facilities, and artist performances are 100% the sole responsibility of the individual Event Organizer. Milo App shall NOT be held legally or financially liable for any mishap, dispute, delay, injury, or venue issues.',
        ),
        _sectionTitle('2. Organizer-Controlled Pricing & Discounts'),
        _sectionBody(
          'Ticket pricing, discount offers, squad rates, and promo codes are independently defined and funded by the Event Organizer. Milo does not provide default coupons or guarantee organizer-side discounts.',
        ),
        _sectionTitle('3. Entry Verification & Venue Rules'),
        _sectionBody(
          'Attendees must present a valid Milo digital M-Ticket (QR code) at the venue gate. The Organizer reserves full rights of admission in accordance with local regulations, age verification, and venue security standards.',
        ),
        _sectionTitle('4. Payments & Billing Transparency'),
        _sectionBody(
          'All pass payments are processed through secure encrypted gateways. Convenience fees and taxes are clearly disclosed prior to final payment.',
        ),
      ],
    );
  }

  Widget _buildOrganizerTerms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. 100% Organizer Legal & Regulatory Responsibility'),
        _sectionBody(
          'The Event Organizer represents and warrants that they have obtained all required government, municipal, police permissions, fire safety NOCs, venue approvals, sound permits, and copyright/music royalties. Milo App is solely a listing and ticketing facilitator and assumes ZERO legal or operational liability for the event.',
        ),
        _sectionTitle('2. Organizer Payment Payout Policy (3-5 Working Days)'),
        _sectionBody(
          'Ticket sale proceeds are held securely in platform escrow during the event cycle. Following the successful completion of the event and check-in validation, Milo will initiate and release the net payout to the Organizer\'s verified bank account within 3 to 5 business/working days, minus applicable platform service fees.',
        ),
        _sectionTitle('3. Mandatory 100% Refund on Event Cancellation'),
        _sectionBody(
          'If the event is cancelled, postponed, rescheduled, or called off for ANY reason (regulatory, weather, host-related), the Organizer is strictly legally bound to issue a full 100% refund to all ticket holders. Milo reserves the immediate right to withhold escrow funds to process automated full refunds to buyers.',
        ),
        _sectionTitle('4. Pricing & Custom Rules Autonomy'),
        _sectionBody(
          'Organizers have full control over creating promotional coupons, defining custom venue guidelines, and choosing whether individual passes are refundable or non-refundable.',
        ),
      ],
    );
  }

  Widget _buildRefundPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Official Event Cancellation: 100% Guaranteed Refund'),
        _sectionBody(
          'If an event is officially CANCELLED, postponed, or called off by the Organizer, all affected ticket buyers are entitled to a full 100% refund. The refund will be automatically processed by Milo directly back to the original payment method within 5 to 7 business days.',
        ),
        _sectionTitle('2. User Voluntary Cancellations: Refundable vs Non-Refundable Passes'),
        _sectionBody(
          '• 100% Refundable Passes: If the Organizer specifically lists the ticket tier as "100% Refundable", users can request a refund prior to the event cutoff window specified on the ticket.\n• Non-Refundable Passes: If the ticket is marked as "Non-Refundable" by the Organizer, voluntary cancellation requests cannot be refunded under any circumstances.',
        ),
        _sectionTitle('3. Organizer Settlement Cycle & Disputes'),
        _sectionBody(
          'In case of attendee disputes or verified false listings, Milo escrow holds the funds during the 3 to 5 working day settlement window to ensure user rights and fair dispute resolution.',
        ),
      ],
    );
  }

  Widget _buildPrivacyPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Privacy-First Architecture'),
        _sectionBody(
          'Milo is built to keep user personal data safe. Your exact live GPS coordinates, phone numbers, and identity are never exposed to other attendees or organizers without your explicit consent.',
        ),
        _sectionTitle('2. Incognito & Ghost Mode'),
        _sectionBody(
          'Users can turn on "Incognito Event Attendance" to hide their ticket booking from other attendees, or enable "Ghost Mode" to pause discovery visibility completely.',
        ),
        _sectionTitle('3. Zero Third-Party Ad Selling'),
        _sectionBody(
          'We do not sell user data, chats, or personal profiles to external advertising brokers. All chat conversations and transaction logs are 256-bit encrypted.',
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.primaryLight),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.55),
    );
  }
}
