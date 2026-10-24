import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';

/// S-48 · Manual Lookup & Offline Gate Mode Screen
/// For Gate Leads: Lookup ticket via booking ref (JHOOMO-######) + last 4 digits of phone
/// Offline gate manifest status with local reconciliation queue
class GateManualLookupScreen extends StatefulWidget {
 final String eventId;
 final String gateName;

 const GateManualLookupScreen({
 super.key,
 required this.eventId,
 required this.gateName,
 });

 @override
 State<GateManualLookupScreen> createState() => _GateManualLookupScreenState();
}

class _GateManualLookupScreenState extends State<GateManualLookupScreen> {
 final _bookingRefCtrl = TextEditingController();
 final _phoneLast4Ctrl = TextEditingController();

 bool _isSearching = false;
 Map<String, dynamic>? _foundTicket;
 bool _isAdmitted = false;
 int _offlineQueueCount = 0;

 void _searchTicket() async {
 final ref = _bookingRefCtrl.text.trim().toUpperCase();
 final phone4 = _phoneLast4Ctrl.text.trim();

 if (ref.isEmpty || phone4.length < 4) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Enter 6-digit Booking Ref and last 4 digits of attendee phone number'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 return;
 }

 setState(() {
 _isSearching = true;
 _foundTicket = null;
 _isAdmitted = false;
 });

 await Future.delayed(const Duration(milliseconds: 650));

 if (!mounted) return;
 setState(() {
 _isSearching = false;
 _foundTicket = {
 'ref': ref.startsWith('JHOOMO-') ? ref : 'JHOOMO-$ref',
 'attendee': 'Sahil K.',
 'phoneMasked': '+91 XXXXX XX$phone4',
 'tier': 'VIP Couple Pass (Admits 2)',
 'admits': 2,
 'status': 'VALID',
 'bookedAt': 'Yesterday, 8:45 PM',
 };
 });
 }

 void _admitAttendee() {
 HapticFeedback.heavyImpact();
 setState(() {
 _isAdmitted = true;
 _offlineQueueCount++;
 });

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('ENTRY APPROVED — ${_foundTicket?['attendee']} (${_foundTicket?['tier']}) admitted at ${widget.gateName}'),
 backgroundColor: MiloColors.accentGreen,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 @override
 void dispose() {
 _bookingRefCtrl.dispose();
 _phoneLast4Ctrl.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: const Color(0xFF0F172A), // Royal Navy / Locked Staff Theme
 appBar: AppBar(
 backgroundColor: const Color(0xFF1E293B),
 elevation: 0,
 title: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Manual Gate Entry Lookup',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 Text(
 ' Gate Lead • ${widget.gateName}',
 style: GoogleFonts.inter(color: MiloColors.amber, fontSize: 11, fontWeight: FontWeight.w600),
 ),
 ],
 ),
 ),
 body: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
 children: [
 // Offline Manifest Banner
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFF1E293B),
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: Colors.white12),
 ),
 child: Row(
 children: [
 const Icon(Icons.download_done_rounded, color: MiloColors.accentGreen, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Offline Gate Manifest Active',
 style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
 ),
 Text(
 'Ed25519 Local Verification • $_offlineQueueCount scans queued',
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 Text(
 'SEARCH ATTENDEE BY PASS DETAILS',
 style: GoogleFonts.inter(
 color: Colors.white38,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 ),
 ),
 const SizedBox(height: 12),

 // Booking Ref Input
 TextField(
 controller: _bookingRefCtrl,
 textCapitalization: TextCapitalization.characters,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 labelText: 'Booking Reference (JHOOMO-######)',
 labelStyle: GoogleFonts.inter(color: Colors.white60),
 prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Colors.white38),
 filled: true,
 fillColor: const Color(0xFF1E293B),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Colors.white12),
 ),
 ),
 ),
 const SizedBox(height: 14),

 // Phone Last 4 Digits Input
 TextField(
 controller: _phoneLast4Ctrl,
 keyboardType: TextInputType.number,
 maxLength: 4,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 counterText: '',
 labelText: 'Attendee Phone (Last 4 Digits)',
 labelStyle: GoogleFonts.inter(color: Colors.white60),
 prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white38),
 filled: true,
 fillColor: const Color(0xFF1E293B),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: const BorderSide(color: Colors.white12),
 ),
 ),
 ),
 const SizedBox(height: 20),

 SizedBox(
 width: double.infinity,
 height: 48,
 child: ElevatedButton(
 onPressed: _isSearching ? null : _searchTicket,
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 child: _isSearching
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
 )
 : Text(
 'Verify & Search Ticket',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
 ),
 ),
 ),
 const SizedBox(height: 24),

 // Found Ticket Result Card
 if (_foundTicket != null) ...[
 Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: const Color(0xFF1E293B),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: _isAdmitted ? MiloColors.accentGreen : MiloColors.primary,
 width: 1.5,
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 _foundTicket!['ref'],
 style: GoogleFonts.inter(
 color: MiloColors.primaryLight,
 fontSize: 16,
 fontWeight: FontWeight.w800,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: (_isAdmitted ? MiloColors.accentGreen : Colors.blueAccent)
 .withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 _isAdmitted ? 'ADMITTED (GATE 1)' : 'VALID TICKET',
 style: GoogleFonts.inter(
 color: _isAdmitted ? MiloColors.accentGreen : Colors.blueAccent,
 fontSize: 11,
 fontWeight: FontWeight.w800,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Divider(color: Colors.white12, height: 1),
 const SizedBox(height: 12),
 _buildDetailRow('Guest Name', _foundTicket!['attendee']),
 const SizedBox(height: 8),
 _buildDetailRow('Phone', _foundTicket!['phoneMasked']),
 const SizedBox(height: 8),
 _buildDetailRow('Tier', _foundTicket!['tier']),
 const SizedBox(height: 8),
 _buildDetailRow('Booked At', _foundTicket!['bookedAt']),
 const SizedBox(height: 18),
 SizedBox(
 width: double.infinity,
 height: 48,
 child: ElevatedButton.icon(
 onPressed: _isAdmitted ? null : _admitAttendee,
 icon: Icon(_isAdmitted ? Icons.check_circle : Icons.door_front_door_outlined),
 label: Text(_isAdmitted ? 'Admitted Successfully' : 'Admit Attendee (Check In)'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _isAdmitted ? Colors.white12 : MiloColors.accentGreen,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildDetailRow(String label, String value) {
 return Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
 Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
 ],
 );
 }
}
