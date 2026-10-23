import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../services/milo_db_service.dart';
import '../../services/milo_session_service.dart';
import '../../services/milo_staff_service.dart';
import '../../theme/milo_theme.dart';

class StaffRoleModel {
 final String id;
 final String name;
 final String phone;
 final String role; // 'Gate Scanner', 'VIP Security', 'Host Coordinator', 'Kitty Desk Lead'
 final String assignedEvent;
 final String assignedGate;
 final bool isAccessActive;
 final String passCode;

 const StaffRoleModel({
 required this.id,
 required this.name,
 required this.phone,
 required this.role,
 required this.assignedEvent,
 required this.assignedGate,
 this.isAccessActive = true,
 required this.passCode,
 });
}

class ManageStaffRolesScreen extends StatefulWidget {
 const ManageStaffRolesScreen({super.key});

 @override
 State<ManageStaffRolesScreen> createState() => _ManageStaffRolesScreenState();
}

class _ManageStaffRolesScreenState extends State<ManageStaffRolesScreen> {
 final List<StaffRoleModel> _staffList = [
 const StaffRoleModel(
 id: 'st_1',
 name: 'Ramesh Singh',
 phone: '+91 98765 43210',
 role: 'Gate 1 Scanner (Single Entry)',
 assignedEvent: 'Grand Dandiya Mahotsav 2026',
 assignedGate: 'Gate No. 1 - General Standing',
 isAccessActive: true,
 passCode: 'GATE1-SEC-99',
 ),
 const StaffRoleModel(
 id: 'st_2',
 name: 'Vikram Joshi',
 phone: '+91 91234 56789',
 role: 'VIP Lounge & Table Host',
 assignedEvent: 'Grand Dandiya Mahotsav 2026',
 assignedGate: 'VIP Stage Entry & High Tables',
 isAccessActive: true,
 passCode: 'VIP-HOST-44',
 ),
 const StaffRoleModel(
 id: 'st_3',
 name: 'Priya Tandon',
 phone: '+91 99887 76655',
 role: 'Ladies & Kitty Desk Coordinator',
 assignedEvent: 'Sunday Kitty & Tambola Gala',
 assignedGate: 'Pink Verandah Reception Desk',
 isAccessActive: true,
 passCode: 'KITTY-DESK-12',
 ),
 ];

 final TextEditingController _nameCtrl = TextEditingController();
 final TextEditingController _phoneCtrl = TextEditingController();
 String _selectedRole = 'Gate Scanner (Tickets Only)';
 String? _selectedEvent;
 String? _selectedEventId;
 String _selectedGate = 'Gate No. 1 (Main Entrance)';
 List<EventModel> _events = [];

 @override
 void initState() {
 super.initState();
 _loadEvents();
 _loadStaff();
 }

 Future<void> _loadEvents() async {
 try {
 final uid = MiloSessionService.currentUid;
 var events = await MiloDbService.instance.getOrganizerEvents(uid);
 if (events.isEmpty) {
 events = await MiloDbService.instance.getEvents();
 }
 if (!mounted) return;
 setState(() {
 _events = events;
 final valid = _selectedEvent != null && events.any((e) => e.id == _selectedEventId);
 if (!valid) {
 _selectedEventId = events.isNotEmpty ? events.first.id : null;
 _selectedEvent = events.isNotEmpty ? events.first.title : null;
 }
 });
 } catch (e) {
 if (mounted) setState(() => _events = []);
 }
 }

 Future<void> _loadStaff() async {
 final rows = await MiloStaffService.instance.fetchStaff();
 if (!mounted || rows == null) return;
 setState(() {
 _staffList
 ..clear()
 ..addAll(rows.map(_mapStaffDoc));
 });
 }

 StaffRoleModel _mapStaffDoc(Map<String, dynamic> row) {
 return StaffRoleModel(
 id: (row['doc_id'] ?? row['id'] ?? '').toString(),
 name: (row['name'] ?? 'Staff Member').toString(),
 phone: (row['phone'] ?? '').toString(),
 role: (row['role'] ?? 'Gate Scanner').toString(),
 assignedEvent: (row['event_title'] ?? row['assigned_event'] ?? '').toString(),
 assignedGate: (row['gate'] ?? row['assigned_gate'] ?? '').toString(),
 isAccessActive: row['is_access_active'] ?? true,
 passCode: (row['passcode'] ?? '').toString(),
 );
 }

 final List<String> _roleOptions = [
 'Gate Scanner (Tickets Only)',
 'VIP Access & Table Host',
 'Ladies/Kitty Desk Lead',
 'Security Head (Override Access)',
 ];

 final List<String> _gateOptions = [
 'Gate No. 1 (Main Entrance)',
 'Gate No. 2 (VIP / Fast-Track)',
 'Kitty & Private Hall Desk',
 'Backstage & Performer Zone',
 ];

