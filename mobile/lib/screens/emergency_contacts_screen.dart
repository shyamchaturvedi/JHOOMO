import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

/// S-30 · Emergency Contacts Screen
/// Manage up to 3 contacts (name, phone, relationship)
/// Status chip: Pending / Confirmed / Declined
/// Only Confirmed contacts receive instant SMS & live tracking links during SOS
class EmergencyContactsScreen extends StatefulWidget {
 const EmergencyContactsScreen({super.key});

 @override
 State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
 final List<Map<String, String>> _contacts = [
 {
 'id': 'ec_01',
 'name': 'Anita Sharma',
 'relationship': 'Mother',
 'phone': '+91 98765 43210',
 'status': 'Confirmed',
 },
 {
 'id': 'ec_02',
 'name': 'Rahul Verma',
 'relationship': 'Friend',
 'phone': '+91 98111 22334',
 'status': 'Pending',
 },
 ];

 void _showAddContactDialog() {
 if (_contacts.length >= 3) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Maximum 3 emergency contacts allowed as per Milo Safety Shield policy.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 return;
 }

 final nameCtrl = TextEditingController();
 final phoneCtrl = TextEditingController();
 String relationship = 'Family';

 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setModalState) {
 return Container(
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 padding: EdgeInsets.only(
 top: 20,
 left: 20,
 right: 20,
 bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
 color: Colors.white24,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'Add Emergency Contact',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'A DLT-registered SMS will be sent asking them to confirm receipt of SOS alerts.',
 style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
 ),
 const SizedBox(height: 18),
 TextField(
 controller: nameCtrl,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
 decoration: InputDecoration(
 labelText: 'Contact Name',
 labelStyle: GoogleFonts.inter(color: Colors.white70),
 filled: true,
 fillColor: MiloColors.cardSurface,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(height: 14),
 TextField(
 controller: phoneCtrl,
 keyboardType: TextInputType.phone,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
 decoration: InputDecoration(
 labelText: 'Mobile Number (+91)',
 labelStyle: GoogleFonts.inter(color: Colors.white70),
 filled: true,
 fillColor: MiloColors.cardSurface,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(height: 14),
 DropdownButtonFormField<String>(
 value: relationship,
 dropdownColor: MiloColors.bgSurface,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
 decoration: InputDecoration(
 labelText: 'Relationship',
 labelStyle: GoogleFonts.inter(color: Colors.white70),
 filled: true,
 fillColor: MiloColors.cardSurface,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 ),
 items: ['Family', 'Friend', 'Colleague', 'Partner', 'Other']
 .map((r) => DropdownMenuItem(value: r, child: Text(r)))
 .toList(),
 onChanged: (val) {
 if (val != null) setModalState(() => relationship = val);
 },
 ),
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 height: 48,
 child: ElevatedButton(
 onPressed: () {
 if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().length < 10) {
 return;
 }
 setState(() {
 _contacts.add({
 'id': 'ec_${DateTime.now().millisecondsSinceEpoch}',
 'name': nameCtrl.text.trim(),
 'relationship': relationship,
 'phone': phoneCtrl.text.trim(),
 'status': 'Pending',
 });
 });
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Verification SMS dispatched to contact.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 elevation: 0,
 ),
 child: Text(
 'Send Verification SMS',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
 ),
 ),
 ),
 ],
 ),
 );
 },
 ),
 );
 }

 void _removeContact(int index) {
 setState(() => _contacts.removeAt(index));
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Emergency contact removed'), behavior: SnackBarBehavior.floating),
 );
 }

 void _sendTestAlert() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Test alert sent to confirmed emergency contacts.'),
 backgroundColor: MiloColors.accentGreen,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bgSurface,
 appBar: AppBar(
 backgroundColor: MiloColors.bgSurface,
 elevation: 0,
 title: Text(
 'Emergency Contacts',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 body: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 children: [
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.cardSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 const Icon(Icons.shield_outlined, color: MiloColors.accentGreen, size: 28),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'SOS Armed Status',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 _contacts.any((c) => c['status'] == 'Confirmed')
 ? 'Armed (Confirmed contacts will receive immediate tracking)'
 : 'Unarmed (Need at least 1 Confirmed contact)',
 style: GoogleFonts.inter(
 color: _contacts.any((c) => c['status'] == 'Confirmed')
 ? MiloColors.accentGreen
 : Colors.amber,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'YOUR CONTACTS (${_contacts.length}/3)',
 style: GoogleFonts.inter(
 color: Colors.white38,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 ),
 ),
 if (_contacts.length < 3)
 TextButton.icon(
 onPressed: _showAddContactDialog,
 icon: const Icon(Icons.add, size: 16, color: MiloColors.primary),
 label: Text(
 'Add New',
 style: GoogleFonts.inter(
 color: MiloColors.primary,
 fontSize: 13,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),
 if (_contacts.isEmpty)
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 40),
 child: Center(
 child: Text(
 'No emergency contacts added yet.',
 style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
 ),
 ),
 )
 else
 ..._contacts.asMap().entries.map((entry) {
 final idx = entry.key;
 final c = entry.value;
 final isConfirmed = c['status'] == 'Confirmed';

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.cardSurface,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 CircleAvatar(
 radius: 20,
 backgroundColor: Colors.white12,
 child: Text(
 c['name']![0],
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 c['name']!,
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(width: 6),
 Text(
 '(${c['relationship']})',
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
 ),
 ],
 ),
 const SizedBox(height: 2),
 Text(
 c['phone']!,
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: isConfirmed
 ? MiloColors.accentGreen.withValues(alpha: 0.15)
 : Colors.amber.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 c['status']!,
 style: GoogleFonts.inter(
 color: isConfirmed ? MiloColors.accentGreen : Colors.amber,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 IconButton(
 icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
 onPressed: () => _removeContact(idx),
 ),
 ],
 ),
 );
 }),
 const SizedBox(height: 24),
 if (_contacts.any((c) => c['status'] == 'Confirmed'))
 SizedBox(
 width: double.infinity,
 height: 48,
 child: OutlinedButton.icon(
 onPressed: _sendTestAlert,
 icon: const Icon(Icons.send_rounded, size: 18),
 label: const Text('Send Test Alert to Confirmed Contacts'),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white70,
 side: const BorderSide(color: Colors.white24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 ),
 ],
 ),
 );
 }
}
