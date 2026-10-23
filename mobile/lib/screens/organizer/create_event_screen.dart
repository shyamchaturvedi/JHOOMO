import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/milo_db_service.dart';
import '../../services/milo_session_service.dart';
import '../../services/mock_data.dart';
import '../../theme/milo_theme.dart';
import '../legal_policy_screen.dart';

class CreateEventScreen extends StatefulWidget {
 const CreateEventScreen({super.key});

 @override
 State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
 final TextEditingController _titleCtrl = TextEditingController();
 final TextEditingController _venueCtrl = TextEditingController();
 final TextEditingController _mapsUrlCtrl = TextEditingController();
 final TextEditingController _descCtrl = TextEditingController();
 final TextEditingController _customTermsCtrl = TextEditingController();

 // Tier addition controllers
 final TextEditingController _tierNameCtrl = TextEditingController();
 final TextEditingController _tierPriceCtrl = TextEditingController();
 final TextEditingController _tierCapacityCtrl = TextEditingController();
 final TextEditingController _tierPerksCtrl = TextEditingController();

 // Coupon controllers
 final TextEditingController _couponCodeCtrl = TextEditingController();
 final TextEditingController _couponDiscountCtrl = TextEditingController();

 String _category = 'Dandiya/Garba';
 String _city = 'Lucknow';
 bool _agreedToOrganizerTerms = false;
 bool _submitting = false;

 // BookMyShow-style custom tiered seating / category tickets
 final List<TicketTier> _customTicketTiers = [
 const TicketTier(
 id: 't_silver',
 name: 'Silver / Ground Pass (Standing)',
 price: 499,
 description: 'Standard access to dance lawn & general stage view.',
 perks: ['Ground Entry', 'Free Dandiya Sticks'],
 available: 150,
 ),
 const TicketTier(
 id: 't_gold',
 name: 'Gold / Front Row (Reserved)',
 price: 999,
 description: 'Priority front row access closer to the main celebrity stage.',
 perks: ['Front Row Access', '2 Beverages', 'Fast-Track Entry'],
 available: 80,
 ),
 const TicketTier(
 id: 't_vip',
 name: 'VIP High Table / Box Seat (5 Pax)',
 price: 2499,
 description: 'Dedicated reserved sofa/high-table seating with food platter service.',
 perks: ['VIP Sofa Seating', 'Dedicated Server', 'Starter Platter', 'VIP Parking'],
 available: 20,
 ),
 ];

 final List<OrganizerCoupon> _organizerCoupons = [];

  // Creator & Affiliate Automation Settings
  bool _enableAffiliateProgram = true;
  bool _autoApproveCreators = true; // Auto-accept all creators so organizer doesn't need to approve repeatedly
  final _affiliateDiscountCtrl = TextEditingController(text: '5'); // Default ₹5 or ₹20 set by host
  final _affiliateCommissionCtrl = TextEditingController(text: '50'); // e.g. ₹50 commission per ticket

 final List<String> _categories = [
 'Dandiya/Garba',
 'College & Squad',
 'Office & Work',
 'Standup Comedy',
 'Kitty/Parties',
 'Yoga & Fit',
 'Open Mic & Music',
 'DJ & Nightlife',
 'Date Spots',
 'Workshop & Social',
 ];

