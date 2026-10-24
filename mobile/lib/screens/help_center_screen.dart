import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

/// S-34 · Help Centre & Support Screen
/// FAQ articles by category, Support ticket creation, and Grievance Officer details per IT Rules / DPDP Act
class HelpCenterScreen extends StatefulWidget {
 const HelpCenterScreen({super.key});

 @override
 State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
 final TextEditingController _searchCtrl = TextEditingController();
 String _selectedCategory = 'All';

 final List<String> _categories = [
 'All',
 'Ticketing & Entry',
 'Refunds & Cancel',
 'Payments & UPI',
 'Safety & SOS',
 'Radar & Privacy',
 ];

 final List<Map<String, String>> _faqs = [
 {
 'cat': 'Ticketing & Entry',
 'q': 'How does the dynamic rotating QR code work at the gate?',
  'a': 'Jhoomo generates a new security token every 30 seconds to prevent screenshots. The gate staff scanner verifies it instantaneously. If you are offline, a signed offline QR code is automatically displayed.',
 },
 {
 'cat': 'Refunds & Cancel',
 'q': 'When will I receive my refund if an event gets cancelled?',
 'a': 'For organizer-cancelled events, a 100% full refund is issued automatically to your original payment source via Razorpay within 5–7 business days.',
 },
 {
 'cat': 'Payments & UPI',
 'q': 'My bank account was debited but the booking is still pending?',
 'a': 'UPI payments usually reconcile within 2–5 minutes. If confirmation fails, the amount is automatically reversed by your bank within 24–48 hours.',
 },
 {
 'cat': 'Safety & SOS',
 'q': 'Who receives my live location when I trigger Instant SOS?',
 'a': 'Your verified Emergency Contacts receive an SMS with a live tracking link, and the event on-ground security desk gets an urgent alert with your location coordinates.',
 },
 {
 'cat': 'Radar & Privacy',
 'q': 'Can other attendees see my mobile number on Meet People Radar?',
 'a': 'No. Jhoomo never reveals your phone number, exact GPS location, email, or full name on Radar. Only your first name, age group, and shared interests are visible.',
 },
 ];

