import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/models.dart';
import '../../services/milo_db_service.dart';
import '../../services/milo_session_service.dart';
import '../../services/milo_staff_service.dart';
import '../../theme/milo_theme.dart';
import 'gate_manual_lookup_screen.dart';

class QRScannerScreen extends StatefulWidget {
 final EventModel? initialEvent;

 const QRScannerScreen({super.key, this.initialEvent});

 @override
 State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
 final MobileScannerController _scannerController = MobileScannerController();
 late EventModel _selectedEvent;
 List<EventModel> _events = [];
 int _scannedCount = 0;
 String _gateNumber = 'Gate 1 (Main Entrance)';
 bool _isProcessing = false;
 String _lastPayload = '';
 DateTime? _lastPayloadAt;
 final TextEditingController _manualTicketCtrl = TextEditingController();

 static const EventModel _fallbackEvent = EventModel(
 id: 'e1',
  title: 'Jhoomo Live Event',
 category: 'Events',
 date: 'This Weekend',
 time: '07:00 PM',
  venue: 'Jhoomo Venue',
 city: 'Lucknow',
 startingPrice: 499.0,
 imageUrl:
 'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&w=800&q=80',
 organizerName: 'Official Organizer',
 tags: ['Verified'],
 ticketsLeft: 50,
 description: 'Live event on Jhoomo app',
 ticketTiers: [],
 );

 List<Map<String, dynamic>> _recentScans = [
 {
 'name': 'Sahil Kumar',
 'tier': 'Couple VIP Pass',
 'id': 'JHOOMO-892182',
 'time': 'Just now',
 'status': 'VALID',
 'eventId': 'e1',
 },
 {
 'name': 'Pooja Verma',
 'tier': 'Single Entry Pass',
 'id': 'JHOOMO-473829',
 'time': '2 mins ago',
 'status': 'VALID',
 'eventId': 'e1',
 },
 {
 'name': 'Rohit Sharma',
 'tier': 'Single Entry Pass',
 'id': 'JHOOMO-119283',
 'time': '5 mins ago',
 'status': 'ALREADY_CHECKED_IN',
 'eventId': 'e1',
 },
 ];

 @override
 void initState() {
 super.initState();
 _selectedEvent = widget.initialEvent ?? _fallbackEvent;
 _loadEvents();
 _refreshCheckedInCount();
 _loadRecentLogs();
 _loadGateFromStaffAccess();
 }

 @override
 void dispose() {
 _manualTicketCtrl.dispose();
 _scannerController.dispose();
 super.dispose();
 }

 Future<void> _loadEvents() async {
 try {
 final events = await MiloDbService.instance.getEvents();
 if (!mounted) return;
 setState(() {
 _events = events;
 if (widget.initialEvent == null && events.isNotEmpty) {
 _selectedEvent = events.first;
 }
 });
 _refreshCheckedInCount();
 } catch (e) {
 if (mounted) setState(() => _events = []);
 }
 }

 Future<void> _refreshCheckedInCount() async {
 try {
 final count = await MiloDbService.instance.checkedInCount(_selectedEvent.id);
 if (mounted) setState(() => _scannedCount = count);
 } catch (e) {
 debugPrint('Scanner checked-in count note: $e');
 }
 }

 Future<void> _loadRecentLogs() async {
 try {
 final logs = await MiloStaffService.instance.fetchCheckInLogs(_selectedEvent.id);
 if (!mounted || logs.isEmpty) return;
 setState(() {
 _recentScans = logs.map((row) {
 return {
 'name': (row['attendee_name'] ?? 'Attendee').toString(),
 'tier': row['status'] == 'VALID' ? 'Verified Pass' : 'Scan Alert',
 'id': (row['booking_ref'] ?? '').toString(),
 'time': _relativeTime(row['created_at']),
 'status': (row['status'] ?? 'VALID').toString(),
 'eventId': (row['event_id'] ?? '').toString(),
 };
 }).toList();
 });
 } catch (e) {
 debugPrint('Scanner recent logs note: $e');
 }
 }

