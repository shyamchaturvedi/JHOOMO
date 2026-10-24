import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/milo_db_service.dart';
import '../../services/milo_session_service.dart';
import '../../services/payment_approval_service.dart';
import '../../theme/milo_theme.dart';
import '../legal_policy_screen.dart';

class OrganizerDashboardScreen extends StatefulWidget {
 const OrganizerDashboardScreen({super.key});

 @override
 State<OrganizerDashboardScreen> createState() => _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
 String _selectedApprovalFilter = 'PENDING';

 bool _statsLoading = true;
 double _grossSales = 0;
 int _passesSold = 0;
 int _checkedInScanned = 0;
 List<EventModel> _hostedEvents = [];
 Map<String, int> _soldByEvent = {};
 final Map<String, int> _capacityByEvent = {};

 @override
 void initState() {
 super.initState();
 _loadOrganizerData();
 }

 Future<void> _loadOrganizerData() async {
 setState(() => _statsLoading = true);

 List<EventModel> events = [];
 final uid = MiloSessionService.currentUid;
 if (uid.isNotEmpty) {
 try {
 final snap = await FirebaseFirestore.instance
 .collection('events')
 .where('organizer_uid', isEqualTo: uid)
 .get();
 events = snap.docs
 .map((d) => MiloDbService.mapEventDoc({...d.data(), 'id': d.id}))
 .toList();
 } catch (e) {
 debugPrint('Organizer events load note: $e');
 }
 }

 List<Map<String, dynamic>> bookings = [];
 bool bookingsOk = false;
 try {
 final snap = await FirebaseFirestore.instance
 .collection('bookings')
 .limit(500)
 .get();
 bookings = snap.docs.map((d) => d.data()).toList();
 bookingsOk = true;
 } catch (e) {
 debugPrint('Organizer bookings load note: $e');
 }

 double gross = 0;
 int passes = 0;
 int scanned = 0;
 final organizerIds = events.map((e) => e.id).toSet();
 if (bookingsOk && organizerIds.isNotEmpty) {
 for (final b in bookings) {
 final eid = b['event_id']?.toString() ?? '';
 if (!organizerIds.contains(eid)) continue;
 final qty = ((b['quantity'] as num?) ?? 1).toInt();
 final amount = (b['total_amount'] as num?)?.toDouble() ?? 0;
 final confirmed = (b['status'] ?? '').toString() == 'CONFIRMED';
 if (confirmed) {
 gross += amount;
 passes += qty;
 }
 if (b['checked_in'] == true) scanned += 1;
 }
 }

 if (events.isEmpty) {
 try {
 final all = await MiloDbService.instance.getEvents();
 events = all.take(2).toList();
 } catch (e) {
 debugPrint('Organizer fallback events note: $e');
 events = [];
 }
 }

 final soldByEvent = <String, int>{};
 if (bookingsOk) {
 for (final e in events) {
 int sold = 0;
 for (final b in bookings) {
 if (b['event_id']?.toString() != e.id) continue;
 if ((b['status'] ?? '').toString() != 'CONFIRMED') continue;
 sold += ((b['quantity'] as num?) ?? 1).toInt();
 }
 soldByEvent[e.id] = sold;
 }
 } else {
 for (final e in events) {
 try {
 soldByEvent[e.id] = await MiloDbService.instance.soldCount(e.id);
 } catch (_) {
 soldByEvent[e.id] = 0;
 }
 }
 }

 final capacityByEvent = <String, int>{};
 for (final e in events) {
 var capacity =
 e.ticketTiers.fold<int>(0, (total, t) => total + t.available);
 if (capacity == 0) capacity = e.ticketsLeft;
 capacityByEvent[e.id] = capacity;
 }

 if (!mounted) return;
 setState(() {
 _grossSales = gross;
 _passesSold = passes;
 _checkedInScanned = scanned;
 _hostedEvents = events;
 _soldByEvent = soldByEvent;
 _capacityByEvent
 ..clear()
 ..addAll(capacityByEvent);
 _statsLoading = false;
 });
 }

 String _formatCurrency(double value) {
 try {
 final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
 return f.format(value);
 } catch (_) {
 return '₹${value.toStringAsFixed(0)}';
 }
 }