 void _addTicketTier() {
 final name = _tierNameCtrl.text.trim();
 final price = double.tryParse(_tierPriceCtrl.text.trim()) ?? 0.0;
 final capacity = int.tryParse(_tierCapacityCtrl.text.trim()) ?? 50;
 final perksText = _tierPerksCtrl.text.trim();

 if (name.isNotEmpty && price > 0) {
 setState(() {
 _customTicketTiers.add(
 TicketTier(
 id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
 name: name,
 price: price,
 description: 'Custom seat/category defined by host.',
 perks: perksText.isNotEmpty ? perksText.split(',').map((e) => e.trim()).toList() : ['Gate Admission'],
 available: capacity,
 ),
 );
 _tierNameCtrl.clear();
 _tierPriceCtrl.clear();
 _tierCapacityCtrl.clear();
 _tierPerksCtrl.clear();
 });

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(' Seating Category "$name" added at ₹${price.toStringAsFixed(0)}!',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
 ),
 );
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Please enter category name and price!', style: GoogleFonts.inter(color: MiloColors.rose)),
 ),
 );
 }
 }

 void _addCoupon() {
 final code = _couponCodeCtrl.text.trim().toUpperCase();
 final discount = double.tryParse(_couponDiscountCtrl.text.trim()) ?? 0.0;

 if (code.isNotEmpty && discount > 0) {
 setState(() {
 _organizerCoupons.add(
 OrganizerCoupon(
 code: code,
 discountAmount: discount,
 description: 'Host Special: Flat ₹${discount.toStringAsFixed(0)} OFF',
 ),
 );
 _couponCodeCtrl.clear();
 _couponDiscountCtrl.clear();
 });

 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Promo Code $code created successfully! ',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w700)),
 ),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Create & Host Event ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18),
 ),
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.all(20),
 children: [
 // Banner Upload Box
 Container(
 height: 140,
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.add_photo_alternate_outlined, size: 36, color: MiloColors.primaryLight),
 const SizedBox(height: 8),
 Text('Upload Event Poster / Layout Map',
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
 Text('16:9 Aspect Ratio Recommended', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11)),
 ],
 ),
 ),
 ),
 const SizedBox(height: 20),

 // Event Title
 _buildInputLabel('Event Title'),
 _buildTextField(_titleCtrl, 'e.g. Royal Garba Night 2026'),
 const SizedBox(height: 16),

 // Category & City
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildInputLabel('Category'),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _category,
 dropdownColor: MiloColors.bgSurface,
 isExpanded: true,
 items: _categories
 .map((c) => DropdownMenuItem(
 value: c, child: Text(c, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 12))))
 .toList(),
 onChanged: (val) => setState(() => _category = val ?? 'Dandiya/Garba'),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildInputLabel('City'),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _city,
 dropdownColor: MiloColors.bgSurface,
 isExpanded: true,
 items: ['Lucknow', 'Ahmedabad', 'Bangalore', 'Mumbai', 'Delhi', 'Jaipur']
 .map((c) => DropdownMenuItem(
 value: c, child: Text(c, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 12))))
 .toList(),
 onChanged: (val) => setState(() => _city = val ?? 'Lucknow'),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),

 // Venue
 _buildInputLabel('Venue Name & Address'),
 _buildTextField(_venueCtrl, 'e.g. Sanskriti Lawns, Gomti Nagar'),
 const SizedBox(height: 16),

 // Google Maps Location URL
 _buildInputLabel('Google Maps Location Link (URL) '),
 _buildTextField(_mapsUrlCtrl, 'e.g. https://maps.app.goo.gl/xyz123 (Helps attendees navigate easily)'),
 const SizedBox(height: 16),

 // 30-Min Automatic Reminder Banner
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.notifications_active_rounded, color: MiloColors.emerald, size: 22),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Auto 30-Min Pre-Event Alert Active ',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w800, fontSize: 12),
 ),
 const SizedBox(height: 2),
 Text(
 'Milo will automatically send push notifications with live Google Maps route directions to all attendees 30 mins before start time.',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // BOOKMYSHOW-STYLE TIERED SEAT & CATEGORY PRICING BUILDER 
 Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.9),
 borderRadius: BorderRadius.circular(22),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
 boxShadow: [
 BoxShadow(color: MiloColors.primary.withValues(alpha: 0.1), blurRadius: 16),
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
 const Icon(Icons.event_seat_rounded, color: MiloColors.primaryLight, size: 20),
 const SizedBox(width: 8),
 Text(
 'Seat & Tier Pricing (BMS Style)',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 ],
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text('${_customTicketTiers.length} Categories',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 11, fontWeight: FontWeight.w800)),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 'Define different pricing for Silver, Gold, VIP High Tables, or Balcony seats.',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 ),
 const SizedBox(height: 16),

 // Active Ticket Tiers List
 ..._customTicketTiers.map((tier) {
 return Container(
 margin: const EdgeInsets.only(bottom: 10),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.2),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.confirmation_number_outlined, color: MiloColors.primaryLight, size: 16),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(tier.name,
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 maxLines: 1),
 const SizedBox(height: 2),
 Text('${tier.available} passes capacity • ${tier.perks.join(', ')}',
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted), maxLines: 1),
 ],
 ),
 ),
 Text('₹${tier.price.toStringAsFixed(0)}',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
 const SizedBox(width: 6),
 IconButton(
 icon: const Icon(Icons.delete_outline, size: 18, color: MiloColors.rose),
 onPressed: () {
 if (_customTicketTiers.length > 1) {
 setState(() => _customTicketTiers.remove(tier));
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('At least 1 ticket category is required!')),
 );
 }
 },
 ),
 ],
 ),
 );
 }),
 const Divider(color: MiloColors.border, height: 24),

 // Add New Tier Section
 Text('+ Add Another Seat / Ticket Category',
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MiloColors.primaryLight)),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 flex: 3,
 child: _buildTextField(_tierNameCtrl, 'Category (e.g. VIP Balcony)'),
 ),
 const SizedBox(width: 8),
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: _tierPriceCtrl,
 keyboardType: TextInputType.number,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 hintText: 'Price (₹)',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
 border: InputBorder.none,
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: _tierCapacityCtrl,
 keyboardType: TextInputType.number,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 hintText: 'Capacity (e.g. 50)',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
 border: InputBorder.none,
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 flex: 3,
 child: _buildTextField(_tierPerksCtrl, 'Perks (e.g. Front Row, Snack)'),
 ),
 ],
 ),
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 icon: const Icon(Icons.add_rounded, size: 18, color: MiloColors.bg),
 label: Text('Add Category to Event',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.bg, fontSize: 13)),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 ),
 onPressed: _addTicketTier,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // Description
 _buildInputLabel('Event Description & Details'),
 _buildTextField(_descCtrl, 'Describe music, artists, dress codes, perks and highlights...', maxLines: 3),
 const SizedBox(height: 24),

 // Organizer Coupon Creator Section
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.8),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.local_offer_rounded, color: MiloColors.amber, size: 18),
 const SizedBox(width: 8),
 Text(
 'Host Promotional Coupons',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 'You fund and control all discounts for your event. Milo platform does not issue ad-hoc coupons.',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 ),
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.border),
 ),
 child: TextField(
 controller: _couponCodeCtrl,
 textCapitalization: TextCapitalization.characters,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 hintText: 'Code (e.g. VIP50)',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 border: InputBorder.none,
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 flex: 2,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.border),
 ),
 child: TextField(
 controller: _couponDiscountCtrl,
 keyboardType: TextInputType.number,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
 decoration: InputDecoration(
 hintText: 'Disc (₹)',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 border: InputBorder.none,
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: _addCoupon,
 child: Text('Add', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 12)),
 ),
 ],
 ),
 if (_organizerCoupons.isNotEmpty) ...[
 const SizedBox(height: 12),
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: _organizerCoupons.map((c) {
 return Chip(
 backgroundColor: MiloColors.bgCard,
 side: BorderSide(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
 avatar: const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 16),
 label: Text('${c.code} (-₹${c.discountAmount.toStringAsFixed(0)})',
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 11)),
 deleteIcon: const Icon(Icons.close, size: 14, color: MiloColors.rose),
 onDeleted: () => setState(() => _organizerCoupons.remove(c)),
 );
 }).toList(),
 ),
 ],
 ],
 ),
 ),
 const SizedBox(height: 20),

 // Custom Host Rules & Entry Terms
 _buildInputLabel('Organizer Venue Rules & Terms (Optional)'),
 _buildTextField(
 _customTermsCtrl,
 'e.g. Traditional attire mandatory. No outside alcohol permitted. Non-refundable passes.',
 maxLines: 2,
 ),
 const SizedBox(height: 20),

 // Legal Agreement Checkbox
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.6),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Checkbox(
 value: _agreedToOrganizerTerms,
 activeColor: MiloColors.primaryLight,
 checkColor: MiloColors.bg,
 onChanged: (val) => setState(() => _agreedToOrganizerTerms = val ?? false),
 ),
 Expanded(
 child: GestureDetector(
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => const LegalPolicyScreen(
 title: 'Organizer Terms & Agreement',
 policyType: 'organizer_terms',
 ),
 ),
 );
 },
 child: Text.rich(
 TextSpan(
 text: 'I certify that I am the authorized host and agree to the ',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11),
 children: [
 TextSpan(
 text: 'Milo Organizer Terms & Safety Responsibility Policy.',
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
 ),
 ],
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // Publish Button
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 elevation: 6,
 shadowColor: MiloColors.primaryGlow,
 ),
 onPressed: _submitting ? null : _submitEvent,
 child: _submitting
 ? const SizedBox(
 height: 22,
 width: 22,
 child: CircularProgressIndicator(color: MiloColors.bg, strokeWidth: 2.4),
 )
 : Text(
 'Publish Event with Seating Tiers ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.bg, fontSize: 15),
 ),
 ),
 ),
 const SizedBox(height: 30),
 ],
 ),
 );
 }

 Future<void> _submitEvent() async {
 if (_titleCtrl.text.trim().isEmpty || _venueCtrl.text.trim().isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Please fill event title and venue!', style: GoogleFonts.inter(color: MiloColors.rose)),
 ),
 );
 return;
 }

 if (!_agreedToOrganizerTerms) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Please accept the Organizer Terms & Agreement!', style: GoogleFonts.inter(color: MiloColors.amber)),
 ),
 );
 return;
 }

 final minStartingPrice = _customTicketTiers.map((t) => t.price).reduce((a, b) => a < b ? a : b);
 final totalCapacity = _customTicketTiers.map((t) => t.available).reduce((a, b) => a + b);
 final title = _titleCtrl.text.trim();
 final venue = _venueCtrl.text.trim();
 final description = _descCtrl.text.trim().isNotEmpty
 ? _descCtrl.text.trim()
 : 'Exclusive event hosted on Milo platform. Complete seating & category management by organizer.';
 final organizerName =
 MiloSessionService.currentUserName.isNotEmpty ? MiloSessionService.currentUserName : 'Self-Hosted Event';
 final tierMaps = _customTicketTiers
 .map((t) => {
 'id': t.id,
 'tier_name': t.name,
 'price': t.price,
 'description': t.description,
 'perks': t.perks,
 'available_seats': t.available,
 })
 .toList();

 setState(() => _submitting = true);
 String? error;
 try {
 error = await MiloDbService.instance.createEvent(
 title: title,
 description: description,
 category: _category,
 bannerUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80',
 eventDate: 'Sun, 27 Sep 2026',
 eventTime: '07:30 PM onwards',
 venueName: venue,
 city: _city,
 startingPrice: minStartingPrice,
 organizerName: organizerName,
 organizerUid: MiloSessionService.currentUid,
 contactPhone: MiloSessionService.currentUserPhone,
 tags: ['Hosted by You', _category],
 ticketTiers: tierMaps,
 capacity: totalCapacity,
 organizerVerified: false,
 );
 } catch (e) {
 error = e.toString();
 }
 if (!mounted) return;
 setState(() => _submitting = false);

 if (error == null) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(' Event "$title" submitted for admin review — it will go live after approval!',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w800)),
 ),
 );
 return;
 }

 final newEvent = EventModel(
 id: 'org_${DateTime.now().millisecondsSinceEpoch}',
 title: title,
 category: _category,
 date: 'Sun, 27 Sep 2026',
 time: '07:30 PM onwards',
 venue: venue,
 city: _city,
 startingPrice: minStartingPrice,
 imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80',
 organizerName: organizerName,
 isVerifiedOrganizer: true,
 tags: ['Hosted by You', _category],
 ticketsLeft: totalCapacity,
 description: description,
 organizerCoupons: _organizerCoupons,
 customTermsAndConditions: _customTermsCtrl.text.trim(),
 ticketTiers: _customTicketTiers,
 );
 MockData.events.insert(0, newEvent);

 if (!mounted) return;
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Could not reach Milo servers — event saved on this device only. Please retry later.',
 style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w700)),
 ),
 );
 }

 Widget _buildInputLabel(String text) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 );
 }

 Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: controller,
 maxLines: maxLines,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14),
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
 border: InputBorder.none,
 contentPadding: maxLines > 1 ? const EdgeInsets.symmetric(vertical: 12) : null,
 ),
 ),
 );
 }
}