 Future<void> _loadGateFromStaffAccess() async {
 try {
 final assignment = await MiloStaffService.instance.activeAssignmentFor(
 name: MiloSessionService.currentUserName,
 phone: MiloSessionService.currentUserPhone,
 );
 final gate = (assignment?['gate'] ?? '').toString();
 if (mounted && gate.isNotEmpty) {
 setState(() => _gateNumber = gate);
 }
 } catch (e) {
 debugPrint('Scanner gate lookup note: $e');
 }
 }

 String _relativeTime(dynamic createdAt) {
 if (createdAt is! Timestamp) return 'Recently';
 final diff = DateTime.now().difference(createdAt.toDate());
 if (diff.inMinutes < 1) return 'Just now';
 if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
 if (diff.inHours < 24) return '${diff.inHours}h ago';
 return '${diff.inDays}d ago';
 }

 void _onBarcodeDetected(BarcodeCapture capture) {
 if (_isProcessing || !mounted) return;
 final codes = capture.barcodes;
 if (codes.isEmpty) return;
 final code = codes.first.rawValue?.trim();
 if (code == null || code.isEmpty) return;
 _verifyPayload(code);
 }

 /// Single validation path shared by camera scans, manual booking-ID
 /// entry and the demo simulator chips — server-side atomic check-in.
 Future<void> _verifyPayload(String payload) async {
 final code = payload.trim();
 if (code.isEmpty || _isProcessing) return;

 final now = DateTime.now();
 if (code == _lastPayload &&
 _lastPayloadAt != null &&
 now.difference(_lastPayloadAt!).inSeconds < 3) {
 return;
 }
 _lastPayload = code;
 _lastPayloadAt = now;

 setState(() => _isProcessing = true);

 Map<String, dynamic> result;
 try {
 result = await MiloDbService.instance.verifyAndCheckIn(
 payload: code,
 eventId: _selectedEvent.id,
 gate: _gateNumber,
 staffName: MiloSessionService.currentUserName,
 );
 } catch (e) {
 result = {'status': 'ERROR', 'message': 'Verification failed: $e'};
 }

 if (!mounted) return;
 _handleVerifyResult(code, result);
 _refreshCheckedInCount();
 }

 void _handleVerifyResult(String code, Map<String, dynamic> result) {
 final status = (result['status'] ?? 'ERROR').toString();
 final message = (result['message'] ?? '').toString();
 final rawBooking = result['booking'];
 final booking = rawBooking is Map ? Map<String, dynamic>.from(rawBooking) : null;
 final attendeeName = (booking?['attendee_name'] ?? 'Attendee').toString();
 final tierName = (booking?['tier_name'] ?? 'Verified Pass').toString();

 _recordScan(code, attendeeName, tierName, status);
 _logScan(code, attendeeName, status);

 switch (status) {
 case 'VALID':
 _showResultDialog(
 title: 'ENTRY APPROVED ',
 message:
 'Valid cryptographically verified pass for ${_selectedEvent.title}.\nAdmit $attendeeName through $_gateNumber.',
 color: MiloColors.emerald,
 isValid: true,
 badgeText: 'VERIFIED 100%',
 );
 break;
 case 'ALREADY_USED':
 _showResultDialog(
 title: 'ALREADY CHECKED IN ',
 message:
 'DUPLICATE TICKET DETECTED!\n$message\nScreenshot passes are strictly prohibited.',
 color: MiloColors.amber,
 isValid: false,
 badgeText: 'SECURITY ALERT',
 );
 break;
 case 'WRONG_EVENT':
 _showResultDialog(
 title: 'WRONG EVENT TICKET ',
 message:
 'This pass belongs to a DIFFERENT event! Entry strictly denied for "${_selectedEvent.title}".\n$message',
 color: MiloColors.rose,
 isValid: false,
 badgeText: 'EVENT MISMATCH',
 );
 break;
 case 'REJECTED':
 _showResultDialog(
 title: 'PAYMENT REJECTED ',
 message: '$message\nEntry strictly denied.',
 color: MiloColors.rose,
 isValid: false,
 badgeText: 'ENTRY DENIED',
 );
 break;
 case 'PENDING':
 _showResultDialog(
 title: 'PAYMENT STILL PENDING ⏳',
 message: '$message\nAsk the attendee to contact the event organizer.',
 color: MiloColors.amber,
 isValid: false,
 badgeText: 'NOT APPROVED',
 );
 break;
 case 'OFFLINE':
 _showResultDialog(
 title: 'OFFLINE — CANNOT VERIFY ',
 message:
 '$message\nReconnect to the internet before admitting this attendee.',
 color: MiloColors.amber,
 isValid: false,
 badgeText: 'NO CONNECTION',
 );
 break;
 case 'INVALID':
 _showResultDialog(
 title: 'FORGED / INVALID PASS ',
 message:
 '$message\nThis QR code was not generated by Jhoomo servers for a valid booking.',
 color: MiloColors.rose,
 isValid: false,
 badgeText: 'COUNTERFEIT',
 );
 break;
 default:
 _showResultDialog(
 title: 'VERIFICATION ERROR ',
 message: message.isEmpty ? 'Could not verify this pass. Try again.' : message,
 color: MiloColors.rose,
 isValid: false,
 badgeText: 'SCAN FAILED',
 );
 }
 }