 void _showEditEventDialog(EventModel event) {
 final titleCtrl = TextEditingController(text: event.title);
 final dateCtrl = TextEditingController(text: event.date);
 final timeCtrl = TextEditingController(text: event.time);
 final venueCtrl = TextEditingController(text: event.venue);
 final priceCtrl = TextEditingController(text: event.startingPrice.toStringAsFixed(0));
 final cities = ['Lucknow', 'Ahmedabad', 'Bangalore', 'Mumbai', 'Delhi', 'Jaipur'];
 String city = cities.contains(event.city) ? event.city : cities.first;

 showDialog(
 context: context,
 builder: (dialogContext) {
 return StatefulBuilder(
 builder: (dialogContext, setDialogState) {
 return Dialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(20),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Edit Event Details',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 IconButton(
 icon: const Icon(Icons.close, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(dialogContext),
 ),
 ],
 ),
 const SizedBox(height: 12),
 _buildDialogLabel('Title'),
 _buildDialogField(titleCtrl),
 const SizedBox(height: 10),
 _buildDialogLabel('Date'),
 _buildDialogField(dateCtrl),
 const SizedBox(height: 10),
 _buildDialogLabel('Time'),
 _buildDialogField(timeCtrl),
 const SizedBox(height: 10),
 _buildDialogLabel('Venue'),
 _buildDialogField(venueCtrl),
 const SizedBox(height: 10),
 _buildDialogLabel('City'),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.border),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: city,
 dropdownColor: MiloColors.bgSurface,
 isExpanded: true,
 items: cities
 .map((c) => DropdownMenuItem(
 value: c,
 child: Text(c, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13))))
 .toList(),
 onChanged: (val) => setDialogState(() => city = val ?? city),
 ),
 ),
 ),
 const SizedBox(height: 10),
 _buildDialogLabel('Starting Price (₹)'),
 _buildDialogField(priceCtrl, keyboardType: TextInputType.number),
 const SizedBox(height: 18),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.emerald,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: () => _saveEventEdits(
 dialogContext,
 event,
 titleCtrl.text.trim(),
 dateCtrl.text.trim(),
 timeCtrl.text.trim(),
 venueCtrl.text.trim(),
 city,
 priceCtrl.text.trim(),
 ),
 child: Text('Save Changes',
 style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900)),
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

 Widget _buildDialogLabel(String text) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.textMuted)),
 );
 }

 Widget _buildDialogField(TextEditingController ctrl, {TextInputType keyboardType = TextInputType.text}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.border),
 ),
 child: TextField(
 controller: ctrl,
 keyboardType: keyboardType,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
 decoration: const InputDecoration(border: InputBorder.none),
 ),
 );
 }

 Future<void> _saveEventEdits(
 BuildContext dialogContext,
 EventModel event,
 String title,
 String date,
 String time,
 String venue,
 String city,
 String priceStr,
 ) async {
 final price = double.tryParse(priceStr) ?? event.startingPrice;
 if (title.isEmpty || venue.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Title and venue cannot be empty!', style: GoogleFonts.inter(color: MiloColors.rose)),
 ),
 );
 return;
 }
 Navigator.pop(dialogContext);

 bool savedRemotely = false;
 try {
 await FirebaseFirestore.instance.collection('events').doc(event.id).set({
 'title': title,
 'event_date': date,
 'event_time': time,
 'venue_name': venue,
 'city': city,
 'starting_price': price,
 }, SetOptions(merge: true));
 savedRemotely = true;
 } catch (e) {
 debugPrint('Event edit save note: $e');
 }

 final updated = EventModel(
 id: event.id,
 title: title,
 category: event.category,
 date: date,
 time: time,
 venue: venue,
 city: city,
 googleMapsUrl: event.googleMapsUrl,
 startingPrice: price,
 imageUrl: event.imageUrl,
 organizerName: event.organizerName,
 isVerifiedOrganizer: event.isVerifiedOrganizer,
 rating: event.rating,
 tags: event.tags,
 ticketsLeft: event.ticketsLeft,
 isTrending: event.isTrending,
 description: event.description,
 ticketTiers: event.ticketTiers,
 organizerCoupons: event.organizerCoupons,
 customTermsAndConditions: event.customTermsAndConditions,
 );

 if (!mounted) return;
 setState(() {
 final idx = _hostedEvents.indexWhere((e) => e.id == event.id);
 if (idx != -1) _hostedEvents[idx] = updated;
 });
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 savedRemotely
 ? 'Event "$title" updated successfully!'
 : 'Saved locally — Firestore unreachable, will sync later.',
 style: GoogleFonts.inter(
 color: savedRemotely ? MiloColors.emerald : MiloColors.amber, fontWeight: FontWeight.w700),
 ),
 ),
 );
 if (savedRemotely) _loadOrganizerData();
 }

 void _showProofDialog(PaymentApprovalRequest req) {
 showDialog(
 context: context,
 builder: (context) {
 return Dialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Payment Proof Receipt',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 IconButton(
 icon: const Icon(Icons.close, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 ],
 ),
 const SizedBox(height: 10),
 ClipRRect(
 borderRadius: BorderRadius.circular(16),
 child: Image.network(
 req.proofImageUrl.isNotEmpty
 ? req.proofImageUrl
 : 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400&q=80',
 height: 220,
 width: double.infinity,
 fit: BoxFit.cover,
 ),
 ),
 const SizedBox(height: 14),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Attendee:', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 Text(req.attendeeName, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
 ],
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Phone / WhatsApp:', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 Text(req.attendeePhone, style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 12)),
 ],
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('12-Digit UTR:', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 Text(req.utrNumber, style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w900, fontSize: 13)),
 ],
 ),
 if (req.note.isNotEmpty) ...[
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Attendee Note:', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 Text(req.note, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11)),
 ],
 ),
 ],
 ],
 ),
 ),
 const SizedBox(height: 16),
 if (req.status == 'PENDING')
 Row(
 children: [
 Expanded(
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: MiloColors.rose),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: () {
 Navigator.pop(context);
 _promptReject(req);
 },
 child: Text('Decline ', style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w800)),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.emerald,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: () async {
 final messenger = ScaffoldMessenger.of(context);
 final ok = await PaymentApprovalService.instance.approveRequest(req.id);
 if (!context.mounted) return;
 Navigator.pop(context);
 messenger.showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 ok
 ? ' Pass approved for ${req.attendeeName}! QR released.'
 : PaymentApprovalService.instance.lastActionError ?? 'Could not approve payment.',
 style: GoogleFonts.inter(
 color: ok ? MiloColors.emerald : MiloColors.rose,
 fontWeight: FontWeight.w700),
 ),
 ),
 );
 },
 child: Text('Approve Pass ', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900)),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 },
 );
 }

 void _promptReject(PaymentApprovalRequest req) {
 final reasonController = TextEditingController(text: 'UTR not matched in bank statement');
 showDialog(
 context: context,
 builder: (context) {
 return AlertDialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Text('Decline Payment Proof',
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text('Specify reason for attendee notification:',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
 const SizedBox(height: 10),
 TextField(
 controller: reasonController,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
 decoration: InputDecoration(
 filled: true,
 fillColor: MiloColors.bgCard,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
 ),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: Text('Cancel', style: GoogleFonts.inter(color: MiloColors.textMuted)),
 ),
 ElevatedButton(
 style: ElevatedButton.styleFrom(backgroundColor: MiloColors.rose),
 onPressed: () async {
 final messenger = ScaffoldMessenger.of(context);
 final ok = await PaymentApprovalService.instance
 .rejectRequest(req.id, reasonController.text.trim());
 if (!context.mounted) return;
 Navigator.pop(context);
 messenger.showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 ok
 ? 'Payment flagged as invalid.'
 : PaymentApprovalService.instance.lastActionError ?? 'Could not reject payment.',
 style: GoogleFonts.inter(color: ok ? MiloColors.rose : MiloColors.rose),
 ),
 ),
 );
 },
 child: Text('Confirm Decline', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
 ),
 ],
 );
 },
 );
 }

 @override
 Widget build(BuildContext context) {
 return ListenableBuilder(
 listenable: PaymentApprovalService.instance,
 builder: (context, _) {
 final service = PaymentApprovalService.instance;
 final pendingList = service.approvalRequests.where((r) {
 if (_selectedApprovalFilter == 'PENDING') return r.status == 'PENDING';
 if (_selectedApprovalFilter == 'APPROVED') return r.status == 'APPROVED';
 return true;
 }).toList();

 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Organizer Portal ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 18),
 ),
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 actions: [
 IconButton(
 icon: const Icon(Icons.help_outline_rounded, color: MiloColors.primaryLight),
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => const LegalPolicyScreen(
 title: 'Organizer Terms & Settlement',
 policyType: 'organizer_terms',
 ),
 ),
 );
 },
 ),
 ],
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.all(20),
 children: [
 // Revenue & Ticket Stats
 Container(
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [MiloColors.primary.withValues(alpha: 0.25), MiloColors.bgSurface],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('TOTAL GROSS SALES',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text('Settlement: Direct UPI / Self Gateway',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 9, fontWeight: FontWeight.w800)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(_statsLoading ? '₹ —' : _formatCurrency(_grossSales),
 style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: MiloColors.primaryLight)),
 const SizedBox(height: 16),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildStatCol('Tickets Sold', _statsLoading ? '— Passes' : '$_passesSold Passes'),
 _buildStatCol('Checked-In', _statsLoading ? '— Scanned' : '$_checkedInScanned Scanned'),
 _buildStatCol('Pending UTR', '${service.pendingCount} Requests'),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),

 // MANUAL PAYMENT APPROVALS QUEUE (User Specification) 
 Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5), width: 1.4),
 boxShadow: [
 BoxShadow(
 color: MiloColors.primary.withValues(alpha: 0.1),
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
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(
 gradient: MiloGradients.primaryBrand,
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
 ),
 const SizedBox(width: 10),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Payment Approvals Queue ',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 Text('Verify attendee UTR & activate QR passes',
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 ],
 ),
 ],
 ),
 if (service.pendingCount > 0)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.amber),
 ),
 child: Text(
 '${service.pendingCount} PENDING',
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: MiloColors.amber),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),

 // Filter Chips: Pending, Approved, All
 Row(
 children: [
 _buildFilterChip('PENDING', 'Pending (${service.pendingCount})'),
 const SizedBox(width: 8),
 _buildFilterChip('APPROVED', 'Approved'),
 const SizedBox(width: 8),
 _buildFilterChip('ALL', 'All History'),
 ],
 ),
 const SizedBox(height: 14),

 // Approval Request Items
 if (pendingList.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(20),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 ),
 child: Column(
 children: [
 const Icon(Icons.check_circle_outline, color: MiloColors.emerald, size: 36),
 const SizedBox(height: 8),
 Text(
 _selectedApprovalFilter == 'PENDING'
 ? 'All manual payments verified! Zero pending requests.'
 : 'No records found for this filter.',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 )
 else
 ...pendingList.map((req) {
 final isPending = req.status == 'PENDING';
 final isApproved = req.status == 'APPROVED';

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isPending ? MiloColors.amber.withValues(alpha: 0.4) : MiloColors.border,
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 Text(req.attendeeName,
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(width: 6),
 Text('(${req.attendeePhone})',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 ],
 ),
 Text(
 '₹${req.totalAmount.toStringAsFixed(0)}',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: MiloColors.primaryLight),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 '${req.eventTitle} • ${req.tierName} (${req.quantity} Passes)',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textSecondary),
 ),
 const SizedBox(height: 8),
 // UTR & Proof preview row
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 GestureDetector(
 onTap: () {
 Clipboard.setData(ClipboardData(text: req.utrNumber));
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('UTR Copied: ${req.utrNumber}'),
 duration: const Duration(seconds: 1),
 ),
 );
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.copy_rounded, color: MiloColors.primaryLight, size: 12),
 const SizedBox(width: 4),
 Text(
 'UTR: ${req.utrNumber}',
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
 ),
 ],
 ),
 ),
 ),
 TextButton.icon(
 style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
 onPressed: () => _showProofDialog(req),
 icon: const Icon(Icons.image_outlined, size: 14, color: MiloColors.primaryLight),
 label: Text(
 'View Proof ',
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: MiloColors.primaryLight),
 ),
 ),
 ],
 ),
 if (isPending) ...[
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: SizedBox(
 height: 36,
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: MiloColors.rose),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 onPressed: () => _promptReject(req),
 child: Text('Decline ', style: GoogleFonts.inter(color: MiloColors.rose, fontSize: 11, fontWeight: FontWeight.w800)),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 flex: 2,
 child: SizedBox(
 height: 36,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.emerald,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 onPressed: () async {
 final messenger = ScaffoldMessenger.of(context);
 final ok = await service.approveRequest(req.id);
 if (!mounted) return;
 messenger.showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 ok
 ? ' Pass approved for ${req.attendeeName}! QR released.'
 : service.lastActionError ?? 'Could not approve payment.',
 style: GoogleFonts.inter(
 color: ok ? MiloColors.emerald : MiloColors.rose,
 fontWeight: FontWeight.w700),
 ),
 ),
 );
 },
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.check, color: MiloColors.bg, size: 16),
 const SizedBox(width: 4),
 Text('Approve & Release QR',
 style: GoogleFonts.inter(color: MiloColors.bg, fontSize: 11, fontWeight: FontWeight.w900)),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 ] else if (isApproved) ...[
 const SizedBox(height: 6),
 Row(
 children: [
 const Icon(Icons.check_circle, color: MiloColors.emerald, size: 14),
 const SizedBox(width: 4),
 Text('Approved & QR Pass Issued to Attendee',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w700)),
 ],
 ),
 ],
 ],
 ),
 );
 }),
 ],
 ),
 ),
 const SizedBox(height: 20),

 // App is dashboard-only for organizers. All operations live on web.
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: const BoxDecoration(color: MiloColors.primaryLight, shape: BoxShape.circle),
 child: const Icon(Icons.language_rounded, color: MiloColors.bg, size: 20),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Manage on Web',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 2),
 Text('Event creation, gate scanning, staff access, KYC, payouts and settlements are handled from the organizer web dashboard.',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, height: 1.4)),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // Active Listings
 Text('Your Hosted Events', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 12),

 if (_statsLoading)
 ...List.generate(2, (_) {
 return Container(
 margin: const EdgeInsets.only(bottom: 14),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 Container(width: 60, height: 60, decoration: BoxDecoration(color: MiloColors.bgCard, borderRadius: BorderRadius.circular(12))),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(width: 140, height: 12, decoration: BoxDecoration(color: MiloColors.bgCard, borderRadius: BorderRadius.circular(6))),
 const SizedBox(height: 8),
 Container(width: 90, height: 10, decoration: BoxDecoration(color: MiloColors.bgCard, borderRadius: BorderRadius.circular(5))),
 ],
 ),
 ),
 ],
 ),
 );
 })
 else
 ..._hostedEvents.map((event) {
 final sold = _soldByEvent[event.id] ?? 0;
 final capacity = _capacityByEvent[event.id] ?? (event.ticketsLeft + sold);
 return Container(
 margin: const EdgeInsets.only(bottom: 14),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(18),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 ClipRRect(
 borderRadius: BorderRadius.circular(12),
 child: Image.network(event.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(event.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary), maxLines: 1),
 const SizedBox(height: 4),
 Text('Sold: $sold / $capacity passes', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w600)),
 ],
 ),
 ),
 IconButton(
 icon: const Icon(Icons.edit_note, color: MiloColors.primaryLight),
 onPressed: () => _showEditEventDialog(event),
 ),
 ],
 ),
 );
 }),
 const SizedBox(height: 30),
 ],
 ),
 );
 },
 );
 }

 Widget _buildFilterChip(String filter, String label) {
 final isSelected = _selectedApprovalFilter == filter;
 return GestureDetector(
 onTap: () => setState(() => _selectedApprovalFilter = filter),
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: isSelected ? MiloColors.primaryLight : MiloColors.border,
 ),
 ),
 child: Text(
 label,
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
 ),
 ),
 ),
 );
 }

 Widget _buildStatCol(String label, String val) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 const SizedBox(height: 2),
 Text(val, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
 ],
 );
 }
}
