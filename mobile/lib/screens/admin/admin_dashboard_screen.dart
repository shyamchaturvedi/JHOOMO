import '../../services/milo_moderation_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/milo_admin_service.dart';
import '../../services/payment_approval_service.dart';
import '../../theme/milo_theme.dart';
import '../../widgets/app_logo.dart';

class AdminDashboardScreen extends StatefulWidget {
 const AdminDashboardScreen({super.key});

 @override
 State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
 static const List<Color> _barColors = [
 MiloColors.amber,
 MiloColors.cyan,
 MiloColors.primaryLight,
 MiloColors.rose,
 MiloColors.emerald,
 ];

 late TabController _tabController;
 final MiloAdminService _admin = MiloAdminService.instance;

 @override
 void initState() {
 super.initState();
 _tabController = TabController(length: 4, vsync: this);
 _admin.addListener(_onDataChanged);
 PaymentApprovalService.instance.addListener(_onDataChanged);
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (!mounted) return;
 PaymentApprovalService.instance.init();
 _admin.refresh();
 });
 }

 void _onDataChanged() {
 if (mounted) setState(() {});
 }

 @override
 void dispose() {
 _admin.removeListener(_onDataChanged);
 PaymentApprovalService.instance.removeListener(_onDataChanged);
 _tabController.dispose();
 super.dispose();
 }

 Future<void> _refresh() => _admin.refresh();

 void _toast(AdminAction result) {
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 result.message,
 style: GoogleFonts.inter(
 color: result.ok ? MiloColors.emerald : MiloColors.rose,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 ));
 }

 Future<void> _approveEvent(EventModel ev) async {
 final result = await _admin.approveEvent(ev);
 if (!mounted) return;
 _toast(result);
 }

 Future<void> _rejectEvent(EventModel ev) async {
 final reason = await _askRejectReason();
 if (reason == null || !mounted) return;
 final result = await _admin.rejectEvent(ev, reason);
 if (!mounted) return;
 _toast(result);
 }

 Future<void> _toggleVerify(EventModel ev, bool value) async {
 final result = await _admin.setEventVerified(ev, value);
 if (!mounted) return;
 _toast(result);
 }

 Future<void> _dismissReport(Map<String, dynamic> rep) async {
 final result = await _admin.dismissReport(rep['id']?.toString() ?? '');
 if (!mounted) return;
 _toast(result);
 }

 Future<void> _suspendReport(Map<String, dynamic> rep) async {
 final result = await _admin.suspendReport(rep);
 if (!mounted) return;
 _toast(result);
 }

 Future<void> _authorizePayout(Map<String, dynamic> st) async {
 final result = await _admin.authorizeSettlement(
 st['id']?.toString() ?? '',
 (st['net_payout'] as num?)?.toDouble() ?? 0,
 st['bank_account']?.toString() ?? 'bank account on file',
 );
 if (!mounted) return;
 _toast(result);
 }

 Future<String?> _askRejectReason() async {
 final controller = TextEditingController();
 final result = await showDialog<String>(
 context: context,
 builder: (ctx) => AlertDialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Text('Reject Listing', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
 content: TextField(
 controller: controller,
 maxLines: 3,
 style: GoogleFonts.inter(fontSize: 13),
 decoration: InputDecoration(
 hintText: 'Reason sent back to the host (optional)…',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: Text('Cancel', style: GoogleFonts.inter(color: MiloColors.textMuted)),
 ),
 ElevatedButton(
 style: ElevatedButton.styleFrom(backgroundColor: MiloColors.rose),
 onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
 child: Text('Reject Listing', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
 ),
 ],
 ),
 );
 controller.dispose();
 if (result == null) return null;
 if (result.isEmpty) {
 return 'Rejected during Super Admin review — listing does not meet Milo guidelines.';
 }
 return result;
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Row(
 children: [
 const MiloAppLogo(size: 32, showText: false),
 const SizedBox(width: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text('Super Admin Central', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 16)),
 const SizedBox(width: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(color: MiloColors.rose.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
 child: Text('ROOT ACCESS', style: GoogleFonts.inter(color: MiloColors.rose, fontSize: 9, fontWeight: FontWeight.w900)),
 ),
 ],
 ),
 Text('Platform Health, Settlements & Moderation', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 ],
 ),
 ],
 ),
 bottom: TabBar(
 controller: _tabController,
 indicatorColor: MiloColors.primaryLight,
 labelColor: MiloColors.primaryLight,
 unselectedLabelColor: MiloColors.textMuted,
 labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
 unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
 isScrollable: true,
 tabAlignment: TabAlignment.start,
 tabs: const [
 Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview '),
 Tab(icon: Icon(Icons.event_available_rounded, size: 18), text: 'Event Approvals '),
 Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Settlements & Escrow '),
 Tab(icon: Icon(Icons.gavel_rounded, size: 18), text: 'Trust & Moderation '),
 ],
 ),
 ),
 body: TabBarView(
 controller: _tabController,
 children: [
 _buildOverviewTab(),
 _buildEventApprovalsTab(),
 _buildSettlementsTab(),
 _buildModerationTab(),
 ],
 ),
 );
 }

 // Tab 1: Platform Overview & Metrics 
 Widget _buildOverviewTab() {
 final categories = _admin.categories;
 return RefreshIndicator(
 onRefresh: _refresh,
 color: MiloColors.primaryLight,
 backgroundColor: MiloColors.bgSurface,
 child: ListView(
 physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
 padding: const EdgeInsets.all(20),
 children: [
 _buildHealthBanner(),
 const SizedBox(height: 18),
 Row(
 children: [
 Expanded(child: _buildMetricCard(
 title: 'Total Active Users',
 value: MiloAdminService.group(_admin.totalUsers),
 change: 'Registered Milo accounts',
 icon: Icons.people_alt_rounded,
 color: MiloColors.cyan,
 )),
 const SizedBox(width: 12),
 Expanded(child: _buildMetricCard(
 title: 'Live Events',
 value: MiloAdminService.group(_admin.liveCount),
 change: 'Live on the Explore feed',
 icon: Icons.celebration_rounded,
 color: MiloColors.amber,
 )),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: _buildMetricCard(
 title: 'Gross Bookings (GMV)',
 value: MiloAdminService.compactInr(_admin.gmv),
 change: _admin.confirmedBookings > 0
 ? '${_admin.confirmedBookings} confirmed • 5% Milo fee'
 : 'Confirmed bookings • 5% Milo fee',
 icon: Icons.payments_rounded,
 color: MiloColors.emerald,
 )),
 const SizedBox(width: 12),
 Expanded(child: _buildMetricCard(
 title: 'Pending Escrow Holds',
 value: MiloAdminService.compactInr(_admin.escrowHolds),
 change: 'Awaiting payout authorization',
 icon: Icons.lock_clock_rounded,
 color: MiloColors.rose,
 )),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: _buildMetricCard(
 title: 'Pending Payment Approvals',
 value: '${_admin.pendingPaymentApprovals}',
 change: 'UTR requests awaiting organizers',
 icon: Icons.hourglass_top_rounded,
 color: MiloColors.gold,
 )),
 const SizedBox(width: 12),
 Expanded(child: _buildMetricCard(
 title: 'Pending Event Reviews',
 value: '${_admin.pendingReviewCount}',
 change: 'Awaiting Super Admin approval',
 icon: Icons.rule_rounded,
 color: MiloColors.primaryLight,
 )),
 ],
 ),
 const SizedBox(height: 24),
 Text('Active Social Archetype Distribution ', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 12),
 if (categories.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Text(
 'No live events yet — category share appears once events are published.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
 ),
 )
 else
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 children: [
 for (var i = 0; i < categories.length; i++) ...[
 if (i > 0) const SizedBox(height: 12),
 _buildCategoryProgressBar(
 categories[i].label,
 categories[i].share,
 categories[i].detail,
 _barColors[i % _barColors.length],
 ),
 ],
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildHealthBanner() {
 String title;
 String subtitle;
 Color color;
 if (_admin.health == 'connected') {
 color = MiloColors.emerald;
 title = 'Firestore sync: connected';
 subtitle = '${MiloAdminService.group(_admin.totalUsers)} users • ${MiloAdminService.group(_admin.liveCount)} live events • ${_admin.pendingReviewCount} awaiting review';
 } else if (_admin.health == 'degraded') {
 color = MiloColors.amber;
 title = 'Firestore sync: partial — some reads failed';
 subtitle = 'Unavailable figures fall back to the last saved numbers • pull to retry';
 } else if (_admin.health == 'cached') {
 color = MiloColors.amber;
 title = 'Firestore sync: offline — showing cached data';
 subtitle = 'Reads served from device cache • writes queue until reconnect';
 } else if (_admin.health == 'offline') {
 color = MiloColors.rose;
 title = 'Firestore sync: unreachable';
 subtitle = 'Could not reach Firestore • showing last saved figures • pull to retry';
 } else {
 color = MiloColors.amber;
 title = 'Firestore sync: connecting…';
 subtitle = 'Loading KPIs from Firestore';
 }
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: color.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 Container(
 width: 12,
 height: 12,
 decoration: BoxDecoration(
 color: color,
 shape: BoxShape.circle,
 boxShadow: [BoxShadow(color: color, blurRadius: 8)],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(title, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
 Text(subtitle, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 ],
 ),
 ),
 ],
 ),
 );
 }

 // Tab 2: Event Approvals 
 Widget _buildEventApprovalsTab() {
 if (!_admin.hasLoaded && _admin.isLoading) {
 return const Center(child: CircularProgressIndicator(color: MiloColors.primaryLight));
 }
 final pending = _admin.pendingEvents;
 final live = _admin.liveEvents;
 final children = <Widget>[
 _sectionHeader('Awaiting Approval (${pending.length})', Icons.pending_actions_rounded, MiloColors.amber),
 const SizedBox(height: 12),
 ];
 if (pending.isEmpty) {
 children.add(_emptyState('No event submissions are awaiting Super Admin review.', Icons.event_available_rounded));
 } else {
 children.addAll(pending.map(_buildPendingEventCard));
 }
 children.add(const SizedBox(height: 14));
 children.add(_sectionHeader('Published & Live (${live.length})', Icons.rocket_launch_rounded, MiloColors.emerald));
 children.add(const SizedBox(height: 12));
 if (live.isEmpty) {
 children.add(_emptyState('No live events on the Explore feed yet.', Icons.event_rounded));
 } else {
 children.addAll(live.take(30).map(_buildLiveEventCard));
 if (live.length > 30) {
 children.add(Text(
 'Showing 30 of ${live.length} live events — pull to refresh.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 ));
 }
 }
 return RefreshIndicator(
 onRefresh: _refresh,
 color: MiloColors.primaryLight,
 backgroundColor: MiloColors.bgSurface,
 child: ListView(
 physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
 padding: const EdgeInsets.all(20),
 children: children,
 ),
 );
 }

 Widget _buildPendingEventCard(EventModel ev) {
 return Container(
 margin: const EdgeInsets.only(bottom: 18),
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: MiloColors.glassBorder),
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
 color: MiloColors.amber.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: MiloColors.amber),
 ),
 child: Text(
 'Pending Approval',
 style: GoogleFonts.inter(color: MiloColors.amber, fontSize: 11, fontWeight: FontWeight.w800),
 ),
 ),
 Text(ev.category, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
 ],
 ),
 const SizedBox(height: 12),
 Text(ev.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 4),
 Text('Host: ${ev.organizerName} • City: ${ev.city}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
 const SizedBox(height: 4),
 Text('Show Date: ${ev.date} • ${ev.time} • Base Price: ${MiloAdminService.inr(ev.startingPrice)}',
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text('Capacity: ${ev.ticketsLeft} Seats', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
 const Divider(color: MiloColors.border, height: 24),
 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 icon: const Icon(Icons.close_rounded, size: 16, color: MiloColors.rose),
 label: Text('Reject Listing', style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w700, fontSize: 12)),
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: MiloColors.rose),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () => _rejectEvent(ev),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton.icon(
 icon: const Icon(Icons.check_circle_rounded, size: 16, color: MiloColors.bg),
 label: Text('Approve & Publish', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 12)),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.emerald,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () => _approveEvent(ev),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildLiveEventCard(EventModel ev) {
 final verified = ev.isVerifiedOrganizer;
 return Container(
 margin: const EdgeInsets.only(bottom: 18),
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: verified ? MiloColors.emerald.withValues(alpha: 0.5) : MiloColors.glassBorder),
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
 color: MiloColors.emerald.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: MiloColors.emerald),
 ),
 child: Text(
 'Published ',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w800),
 ),
 ),
 Text(ev.category, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
 ],
 ),
 const SizedBox(height: 12),
 Text(ev.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 4),
 Text('Host: ${ev.organizerName} • City: ${ev.city}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
 const SizedBox(height: 4),
 Text('Show Date: ${ev.date} • ${ev.time} • Base Price: ${MiloAdminService.inr(ev.startingPrice)}',
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 Text(
 verified ? 'Capacity: ${ev.ticketsLeft} Seats • Verify badge showing in Explore' : 'Capacity: ${ev.ticketsLeft} Seats • No verify badge',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
 ),
 const Divider(color: MiloColors.border, height: 24),
 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 icon: Icon(
 verified ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
 size: 16,
 color: verified ? MiloColors.emerald : MiloColors.amber,
 ),
 label: Text(
 verified ? 'Remove Verify Badge' : 'Grant Verify Badge',
 style: GoogleFonts.inter(
 color: verified ? MiloColors.emerald : MiloColors.amber,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 style: OutlinedButton.styleFrom(
 side: BorderSide(color: verified ? MiloColors.emerald : MiloColors.amber),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () => _toggleVerify(ev, !verified),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 // Tab 3: Settlements & Escrow Releases 
 Widget _buildSettlementsTab() {
 if (!_admin.hasLoaded && _admin.isLoading) {
 return const Center(child: CircularProgressIndicator(color: MiloColors.primaryLight));
 }
 final settlements = _admin.settlements;
 if (settlements.isEmpty) {
 return RefreshIndicator(
 onRefresh: _refresh,
 color: MiloColors.primaryLight,
 backgroundColor: MiloColors.bgSurface,
 child: ListView(
 physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
 padding: const EdgeInsets.all(20),
 children: [_emptyState('No payout requests right now.', Icons.account_balance_rounded)],
 ),
 );
 }
 return RefreshIndicator(
 onRefresh: _refresh,
 color: MiloColors.primaryLight,
 backgroundColor: MiloColors.bgSurface,
 child: ListView.builder(
 physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
 padding: const EdgeInsets.all(20),
 itemCount: settlements.length,
 itemBuilder: (context, index) => _buildSettlementCard(settlements[index]),
 ),
 );
 }

 Widget _buildSettlementCard(Map<String, dynamic> st) {
 final isReleased = st['status'] == 'authorized' || st['status'] == 'paid';
 final gross = (st['gross_amount'] as num?)?.toDouble() ?? 0;
 final fee = (st['platform_fee'] as num?)?.toDouble() ?? 0;
 final net = (st['net_payout'] as num?)?.toDouble() ?? 0;
 final feePct = gross > 0 ? (fee / gross * 100).round() : 0;
 final bank = st['bank_account']?.toString() ?? 'Bank account on file';
 final escrowNote = st['escrow_status']?.toString() ?? '3-5 Days Escrow Cleared ';

 return Container(
 margin: const EdgeInsets.only(bottom: 18),
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: isReleased ? MiloColors.emerald.withValues(alpha: 0.5) : MiloColors.glassBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Text(st['organizer']?.toString() ?? 'Organizer',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 isReleased ? 'Payout Authorized ' : escrowNote,
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 10, fontWeight: FontWeight.w800),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text('For Event: ${st['event'] ?? 'Milo Event'}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
 const SizedBox(height: 14),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Gross Ticket Sales', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
 Text(MiloAdminService.inr(gross), style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
 ],
 ),
 Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text('Milo Fee ($feePct%)', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
 Text(MiloAdminService.inr(fee), style: GoogleFonts.inter(color: MiloColors.amber, fontWeight: FontWeight.w700, fontSize: 12)),
 ],
 ),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text('Net Host Payout', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
 Text(MiloAdminService.inr(net), style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w900, fontSize: 15)),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Text('Bank Target: $bank', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const SizedBox(height: 14),
 if (!isReleased)
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 icon: const Icon(Icons.send_rounded, size: 16, color: MiloColors.bg),
 label: Text('Authorize Bank Settlement (${MiloAdminService.inr(net)}) ',
 style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 13)),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: () => _authorizePayout(st),
 ),
 ),
 ],
 ),
 );
 }

 // Tab 4: Trust & Moderation 
 Widget _buildModerationTab() {
    return AnimatedBuilder(
      animation: MiloModerationService.instance,
      builder: (context, _) {
        final modReports = MiloModerationService.instance.reports;
        if (modReports.isEmpty && _admin.reports.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            color: MiloColors.primaryLight,
            backgroundColor: MiloColors.bgSurface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              children: [_emptyState('No moderation reports open.', Icons.shield_rounded)],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: MiloColors.primaryLight,
          backgroundColor: MiloColors.bgSurface,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20),
            itemCount: modReports.isNotEmpty ? modReports.length : _admin.reports.length,
            itemBuilder: (context, index) {
              if (modReports.isNotEmpty) {
                return _buildModerationModelCard(modReports[index]);
              }
              return _buildReportCard(_admin.reports[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildModerationModelCard(MiloReportModel rep) {
    final isOpen = rep.status == 'open';
    final isSuspended = rep.status == 'action_taken' || rep.status == 'suspended';
    final isCritical = rep.severity.contains('Critical') || rep.duplicateCount >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MiloColors.bgSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCritical
              ? MiloColors.rose
              : (isOpen ? MiloColors.rose.withValues(alpha: 0.4) : MiloColors.border),
          width: isCritical ? 1.5 : 1.0,
        ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: MiloColors.rose.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCritical ? MiloColors.rose : MiloColors.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Incident #' + _shortId(rep.id) + ' • ' + rep.severity,
                      style: GoogleFonts.inter(
                        color: isCritical ? Colors.white : MiloColors.rose,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: MiloColors.bgCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: MiloColors.border),
                    ),
                    child: Text(
                      rep.targetType.name.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: MiloColors.textSecondary),
                    ),
                  ),
                ],
              ),
              Text(rep.timestamp, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rep.targetName,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
          ),
          const SizedBox(height: 4),

          // Deduplication badge (Instagram style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: rep.duplicateCount > 1
                  ? const Color(0xFFFEF2F2)
                  : MiloColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: rep.duplicateCount > 1 ? const Color(0xFFFECACA) : MiloColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rep.duplicateCount > 1 ? Icons.warning_amber_rounded : Icons.person_outline_rounded,
                  size: 13,
                  color: rep.duplicateCount > 1 ? const Color(0xFFDC2626) : MiloColors.textMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    rep.duplicateCount > 1
                        ? '🚨 ' + rep.duplicateCount.toString() + ' Users Reported: ' + rep.reporterNames.take(3).join(', ') + (rep.reporterNames.length > 3 ? ' +more' : '')
                        : 'Reported by: ' + rep.reporterName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: rep.duplicateCount > 1 ? FontWeight.w800 : FontWeight.w600,
                      color: rep.duplicateCount > 1 ? const Color(0xFFDC2626) : MiloColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: MiloColors.bgCard, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: ' + rep.reason,
                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, height: 1.3)),
                if (rep.details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(rep.details, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, height: 1.3)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (isOpen)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MiloColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      MiloModerationService.instance.dismissReport(rep.id);
                      _toast(AdminAction(true, 'Report #' + _shortId(rep.id) + ' dismissed as resolved.'));
                    },
                    child: Text('Dismiss', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiloColors.rose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      MiloModerationService.instance.takeActionSuspend(rep.id);
                      _toast(const AdminAction(true, 'Target suspended & restricted across platform.'));
                    },
                    child: Text('Suspend & Block 🚫',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  isSuspended ? Icons.block_rounded : Icons.check_circle_outline,
                  color: isSuspended ? MiloColors.rose : MiloColors.emerald,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isSuspended ? 'Target Suspended & Blocked — Closed' : 'Dismissed — Report Resolved',
                    style: GoogleFonts.inter(
                      color: isSuspended ? MiloColors.rose : MiloColors.emerald,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> rep) {
 final status = rep['status']?.toString() ?? 'open';
 final isOpen = status == 'open';
 final isSuspended = status == 'suspended';
 final details = rep['details']?.toString() ?? '';

 return Container(
 margin: const EdgeInsets.only(bottom: 18),
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: isOpen ? MiloColors.rose.withValues(alpha: 0.4) : MiloColors.border),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.rose.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 'Incident #${_shortId(rep['id']?.toString() ?? '')} • ${rep['severity'] ?? 'Medium'}',
 style: GoogleFonts.inter(color: MiloColors.rose, fontSize: 10, fontWeight: FontWeight.w800),
 ),
 ),
 Text(rep['timestamp']?.toString() ?? 'Recently', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 ],
 ),
 const SizedBox(height: 12),
 Text('Reported: ${rep['reported_name'] ?? 'Unknown user'}',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 3),
 Text('Filed By: ${rep['reporter_name'] ?? 'Unknown reporter'}', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(color: MiloColors.bgCard, borderRadius: BorderRadius.circular(10)),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Reason: ${rep['reason'] ?? ''}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.3)),
 if (details.isNotEmpty) ...[
 const SizedBox(height: 6),
 Text(details, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, height: 1.3)),
 ],
 ],
 ),
 ),
 const SizedBox(height: 14),
 if (isOpen)
 Row(
 children: [
 Expanded(
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: MiloColors.border),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () => _dismissReport(rep),
 child: Text('Dismiss', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12)),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.rose,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () => _suspendReport(rep),
 child: Text('Suspend Account ',
 style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
 ),
 ),
 ],
 )
 else
 Row(
 children: [
 Icon(
 isSuspended ? Icons.block_rounded : Icons.check_circle_outline,
 color: isSuspended ? MiloColors.rose : MiloColors.emerald,
 size: 16,
 ),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 isSuspended ? 'Account Suspension Recorded — Report Closed' : 'Dismissed — Report Resolved',
 style: GoogleFonts.inter(
 color: isSuspended ? MiloColors.rose : MiloColors.emerald,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 String _shortId(String id) {
 if (id.length > 8) return id.substring(id.length - 6);
 return id;
 }

 Widget _sectionHeader(String title, IconData icon, Color color) {
 return Row(
 children: [
 Icon(icon, size: 16, color: color),
 const SizedBox(width: 8),
 Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 ],
 );
 }

 Widget _emptyState(String message, IconData icon) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 children: [
 Icon(icon, color: MiloColors.textMuted, size: 28),
 const SizedBox(height: 10),
 Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12, height: 1.4)),
 ],
 ),
 );
 }

 Widget _buildMetricCard({required String title, required String value, required String change, required IconData icon, required Color color}) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(title, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
 Icon(icon, color: color, size: 18),
 ],
 ),
 const SizedBox(height: 8),
 Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 const SizedBox(height: 4),
 Text(change, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
 ],
 ),
 );
 }

 Widget _buildCategoryProgressBar(String label, double progress, String detail, Color color) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textPrimary))),
 Text(detail, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
 ],
 ),
 const SizedBox(height: 6),
 ClipRRect(
 borderRadius: BorderRadius.circular(6),
 child: LinearProgressIndicator(
 value: progress,
 backgroundColor: MiloColors.bgCard,
 valueColor: AlwaysStoppedAnimation<Color>(color),
 minHeight: 6,
 ),
 ),
 ],
 );
 }
}
