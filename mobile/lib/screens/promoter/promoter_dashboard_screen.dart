import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../config.dart';
import '../../services/milo_db_service.dart';
import '../../services/milo_promoter_tracking_service.dart';
import '../../services/milo_session_service.dart';

import '../../theme/milo_theme.dart';
import '../notifications_screen.dart';

class PromoterDashboardScreen extends StatefulWidget {
  final String promoterHandle;
  final String promoterName;

  const PromoterDashboardScreen({
    super.key,
    this.promoterHandle = '@lucknow_vibes',
    this.promoterName = 'Vikas Mishra (Lucknow Food & Beats)',
  });

  @override
  State<PromoterDashboardScreen> createState() => _PromoterDashboardScreenState();
}

class _PromoterDashboardScreenState extends State<PromoterDashboardScreen> {
  final _service = MiloPromoterTrackingService.instance;
  int _activeNavIndex = 0; // 0: Overview/Stats, 1: My Links, 2: Realtime Sales, 3: Profile/Payout
  String _activeTab = 'MY_LINKS'; // 'MY_LINKS' | 'SALES_LOG'
  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _loadEvents();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEvents() async {
    try {
      final events = await MiloDbService.instance.getEvents();
      if (!mounted) return;
      if (events.isNotEmpty) {
        setState(() => _events = List<EventModel>.from(events));
      }
    } catch (e) {
      debugPrint('Promoter dashboard events note: $e');
    }
  }

  String get _promoterScopeId {
    final uid = MiloSessionService.currentUid.trim();
    if (uid.isNotEmpty) return uid;
    return MiloSessionService.currentUserPhone.trim();
  }

  String get _promoterName {
    final name = MiloSessionService.currentUserName.trim();
    return name.isNotEmpty ? name : widget.promoterName;
  }

  String get _promoterHandle {
    final name = MiloSessionService.currentUserName.trim();
    if (name.isNotEmpty) {
      return '@${name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
    }
    return widget.promoterHandle;
  }

  static const Set<String> _samplePromoterIds = {'prom-1', 'prom-2', 'prom-3'};

  List<PromoterReferralItem> get _myLinks {
    final scopeId = _promoterScopeId;
    if (scopeId.isEmpty || !_service.firestoreOnline) {
      return _service.allReferrals;
    }
    final scoped = _service.getReferralsForPromoter(scopeId);
    if (scoped.isNotEmpty) return scoped;
    final referrals = _service.allReferrals;
    final sampleOnly =
        referrals.isNotEmpty && referrals.every((r) => _samplePromoterIds.contains(r.promoterId));
    return sampleOnly ? referrals : scoped;
  }