 void _showAddStaffModal() {
 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (context) {
 return StatefulBuilder(
 builder: (context, setModalState) {
 return Container(
 padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Center(
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(color: MiloColors.textMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
 ),
 ),
 const SizedBox(height: 18),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Assign New Staff / Gate Guard ',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 IconButton(
 icon: const Icon(Icons.close, color: MiloColors.textMuted),
 onPressed: () => Navigator.pop(context),
 ),
 ],
 ),
 const SizedBox(height: 12),

 // Staff Name
 Text('Staff Member Name', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 _buildModalTextField(_nameCtrl, 'e.g. Suresh Kumar (Gate Guard)'),
 const SizedBox(height: 12),

 // Mobile Number
 Text('Staff Phone / Mobile Number', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 _buildModalTextField(_phoneCtrl, 'e.g. +91 98765 43210'),
 const SizedBox(height: 12),

 // Assigned Event
 Text('Assign to Event / Program', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: (_selectedEventId != null && _events.any((e) => e.id == _selectedEventId)) ? _selectedEventId : null,
 hint: Text('Select event', style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted)),
 isExpanded: true,
 dropdownColor: MiloColors.bgSurface,
 items: _events.map((e) {
 return DropdownMenuItem(
 value: e.id,
 child: Text(e.title, style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
 );
 }).toList(),
 onChanged: (val) => setModalState(() {
 _selectedEventId = val;
 _selectedEvent = _events.firstWhere((e) => e.id == val, orElse: () => _events.first).title;
 }),
 ),
 ),
 ),
 const SizedBox(height: 12),

 // Specific Assigned Gate / Zone
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Assigned Gate / Zone', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _selectedGate,
 isExpanded: true,
 dropdownColor: MiloColors.bgSurface,
 items: _gateOptions.map((g) {
 return DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textPrimary)));
 }).toList(),
 onChanged: (val) => setModalState(() => _selectedGate = val ?? _gateOptions.first),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Permission Role', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
 const SizedBox(height: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _selectedRole,
 isExpanded: true,
 dropdownColor: MiloColors.bgSurface,
 items: _roleOptions.map((r) {
 return DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textPrimary)));
 }).toList(),
 onChanged: (val) => setModalState(() => _selectedRole = val ?? _roleOptions.first),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
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
 onPressed: () async {
 final name = _nameCtrl.text.trim();
 final phone = _phoneCtrl.text.trim();
 if (name.isEmpty || phone.isEmpty) return;

 final matched = _events.where((e) => e.id == _selectedEventId);
 final event = matched.isNotEmpty ? matched.first : null;
 final passcode = MiloStaffService.generatePasscode();

 setState(() {
 _staffList.insert(
 0,
 StaffRoleModel(
 id: 'local_${DateTime.now().millisecondsSinceEpoch}',
 name: name,
 phone: phone,
 role: _selectedRole,
 assignedEvent: event?.title ?? _selectedEvent ?? 'Unassigned Event',
 assignedGate: _selectedGate,
 passCode: passcode,
 ),
 );
 _nameCtrl.clear();
 _phoneCtrl.clear();
 });

 Navigator.pop(context);
 final docId = await MiloStaffService.instance.addStaff(
 name: name,
 phone: phone,
 eventId: event?.id ?? '',
 eventTitle: event?.title ?? '',
 role: _selectedRole,
 gate: _selectedGate,
 passcode: passcode,
 );
 if (docId != null && mounted) {
 await _loadStaff();
 }
 if (mounted) {
 _showPasscodeIssuedSheet(name, phone, passcode, event?.title ?? _selectedEvent ?? 'your event', _selectedGate);
 }
 },
 child: Text('Issue Gate Access Pass ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.bg)),
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

 void _showPasscodeIssuedSheet(String name, String phone, String passcode, String eventTitle, String gate) {
 showModalBottomSheet(
 context: context,
 backgroundColor: Colors.transparent,
 builder: (context) {
 return Container(
 padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 44,
 height: 5,
 decoration: BoxDecoration(color: MiloColors.textMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3)),
 ),
 const SizedBox(height: 20),
 const Icon(Icons.verified_user_rounded, color: MiloColors.emerald, size: 44),
 const SizedBox(height: 12),
 Text('Gate Pass Issued ', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
 const SizedBox(height: 6),
 Text(
 'Share this passcode with $name. They log in with their mobile number + this code.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.4),
 ),
 const SizedBox(height: 18),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
 ),
 child: Column(
 children: [
 Text('GATE PASSCODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.textMuted, letterSpacing: 1.5)),
 const SizedBox(height: 6),
 Text(passcode, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: MiloColors.primaryLight, letterSpacing: 2)),
 const SizedBox(height: 8),
 Text('Mobile: $phone', style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary)),
 ],
 ),
 ),
 const SizedBox(height: 18),
 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: MiloColors.glassBorder),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 ),
 onPressed: () => _sharePasscode(name, phone, passcode, eventTitle, gate),
 icon: const Icon(Icons.share_rounded, color: MiloColors.primaryLight, size: 18),
 label: Text('Share to Staff', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w800, fontSize: 13)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 ),
 onPressed: () => Navigator.pop(context),
 child: Text('Done', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 },
 );
 }

 void _sharePasscode(String name, String phone, String passcode, String eventTitle, String gate) {
 final message = 'Hi $name, your Milo gate pass is ready! \n\n'
 'Event: $eventTitle\n'
 'Gate: $gate\n'
 'Login mobile: $phone\n'
 'Gate Passcode: $passcode\n\n'
 'Open the Milo app → Login as Gate Staff → enter your mobile number & this passcode to start scanning tickets.';
 Share.share(message, subject: 'Milo Gate Pass — $name');
 }

 Widget _buildModalTextField(TextEditingController ctrl, String hint) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: TextField(
 controller: ctrl,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
 border: InputBorder.none,
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Staff & Gate Access Control ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18),
 ),
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 ),
 floatingActionButton: FloatingActionButton.extended(
 backgroundColor: MiloColors.primary,
 icon: const Icon(Icons.person_add_alt_1_rounded, color: MiloColors.bg),
 label: Text('Assign Staff', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w900)),
 onPressed: _showAddStaffModal,
 ),
 body: ListView(
 padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
 physics: const BouncingScrollPhysics(),
 children: [
 // Anti-Unauthorized Entry Security Banner
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.rose.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.rose.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.security_rounded, color: MiloColors.rose, size: 24),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Strict Role-Based Gate Lockdown ', style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w800, fontSize: 13)),
 const SizedBox(height: 2),
 Text(
 'Unassigned staff or unauthorized persons cannot scan or verify passes. Each staff scanner is locked to their specific assigned Gate / Event.',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),

 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Active Assigned Staff (${_staffList.where((s) => s.isAccessActive).length})', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(color: MiloColors.emerald.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
 child: Text('All Gate Validated', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 10, fontWeight: FontWeight.w800)),
 ),
 ],
 ),
 const SizedBox(height: 14),

 ..._staffList.map((staff) {
 return Container(
 margin: const EdgeInsets.only(bottom: 14),
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
 Row(
 children: [
 CircleAvatar(
 radius: 20,
 backgroundColor: MiloColors.primary.withValues(alpha: 0.2),
 child: const Icon(Icons.badge_rounded, color: MiloColors.primaryLight, size: 22),
 ),
 const SizedBox(width: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(staff.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 Text(staff.phone, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted)),
 ],
 ),
 ],
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: staff.isAccessActive ? MiloColors.emerald.withValues(alpha: 0.15) : MiloColors.rose.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: staff.isAccessActive ? MiloColors.emerald : MiloColors.rose),
 ),
 child: Text(
 staff.isAccessActive ? 'Active' : 'Revoked',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w800,
 color: staff.isAccessActive ? MiloColors.emerald : MiloColors.rose,
 ),
 ),
 ),
 ],
 ),
 const Divider(color: MiloColors.border, height: 20),

 Row(
 children: [
 const Icon(Icons.event_seat_rounded, color: MiloColors.primaryLight, size: 14),
 const SizedBox(width: 6),
 Expanded(
 child: Text('Role: ${staff.role}', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 12)),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Row(
 children: [
 const Icon(Icons.meeting_room_rounded, color: MiloColors.cyan, size: 14),
 const SizedBox(width: 6),
 Expanded(
 child: Text('Gate: ${staff.assignedGate}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11)),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Row(
 children: [
 const Icon(Icons.celebration_rounded, color: MiloColors.amber, size: 14),
 const SizedBox(width: 6),
 Expanded(
 child: Text('Assigned: ${staff.assignedEvent}', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 ),
 ],
 ),
 const SizedBox(height: 12),

 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(color: MiloColors.bgCard, borderRadius: BorderRadius.circular(8)),
 child: Text('Passcode: ${staff.passCode}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
 ),
 Row(
 children: [
 IconButton(
 tooltip: 'Share passcode',
 icon: const Icon(Icons.share_rounded, size: 16, color: MiloColors.primaryLight),
 onPressed: staff.passCode.isEmpty
 ? null
 : () => _sharePasscode(staff.name, staff.phone, staff.passCode, staff.assignedEvent, staff.assignedGate),
 ),
 TextButton.icon(
 icon: const Icon(Icons.block_flipped, size: 14, color: MiloColors.rose),
 label: Text('Revoke', style: GoogleFonts.inter(color: MiloColors.rose, fontSize: 11, fontWeight: FontWeight.w700)),
 onPressed: () {
 setState(() {
 final index = _staffList.indexWhere((s) => s.id == staff.id);
 if (index != -1) {
 _staffList[index] = StaffRoleModel(
 id: staff.id,
 name: staff.name,
 phone: staff.phone,
 role: staff.role,
 assignedEvent: staff.assignedEvent,
 assignedGate: staff.assignedGate,
 isAccessActive: false,
 passCode: staff.passCode,
 );
 }
 });
 MiloStaffService.instance.revokeStaff(staff.id);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Gate Access Revoked for ${staff.name} ', style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w700)),
 ),
 );
 },
 ),
 ],
 ),
 ],
 ),
 ],
 ),
 );
 }),
 ],
 ),
 );
 }
}