 void _openContactSupportSheet() {
 final msgCtrl = TextEditingController();
 String topic = 'Ticketing Issue';

 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (ctx) => StatefulBuilder(
 builder: (ctx, setSheetState) {
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
 'Raise Support Ticket',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Our support desk resolves critical ticketing and payment issues within 4 hours.',
 style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
 ),
 const SizedBox(height: 18),
 DropdownButtonFormField<String>(
 value: topic,
 dropdownColor: MiloColors.bgSurface,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
 decoration: InputDecoration(
 labelText: 'Category',
 labelStyle: GoogleFonts.inter(color: Colors.white70),
 filled: true,
 fillColor: MiloColors.cardSurface,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 ),
 items: [
 'Ticketing Issue',
 'Payment / UPI Failure',
 'Cancellation / Refund Delay',
 'Safety or Harassment Incident',
 'Account or Login Bug',
 ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
 onChanged: (val) {
 if (val != null) setSheetState(() => topic = val);
 },
 ),
 const SizedBox(height: 14),
 TextField(
 controller: msgCtrl,
 maxLines: 4,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
 decoration: InputDecoration(
 hintText: 'Describe what happened (mention Booking Ref if applicable)...',
 hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
 filled: true,
 fillColor: MiloColors.cardSurface,
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
 ),
 ),
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 height: 48,
 child: ElevatedButton(
 onPressed: () {
 if (msgCtrl.text.trim().isEmpty) return;
 Navigator.pop(ctx);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
              content: Text('Support ticket created (#JHOOMO-TK-8192). We will respond via in-app notification.'),
 backgroundColor: MiloColors.accentGreen,
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
 'Submit Ticket',
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

 @override
 void dispose() {
 _searchCtrl.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final filteredFaqs = _faqs.where((f) {
 final matchesCategory = _selectedCategory == 'All' || f['cat'] == _selectedCategory;
 final query = _searchCtrl.text.trim().toLowerCase();
 final matchesQuery = query.isEmpty ||
 f['q']!.toLowerCase().contains(query) ||
 f['a']!.toLowerCase().contains(query);
 return matchesCategory && matchesQuery;
 }).toList();

 return Scaffold(
 backgroundColor: JhoomoTokens.surface,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back_rounded, color: JhoomoTokens.onSurface),
 onPressed: () => Navigator.pop(context),
 ),
 title: Text(
 'Help Centre & Support',
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 18,
 fontWeight: FontWeight.w800,
 ),
 ),
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 children: [
 // Search box
 Container(
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: JhoomoTokens.outline),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.02),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: TextField(
 controller: _searchCtrl,
 onChanged: (_) => setState(() {}),
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
 decoration: InputDecoration(
 hintText: 'Search FAQ articles, policies, refunds...',
 hintStyle: GoogleFonts.inter(color: JhoomoTokens.textMuted, fontSize: 13),
 prefixIcon: const Icon(Icons.search, color: JhoomoTokens.textSecondary),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 ),
 ),
 ),
 const SizedBox(height: 16),

 // Category Chips
 SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: Row(
 children: _categories.map((c) {
 final isSelected = _selectedCategory == c;
 return Padding(
 padding: const EdgeInsets.only(right: 8),
 child: ChoiceChip(
 label: Text(c),
 selected: isSelected,
 selectedColor: JhoomoTokens.primary.withValues(alpha: 0.12),
 backgroundColor: Colors.white,
 labelStyle: GoogleFonts.inter(
 color: isSelected ? JhoomoTokens.primary : JhoomoTokens.textSecondary,
 fontSize: 12,
 fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
 ),
 side: BorderSide(
 color: isSelected ? JhoomoTokens.primary : JhoomoTokens.outline,
 ),
 onSelected: (val) {
 if (val) setState(() => _selectedCategory = c);
 },
 ),
 );
 }).toList(),
 ),
 ),
 const SizedBox(height: 20),

 // Raise ticket banner
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: JhoomoTokens.primary.withValues(alpha: 0.2)),
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.05),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Row(
 children: [
 Container(
 width: 44,
 height: 44,
 decoration: BoxDecoration(
 color: JhoomoTokens.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Icon(Icons.support_agent_rounded, color: JhoomoTokens.primary, size: 26),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Need custom assistance?',
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 15,
 fontWeight: FontWeight.w800,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 'Speak with our live support team or open a ticket.',
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 12),
 ),
 ],
 ),
 ),
 ElevatedButton(
 onPressed: _openContactSupportSheet,
 style: ElevatedButton.styleFrom(
 backgroundColor: JhoomoTokens.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 elevation: 0,
 ),
 child: Text(
 'Ticket',
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // FAQ Expansion Panels
 Text(
 'FREQUENTLY ASKED QUESTIONS',
 style: GoogleFonts.inter(
 color: JhoomoTokens.textSecondary,
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.1,
 ),
 ),
 const SizedBox(height: 12),
 ...filteredFaqs.map((faq) {
 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: JhoomoTokens.outline),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.02),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: ExpansionTile(
 iconColor: JhoomoTokens.primary,
 collapsedIconColor: JhoomoTokens.textMuted,
 title: Text(
 faq['q']!,
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 14,
 fontWeight: FontWeight.w700,
 ),
 ),
 children: [
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
 child: Text(
 faq['a']!,
 style: GoogleFonts.inter(
 color: JhoomoTokens.textSecondary,
 fontSize: 13,
 height: 1.45,
 ),
 ),
 ),
 ],
 ),
 );
 }),
 const SizedBox(height: 24),

 // Grievance Officer details per IT Rules 2021 & DPDP Act 2023
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: JhoomoTokens.outline),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'STATUTORY GRIEVANCE OFFICER (INDIA)',
 style: GoogleFonts.inter(
 color: JhoomoTokens.textSecondary,
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.1,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Name: Grievance Officer, Jhoomo Live Platforms Pvt Ltd\nAddress: Mumbai, Maharashtra, India\nEmail: grievance@jhoomo.live\nSLA: Acknowledgment within 24h, resolution within 15 days.',
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 12, height: 1.4),
 ),
 ],
 ),
 ),
 const SizedBox(height: 36),
 ],
 ),
 );
 }
}