 void _recordScan(String code, String name, String tier, String status) {
 setState(() {
 _recentScans.insert(0, {
 'name': name,
 'tier': tier,
 'id': code,
 'time': 'Just now',
 'status': status,
 'eventId': _selectedEvent.id,
 });
 if (_recentScans.length > 50) _recentScans.removeLast();
 });
 }

 void _logScan(String code, String attendeeName, String status) {
 MiloStaffService.instance.logCheckIn(
 bookingRef: code,
 attendeeName: attendeeName,
 eventId: _selectedEvent.id,
 gate: _gateNumber,
 staff: MiloSessionService.currentUserName.isEmpty ? 'Gate Staff' : MiloSessionService.currentUserName,
 status: status,
 );
 }

 void _showEventSelectorModal() {
 showModalBottomSheet(
 context: context,
 backgroundColor: Colors.transparent,
 builder: (context) {
 return ClipRRect(
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 child: BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
 child: Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.98),
 borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
 border: Border.all(color: MiloColors.glassBorder),
 ),
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
 Text(
 'Select Event to Scan Passes For ',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 const SizedBox(height: 6),
 Text(
 'Tickets will be verified ONLY if they belong to this selected event.',
 style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted),
 ),
 const SizedBox(height: 16),
 ..._events.take(4).map((event) {
 final isSelected = _selectedEvent.id == event.id;
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary.withValues(alpha: 0.15) : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: isSelected ? MiloColors.primaryLight : MiloColors.border),
 ),
 child: ListTile(
 leading: ClipRRect(
 borderRadius: BorderRadius.circular(10),
 child: Image.network(event.imageUrl, width: 44, height: 44, fit: BoxFit.cover),
 ),
 title: Text(
 event.title,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
 color: isSelected ? MiloColors.primaryLight : MiloColors.textPrimary,
 ),
 maxLines: 1,
 ),
 subtitle: Text(
 '${event.venue}, ${event.city}',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
 ),
 trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: MiloColors.primaryLight) : null,
 onTap: () {
 setState(() => _selectedEvent = event);
 _refreshCheckedInCount();
 _loadRecentLogs();
 Navigator.pop(context);
 },
 ),
 );
 }),
 ],
 ),
 ),
 ),
 );
 },
 );
 }

 void _showResultDialog({
 required String title,
 required String message,
 required Color color,
 required bool isValid,
 required String badgeText,
 }) {
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (context) => BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
 child: Dialog(
 backgroundColor: Colors.transparent,
 insetPadding: const EdgeInsets.symmetric(horizontal: 20),
 child: Container(
 padding: const EdgeInsets.all(24),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.98),
 borderRadius: BorderRadius.circular(28),
 border: Border.all(color: color, width: 2),
 boxShadow: [
 BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 4)),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color),
 ),
 child: Text(
 badgeText,
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 1),
 ),
 ),
 const SizedBox(height: 14),
 Icon(isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded, color: color, size: 64),
 const SizedBox(height: 12),
 Text(
 title,
 style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 10),
 Text(
 message,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, height: 1.45),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 24),
 SizedBox(
 width: double.infinity,
 height: 48,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: color,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 onPressed: () {
 Navigator.pop(context);
 if (mounted) setState(() => _isProcessing = false);
 },
 child: Text(
 'Next Attendee Scan ',
 style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.black,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Gate Security & Check-in ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
 if (MiloSessionService.currentRole == MiloRole.staff)
 Text(
 ' Staff Mode Locked • $_gateNumber',
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF10B981),
 ),
 ),
 ],
 ),
 leading: MiloSessionService.currentRole == MiloRole.staff
 ? IconButton(
 icon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981)),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Staff scanner is locked to gate entry operations.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 },
 )
 : IconButton(
 icon: const Icon(Icons.arrow_back, color: Colors.white),
 onPressed: () => Navigator.pop(context),
 ),
 actions: [
 IconButton(
 icon: const Icon(Icons.manage_search_rounded, color: Colors.white, size: 24),
 tooltip: 'Manual Lookup & Offline Manifest',
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => GateManualLookupScreen(
 eventId: _selectedEvent.id,
 gateName: _gateNumber,
 ),
 ),
 );
 },
 ),
 if (MiloSessionService.currentRole == MiloRole.staff)
 IconButton(
 icon: const Icon(Icons.logout_rounded, color: Colors.white70),
 tooltip: 'Exit Staff Mode',
 onPressed: () async {
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
 title: Text('Exit Staff Scanner?',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 content: Text(
 'This will end your active gate scanning duty. You will need your organizer passcode to log back in.',
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: Text('Cancel', style: GoogleFonts.inter(color: MiloColors.textMuted)),
 ),
 ElevatedButton(
 style: ElevatedButton.styleFrom(backgroundColor: MiloColors.rose),
 onPressed: () => Navigator.pop(ctx, true),
 child: Text('Exit & Logout',
 style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
 ),
 ],
 ),
 );
 if (confirm == true && context.mounted) {
 await MiloSessionService.logout();
 if (context.mounted) {
 Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
 }
 }
 },
 ),
 ],
 ),
 body: Column(
 children: [
 // Active Selected Event Bar 
 GestureDetector(
 onTap: _showEventSelectorModal,
 child: Container(
 margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.9),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.6)),
 ),
 child: Row(
 children: [
 const Icon(Icons.confirmation_number_rounded, color: MiloColors.primaryLight, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'SCANNING FOR EVENT:',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8),
 ),
 Text(
 _selectedEvent.title,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text('Change ', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 ),
 ),

 // Live Camera Scanner Viewfinder with Laser Line 
 Expanded(
 flex: 4,
 child: Stack(
 alignment: Alignment.center,
 children: [
 Container(
 color: const Color(0xFF0C1012),
 child: const Center(
 child: Icon(Icons.camera_alt_outlined, size: 90, color: Colors.white10),
 ),
 ),
 Positioned.fill(
 child: MobileScanner(
 controller: _scannerController,
 onDetect: _onBarcodeDetected,
 ),
 ),
 IgnorePointer(
 child: Container(
 width: 240,
 height: 240,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: MiloColors.primaryLight, width: 3),
 boxShadow: [
 BoxShadow(color: MiloColors.primaryLight.withValues(alpha: 0.3), blurRadius: 24),
 ],
 ),
 child: Stack(
 alignment: Alignment.center,
 children: [
 const Icon(Icons.qr_code_scanner_rounded, size: 70, color: MiloColors.primaryLight),
 // Animated scanning bar
 Positioned(
 top: 110,
 left: 20,
 right: 20,
 child: Container(
 height: 2,
 decoration: const BoxDecoration(
 color: MiloColors.cyan,
 boxShadow: [
 BoxShadow(color: MiloColors.cyan, blurRadius: 10, spreadRadius: 2),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 if (_isProcessing)
 Positioned.fill(
 child: Container(
 color: Colors.black45,
 child: const Center(
 child: CircularProgressIndicator(color: MiloColors.primaryLight),
 ),
 ),
 ),
 Positioned(
 top: 12,
 right: 12,
 child: ValueListenableBuilder<MobileScannerState>(
 valueListenable: _scannerController,
 builder: (context, state, child) {
 final torchOn = state.torchState == TorchState.on;
 return GestureDetector(
 onTap: () => _scannerController.toggleTorch(),
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Colors.black.withValues(alpha: 0.6),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: torchOn ? MiloColors.amber : MiloColors.glassBorder),
 ),
 child: Icon(
 torchOn ? Icons.flashlight_on : Icons.flashlight_off,
 color: torchOn ? MiloColors.amber : Colors.white,
 size: 18,
 ),
 ),
 );
 },
 ),
 ),
 Positioned(
 bottom: 16,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.black.withValues(alpha: 0.85),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.5)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.lock_outline_rounded, color: MiloColors.emerald, size: 14),
 const SizedBox(width: 6),
 Text('100% Anti-Cheating & Event ID Verification Active', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
 ],
 ),
 ),
 ),
 ],
 ),
 ),

 // Bottom Gate Check-in Console 
 Expanded(
 flex: 5,
 child: Container(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
 decoration: const BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('TOTAL ADMITTED', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
 Text('$_scannedCount Attendees', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
 ],
 ),
 // Security Testing Simulator Chips
 Wrap(
 spacing: 6,
 runSpacing: 6,
 alignment: WrapAlignment.end,
 children: [
 _buildSimulatorButton(
 'Valid Pass',
 MiloColors.emerald,
 () => _verifyPayload('JHOOMO-SELF-PAY-9842'),
 ),
 _buildSimulatorButton(
 'Wrong Event',
 MiloColors.rose,
 () => _verifyPayload('JHOOMO-SELF-PAY-7719'),
 ),
 _buildSimulatorButton(
 'Duplicate',
 MiloColors.amber,
 () => _verifyPayload('JHOOMO-SELF-PAY-9842'),
 ),
 _buildSimulatorButton(
 'Invalid',
 MiloColors.rose,
 () => _verifyPayload('JHOOMO-FORGED-99999'),
 ),
 ],
 ),
 ],
 ),
 const SizedBox(height: 14),

 // Manual Verification Fallback
 Row(
 children: [
 Expanded(
 child: Container(
 height: 44,
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: _manualTicketCtrl,
 textCapitalization: TextCapitalization.characters,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 hintText: 'Enter Booking ID (e.g. JHOOMO-892182)',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 border: InputBorder.none,
 isDense: true,
 contentPadding: const EdgeInsets.symmetric(vertical: 12),
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 ),
 onPressed: () {
 final code = _manualTicketCtrl.text.trim();
 _manualTicketCtrl.clear();
 _verifyPayload(code);
 },
 child: Text('Verify', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900, fontSize: 13)),
 ),
 ],
 ),
 const SizedBox(height: 14),

 Text('Live Gate Scan Activity', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 8),

 Expanded(
 child: ListView.builder(
 physics: const BouncingScrollPhysics(),
 itemCount: _recentScans.length,
 itemBuilder: (context, index) {
 final scan = _recentScans[index];
 final isValid = scan['status'] == 'VALID';

 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: isValid ? MiloColors.border : MiloColors.amber.withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 Icon(
 isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
 color: isValid ? MiloColors.emerald : MiloColors.amber,
 size: 16,
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(scan['name'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textPrimary)),
 Text('${scan['id']} • ${scan['tier']}', style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 ],
 ),
 ],
 ),
 Text(scan['time'], style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted)),
 ],
 ),
 );
 },
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildSimulatorButton(String label, Color color, VoidCallback onTap) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: color.withValues(alpha: 0.5)),
 ),
 child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
 ),
 );
 }
}
