import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/milo_api.dart';
import '../../services/milo_session_service.dart';
import 'promoter_dashboard_screen.dart';

class BecomeInfluencerPromoterScreen extends StatefulWidget {
  const BecomeInfluencerPromoterScreen({super.key});

  @override
  State<BecomeInfluencerPromoterScreen> createState() =>
      _BecomeInfluencerPromoterScreenState();
}

class _BecomeInfluencerPromoterScreenState
    extends State<BecomeInfluencerPromoterScreen> {
  final _nameController = TextEditingController(
    text: MiloSessionService.currentUserName,
  );
  final _handleController = TextEditingController();
  final _phoneController = TextEditingController(
    text: MiloSessionService.currentUserPhone,
  );
  final _panController = TextEditingController();

  String _selectedCategory = 'LIFESTYLE & NIGHTLIFE';
  String _selectedReach = '10K - 50K';
  bool _agreedToTerms = false;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'LIFESTYLE & NIGHTLIFE',
    'COLLEGE & CAMPUS REP',
    'MUSIC & DJ PROMOTER',
    'FOOD & CAFE BLOGGER',
    'DANCE & GARBA ARTIST',
  ];

  final List<String> _reachOptions = [
    '< 10K',
    '10K - 50K',
    '50K - 200K',
    '200K+',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _phoneController.dispose();
    _panController.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    final handle = _handleController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pan = _panController.text.trim().toUpperCase();

    if (handle.isEmpty || name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name, phone and social handle')),
      );
      return;
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid PAN number (ABCDE1234F)')),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the promoter guidelines')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    var code = handle
        .replaceAll('@', '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length < 3) {
      code = 'PROMO${code.isEmpty ? DateTime.now().millisecondsSinceEpoch : code}';
    }
    if (code.length > 12) code = code.substring(0, 12);

    try {
      await MiloApi.instance.becomePromoter(
        displayName: name,
        pan: pan,
        code: code,
        termsAccepted: true,
      );

      await MiloSessionService.saveLoginSession(
        role: MiloRole.promoter,
        name: name,
        phone: phone,
        uid: MiloSessionService.currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          content: Text(
            'Promoter account activated! Your code is $code',
            style: GoogleFonts.inter(
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PromoterDashboardScreen(
            promoterHandle: handle.startsWith('@') ? handle : '@$handle',
            promoterName: name,
          ),
        ),
      );
    } on MiloApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not register promoter. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Join as Influencer / Promoter',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF881337)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'EARN PER TICKET',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Promote Events & Earn Instant UPI Payouts',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Get custom tracking links, exclusive VIP promo discount codes, live click dashboards, and up to 15% commission per pass booked.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Title
            Text(
              'REGISTRATION DETAILS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE11D48),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 14),

            // Full Name
            _buildInputField(
              label: 'Full Name',
              hint: 'e.g. Sahil Khan',
              icon: Icons.person_rounded,
              controller: _nameController,
            ),
            const SizedBox(height: 14),

            // Social Handle
            _buildInputField(
              label: 'Instagram / YouTube / Social Handle',
              hint: 'e.g. @sahil_vibes',
              icon: Icons.alternate_email_rounded,
              controller: _handleController,
            ),
            const SizedBox(height: 14),

            // Phone Number
            _buildInputField(
              label: 'WhatsApp Phone Number',
              hint: 'e.g. 9876543210',
              icon: Icons.phone_rounded,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // PAN for payout compliance
            _buildInputField(
              label: 'PAN Number (required for payouts)',
              hint: 'e.g. ABCDE1234F',
              icon: Icons.badge_outlined,
              controller: _panController,
            ),
            const SizedBox(height: 18),

            // Creator Category
            Text(
              'CREATOR / PROMOTER NICHE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                underline: const SizedBox(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
            const SizedBox(height: 18),

            // Estimated Reach
            Text(
              'ESTIMATED AUDIENCE REACH',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _reachOptions.map((reach) {
                final isSelected = _selectedReach == reach;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedReach = reach),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE11D48)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE11D48)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        reach,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Agreement checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreedToTerms,
                  activeColor: const Color(0xFFE11D48),
                  onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'I agree to JHOOMO promoter guidelines and fair marketing policies. Commissions are credited within 24h of ticket verification.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSubmitting || !_agreedToTerms ? null : _submitRegistration,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Complete Promoter Registration',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF94A3B8), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
