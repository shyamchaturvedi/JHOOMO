import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../config.dart';
import '../../services/milo_db_service.dart';
import '../../services/milo_promoter_tracking_service.dart';
import '../../services/milo_session_service.dart';
import '../../services/mock_data.dart';
import '../../theme/milo_theme.dart';

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
 String _activeTab = 'MY_LINKS'; // 'MY_LINKS' | 'SALES_LOG' | 'JOIN_CAMPAIGN'
 List<EventModel> _events = MockData.events;

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
 backgroundColor: MiloColors.bgSurface,
 content: Text('No live events available right now. Please try again later.',
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700)),
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
 top: 20,
 left: 20,
 right: 20,
 bottom: MediaQuery.of(context).viewInsets.bottom + 24,
 ),
 decoration: const BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Center(
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: MiloColors.border,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 ),
 const SizedBox(height: 16),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Generate Unique Promo Link ',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 IconButton(
 icon: const Icon(Icons.close, color: MiloColors.textMuted),
 onPressed: () => Navigator.pop(context),
 ),
 ],
 ),
 Text('Share this link on your Instagram Bio, Story, WhatsApp Status or Groups.',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12)),
 const SizedBox(height: 18),

 Text('Select Lucknow Event to Promote:',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: selectedEventId,
 dropdownColor: MiloColors.bgCard,
 isExpanded: true,
 items: _events.map((e) {
 return DropdownMenuItem<String>(
 value: e.id,
 child: Text(
 '${e.title} (${e.venue})',
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textPrimary, fontWeight: FontWeight.w600),
 maxLines: 1,
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

 Text('Your Unique Referral Tag (Code):',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: TextField(
 controller: codeCtrl,
 textCapitalization: TextCapitalization.characters,
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w900, fontSize: 15),
 decoration: const InputDecoration(
 border: InputBorder.none,
 prefixIcon: Icon(Icons.tag_rounded, color: MiloColors.primaryLight, size: 20),
 hintText: 'e.g. VIKAS10',
 ),
 ),
 ),
 const SizedBox(height: 14),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.verified, color: MiloColors.emerald, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Flat 10% Cash Commission credited directly on every ticket booked via your link! No arbitrary coins/points.',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 height: 50,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
 backgroundColor: MiloColors.bgSurface,
 content: Text(' Promo Link generated: ${MiloConfig.eventLink(ev.id, ref: code)}',
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700)),
 ),
 );
 },
 child: Text('Generate & Activate Link ',
 style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900, fontSize: 14)),
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
 .toList(); final totalTicketsSold = myLinks.fold<int>(0, (sum, r) => sum + r.ticketsSold);
 final totalRevenueDriven = myLinks.fold<double>(0.0, (sum, r) => sum + r.grossRevenue);
 final totalCommission = myLinks.fold<double>(0.0, (sum, r) => sum + r.commissionEarned);
 final totalClicks = myLinks.fold<int>(0, (sum, r) => sum + r.totalClicks);
 final pendingCommission = myLinks
 .where((r) => r.payoutStatus != 'SETTLED')
 .fold<double>(0.0, (sum, r) => sum + r.commissionEarned);
 final settledCommission = totalCommission - pendingCommission;

 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: MiloColors.bgSurface,
 elevation: 0,
 title: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Flexible(
 child: Text('Promoter Portal',
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 ),
 const SizedBox(width: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text('LIVE',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 9, fontWeight: FontWeight.w900)),
 ),
 ],
 ),
 Text('$_promoterName • $_promoterHandle',
 overflow: TextOverflow.ellipsis,
 maxLines: 1,
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 ],
 ),
 actions: [
 IconButton(
 icon: const Icon(Icons.share_outlined, color: MiloColors.primaryLight),
 onPressed: () {
 Clipboard.setData(ClipboardData(
 text: 'Promote top Lucknow events with Jhoomo & earn 10% cash commission per ticket: ${MiloConfig.promoterLink()}'));
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(' Promoter invite copied to clipboard!'),
 ),
 );
 },
 ),
 ],
 ),
 body: SingleChildScrollView(
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Transparency Promise Card (No Points Rule) 
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 MiloColors.primary.withValues(alpha: 0.25),
 MiloColors.bgSurface,
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: MiloColors.primary,
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.handshake_rounded, color: MiloColors.bg, size: 18),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('100% Transparent Referral Tracking ',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 Text('No fake coins or arbitrary points. Real tickets & cash commission.',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textSecondary)),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 'Both you and the Event Organizer see the EXACT same numbers in real-time: How many people clicked your link, which event was shared, exact passes bought, and rupees earned.',
 style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textPrimary, height: 1.35),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),

 // Realtime Stats Grid 
 Row(
 children: [
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Tickets Sold', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const Icon(Icons.confirmation_number_rounded, color: MiloColors.primaryLight, size: 16),
 ],
 ),
 const SizedBox(height: 6),
 Text('$totalTicketsSold Passes',
 style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 Text('via your referral links', style: GoogleFonts.inter(fontSize: 10, color: MiloColors.emerald)),
 ],
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Cash Commission', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const Icon(Icons.currency_rupee_rounded, color: MiloColors.emerald, size: 16),
 ],
 ),
 const SizedBox(height: 6),
 Text('₹${totalCommission.toStringAsFixed(0)}',
 style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
 Text('₹${pendingCommission.toStringAsFixed(0)} pending • ₹${settledCommission.toStringAsFixed(0)} settled',
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 ],
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Gross Revenue Driven', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const Icon(Icons.trending_up_rounded, color: MiloColors.amber, size: 16),
 ],
 ),
 const SizedBox(height: 6),
 Text('₹${totalRevenueDriven.toStringAsFixed(0)}',
 style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 Text('For Event Hosts', style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 ],
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Link Clicks / Reach', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const Icon(Icons.ads_click_rounded, color: MiloColors.primaryLight, size: 16),
 ],
 ),
 const SizedBox(height: 6),
 Text('$totalClicks Clicks',
 style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 Text(
 '${totalClicks > 0 ? ((totalTicketsSold / totalClicks) * 100).toStringAsFixed(1) : 0}% Conv. Rate',
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.primaryLight),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),

 // Section Tabs 
 Row(
 children: [
 _buildTabPill('MY_LINKS', 'Active Links (${myLinks.length})', Icons.link_rounded),
 const SizedBox(width: 8),
 _buildTabPill('SALES_LOG', 'Realtime Sales (${mySales.length})', Icons.receipt_long_rounded),
 ],
 ),
 const SizedBox(height: 16),

 // Tab Content
 if (_activeTab == 'MY_LINKS') ...[
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Your Forwarded Events & Links',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 ElevatedButton.icon(
 icon: const Icon(Icons.add, size: 16, color: MiloColors.bg),
 label: Text('New Link', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.bg)),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 ),
 onPressed: _showCreateLinkDialog,
 ),
 ],
 ),
 const SizedBox(height: 12),
 ...myLinks.map((item) => _buildPromoterLinkCard(item)),
 ] else ...[
 Text('Live Ticket Audit Log (Organizer Synced)',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 6),
 Text('Every single pass bought with your code appears here with timestamp.',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 const SizedBox(height: 12),
 ...mySales.map((log) => _buildAuditLogCard(log)),
 ],
 const SizedBox(height: 30),
 ],
 ),
 ),
 );
 }

 Widget _buildTabPill(String tabKey, String label, IconData icon) {
 final isSelected = _activeTab == tabKey;
 return GestureDetector(
 onTap: () => setState(() => _activeTab = tabKey),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary : MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: isSelected ? MiloColors.primaryLight : MiloColors.border),
 ),
 child: Row(
 children: [
 Icon(icon, size: 15, color: isSelected ? MiloColors.bg : MiloColors.textMuted),
 const SizedBox(width: 6),
 Text(
 label,
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
 color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
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
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: MiloColors.border),
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
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.3)),
 ),
 child: Text(
 '${item.commissionRatePercent.toStringAsFixed(0)}% Commission',
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.emerald),
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
 color: MiloColors.primary.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.tag, size: 12, color: MiloColors.primaryLight),
 Text(item.referralCode,
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: MiloColors.primaryLight)),
 ],
 ),
 ),
 const SizedBox(width: 8),
 Text('Forwarded ${item.lastForwardedTime}',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 ],
 ),
 const SizedBox(height: 12),

 // Transparent Counters Row
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceAround,
 children: [
 _buildMetricCol('Clicks', '${item.totalClicks}', Icons.ads_click_rounded, MiloColors.textSecondary),
 _buildMetricCol('Sold Passes', '${item.ticketsSold}', Icons.confirmation_number_rounded, MiloColors.primaryLight),
 _buildMetricCol('Revenue', '₹${item.grossRevenue.toStringAsFixed(0)}', Icons.payments_rounded, MiloColors.amber),
 _buildMetricCol('Earned', '₹${item.commissionEarned.toStringAsFixed(0)}', Icons.currency_rupee_rounded, MiloColors.emerald),
 ],
 ),
 ),
 const SizedBox(height: 12),

 // Link & Share Buttons
 Row(
 children: [
 Expanded(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: MiloColors.bg,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: MiloColors.border),
 ),
 child: Text(
 item.shareLink,
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textSecondary),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ),
 const SizedBox(width: 8),
 IconButton(
 style: IconButton.styleFrom(
 backgroundColor: MiloColors.primary.withValues(alpha: 0.15),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 icon: const Icon(Icons.copy, size: 18, color: MiloColors.primaryLight),
 onPressed: () {
 Clipboard.setData(ClipboardData(text: item.shareLink));
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Copied link: ${item.shareLink}',
 style: GoogleFonts.inter(color: MiloColors.primaryLight)),
 ),
 );
 },
 ),
 IconButton(
 style: IconButton.styleFrom(
 backgroundColor: MiloColors.emerald.withValues(alpha: 0.15),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 icon: const Icon(Icons.share, size: 18, color: MiloColors.emerald),
 onPressed: () {
 final msg =
 ' Book passes for ${item.eventTitle} on Jhoomo with my exclusive referral link & get instant entry QR on WhatsApp:\n${item.shareLink}\n(Use Code: ${item.referralCode})';
 Clipboard.setData(ClipboardData(text: msg));
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('WhatsApp share text copied! Paste anywhere.',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
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
 Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
 Text(label, style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 ],
 );
 }

 Widget _buildAuditLogCard(PromoterAuditLog log) {
 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.15),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 18),
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
 child: Text(log.buyerName,
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 ),
 const SizedBox(width: 6),
 Text(
 '+₹${log.commissionEarned.toStringAsFixed(1)}',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: MiloColors.emerald),
 ),
 ],
 ),
 const SizedBox(height: 3),
 Text(
 '${log.eventTitle} • ${log.tierName} (${log.quantity} Passes)',
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textSecondary),
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Flexible(
 child: Text('Code: ${log.referralCode} • Paid ₹${log.totalAmount.toStringAsFixed(0)}',
 overflow: TextOverflow.ellipsis,
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted, fontWeight: FontWeight.w600)),
 ),
 const SizedBox(width: 4),
 Text(log.timestamp, style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
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