  void _showCreateLinkDialog() {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          content: Text('No live events available right now. Please try again later.',
              style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontWeight: FontWeight.w700)),
        ),
      );
      return;
    }

    final codeCtrl = TextEditingController(text: 'MY_LKO_PASS');
    String selectedEventId = _events.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final ev = _events.firstWhere((e) => e.id == selectedEventId, orElse: () => _events.first);
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Generate Promo Link',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: JhoomoTokens.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '10% CASH',
                          style: GoogleFonts.outfit(
                            color: JhoomoTokens.greenVerified,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select an event to create your instant tracked referral link.',
                    style: GoogleFonts.inter(fontSize: 13, color: JhoomoTokens.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  Text('Select Live Event:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: JhoomoTokens.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: JhoomoTokens.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: JhoomoTokens.outline),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedEventId,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        items: _events.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.id,
                            child: Text(
                              '${e.title} (${e.city})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: JhoomoTokens.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedEventId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Your Unique Promo Tag / Code:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: JhoomoTokens.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: JhoomoTokens.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: JhoomoTokens.outline),
                    ),
                    child: TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.inter(color: JhoomoTokens.primary, fontWeight: FontWeight.w800, fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.tag_rounded, color: JhoomoTokens.primary, size: 20),
                        hintText: 'e.g. VIKAS10',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: JhoomoTokens.greenVerified, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Flat 10% Cash Commission credited on every ticket booked via this link. No points or coin tricks.',
                            style: GoogleFonts.inter(color: const Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JhoomoTokens.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final code = codeCtrl.text.trim().toUpperCase();
                        if (code.isEmpty) return;

                        _service.createReferralLink(
                          eventId: ev.id,
                          eventTitle: ev.title,
                          promoterName: _promoterName,
                          promoterHandle: _promoterHandle,
                          customCode: code,
                          promoterId: _promoterScopeId,
                        );

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.white,
                            content: Text(
                              'Promo link generated: ${MiloConfig.eventLink(ev.id, ref: code)}',
                              style: GoogleFonts.inter(color: JhoomoTokens.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Generate & Activate Link',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myLinks = _myLinks;
    final myCodes = myLinks.map((r) => r.referralCode.toUpperCase()).toSet();
    final mySales = _service.auditLogs
        .where((l) => myCodes.contains(l.referralCode.toUpperCase()))
        .toList();
    final totalTicketsSold = myLinks.fold<int>(0, (sum, r) => sum + r.ticketsSold);
    final totalRevenueDriven = myLinks.fold<double>(0.0, (sum, r) => sum + r.grossRevenue);
    final totalCommission = myLinks.fold<double>(0.0, (sum, r) => sum + r.commissionEarned);
    final totalClicks = myLinks.fold<int>(0, (sum, r) => sum + r.totalClicks);
    final pendingCommission = myLinks
        .where((r) => r.payoutStatus != 'SETTLED')
        .fold<double>(0.0, (sum, r) => sum + r.commissionEarned);

    return Scaffold(
      backgroundColor: JhoomoTokens.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: JhoomoGradients.brandIcon,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: JhoomoTokens.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Promoter & Influencer Portal',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.inter(
                            color: JhoomoTokens.greenVerified,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$_promoterName • $_promoterHandle',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(fontSize: 11, color: JhoomoTokens.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: JhoomoTokens.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(color: JhoomoTokens.outline),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF334155), size: 20),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: 'Promote top events on JHOOMO & earn 10% direct cash commission: ${MiloConfig.promoterLink()}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.white,
                  content: Text(' Promoter invite copied to clipboard!', style: TextStyle(color: Colors.black)),
                ),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFE4E6)),
              ),
              child: const Icon(Icons.share_rounded, color: JhoomoTokens.primary, size: 18),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transparency Banner Card (Customer Theme Compliant)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F2), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFD1D8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: JhoomoGradients.brandIcon,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% Transparent Payouts',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Direct Bank Transfer • No Points • Real Cash Earnings',
                              style: GoogleFonts.inter(fontSize: 11, color: JhoomoTokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Both you and event hosts see the exact same metrics: live ticket sales, clicks, and settled commission. Fully synced with event gate attendance.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Live Performance Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Tickets Sold',
                    value: '$totalTicketsSold Passes',
                    subtitle: 'via your links',
                    icon: Icons.confirmation_number_rounded,
                    accentColor: JhoomoTokens.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Cash Earned',
                    value: '₹${totalCommission.toStringAsFixed(0)}',
                    subtitle: '₹${pendingCommission.toStringAsFixed(0)} pending',
                    icon: Icons.currency_rupee_rounded,
                    accentColor: JhoomoTokens.greenVerified,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Gross Revenue',
                    value: '₹${totalRevenueDriven.toStringAsFixed(0)}',
                    subtitle: 'For Event Hosts',
                    icon: Icons.trending_up_rounded,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Link Clicks',
                    value: '$totalClicks Clicks',
                    subtitle:
                        '${totalClicks > 0 ? ((totalTicketsSold / totalClicks) * 100).toStringAsFixed(1) : 0}% Conv. Rate',
                    icon: Icons.ads_click_rounded,
                    accentColor: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Segmented Layout Bar (Customer App Style Pills)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: JhoomoTokens.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: JhoomoTokens.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      tabKey: 'MY_LINKS',
                      label: 'Active Links (${myLinks.length})',
                      icon: Icons.link_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      tabKey: 'SALES_LOG',
                      label: 'Live Sales (${mySales.length})',
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            if (_activeTab == 'MY_LINKS') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Active Event Links',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'New Link',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JhoomoTokens.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: _showCreateLinkDialog,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (myLinks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: JhoomoTokens.outline),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.link_off_rounded, color: Color(0xFF94A3B8), size: 40),
                      const SizedBox(height: 10),
                      Text(
                        'No referral links created yet',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Click "+ New Link" to generate your first 10% commission tag.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ...myLinks.map((item) => _buildPromoterLinkCard(item)),
            ] else ...[
              Text(
                'Live Ticket Audit Log',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Every ticket purchased using your referral code is displayed below with exact timestamps.',
                style: GoogleFonts.inter(fontSize: 12, color: JhoomoTokens.textSecondary),
              ),
              const SizedBox(height: 14),
              if (mySales.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: JhoomoTokens.outline),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFF94A3B8), size: 40),
                      const SizedBox(height: 10),
                      Text(
                        'No sales recorded yet',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share your links on Instagram, WhatsApp and squads to start earning.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ...mySales.map((log) => _buildAuditLogCard(log)),
            ],
          ],
        ),
      ),

      // Customer App Style Bottom Navigation Bar for Influencer
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard', () {
                  setState(() => _activeNavIndex = 0);
                }),
                _buildBottomNavItem(1, Icons.link_outlined, Icons.link_rounded, 'My Links', () {
                  setState(() {
                    _activeNavIndex = 1;
                    _activeTab = 'MY_LINKS';
                  });
                }),
                // Center Create Link Floating Button
                GestureDetector(
                  onTap: _showCreateLinkDialog,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: JhoomoGradients.brandIcon,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: JhoomoTokens.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_link_rounded, color: Colors.white, size: 24),
                  ),
                ),
                _buildBottomNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Earnings', () {
                  setState(() {
                    _activeNavIndex = 2;
                    _activeTab = 'SALES_LOG';
                  });
                }),
                _buildBottomNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.white,
                      content: Text('Logged in as $_promoterName ($_promoterHandle)',
                          style: const TextStyle(color: Colors.black)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, IconData activeIcon, String label, VoidCallback onTap) {
    final isSelected = _activeNavIndex == index;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? JhoomoTokens.primary : const Color(0xFF64748B),
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? JhoomoTokens.primary : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JhoomoTokens.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String tabKey,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? JhoomoTokens.primary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoterLinkCard(PromoterReferralItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JhoomoTokens.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.eventTitle,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '${item.commissionRatePercent.toStringAsFixed(0)}% Commission',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: JhoomoTokens.greenVerified),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 12, color: JhoomoTokens.primary),
                    Text(
                      item.referralCode,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: JhoomoTokens.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Forwarded ${item.lastForwardedTime}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Transparent Counters Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JhoomoTokens.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: JhoomoTokens.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('Clicks', '${item.totalClicks}', Icons.ads_click_rounded, const Color(0xFF3B82F6)),
                _buildMetricCol('Passes', '${item.ticketsSold}', Icons.confirmation_number_rounded, JhoomoTokens.primary),
                _buildMetricCol('Gross', '₹${item.grossRevenue.toStringAsFixed(0)}', Icons.payments_rounded, const Color(0xFFF59E0B)),
                _buildMetricCol('Earned', '₹${item.commissionEarned.toStringAsFixed(0)}', Icons.currency_rupee_rounded, JhoomoTokens.greenVerified),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Link & Share Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: JhoomoTokens.outline),
                  ),
                  child: Text(
                    item.shareLink,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18, color: JhoomoTokens.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.shareLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.white,
                      content: Text('Copied link: ${item.shareLink}',
                          style: GoogleFonts.inter(color: JhoomoTokens.primary, fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFECFDF5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_rounded, size: 18, color: JhoomoTokens.greenVerified),
                onPressed: () {
                  final msg =
                      'Book passes for ${item.eventTitle} on JHOOMO with my referral link & get verified entry:\n${item.shareLink}\n(Use Promo Code: ${item.referralCode})';
                  Clipboard.setData(ClipboardData(text: msg));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.white,
                      content: Text('WhatsApp share text copied! Paste anywhere.',
                          style: GoogleFonts.inter(color: JhoomoTokens.greenVerified, fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildAuditLogCard(PromoterAuditLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JhoomoTokens.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: JhoomoTokens.greenVerified, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        log.buyerName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+₹${log.commissionEarned.toStringAsFixed(1)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: JhoomoTokens.greenVerified,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${log.eventTitle} • ${log.tierName} (${log.quantity} Passes)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Code: ${log.referralCode} • Paid ₹${log.totalAmount.toStringAsFixed(0)}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(log.timestamp, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
