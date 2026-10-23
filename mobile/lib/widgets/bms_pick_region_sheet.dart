import '../services/milo_location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BMSPickRegionSheet extends StatefulWidget {
 final String currentCity;
 final ValueChanged<String> onCitySelected;

 const BMSPickRegionSheet({
 super.key,
 required this.currentCity,
 required this.onCitySelected,
 });

 static Future<String?> show(BuildContext context, {String currentCity = 'Lucknow'}) {
 return showModalBottomSheet<String>(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (ctx) => BMSPickRegionSheet(
 currentCity: currentCity,
 onCitySelected: (city) => Navigator.of(ctx).pop(city),
 ),
 );
 }

 @override
 State<BMSPickRegionSheet> createState() => _BMSPickRegionSheetState();
}

class _BMSPickRegionSheetState extends State<BMSPickRegionSheet> {
 final TextEditingController _searchCtrl = TextEditingController();
 String _filter = '';

 final List<Map<String, String>> _popularCities = [
 {'name': 'Lucknow', 'badge': 'UP', 'icon': ''},
 {'name': 'Mumbai', 'badge': 'Popular', 'icon': ''},
 {'name': 'Delhi-NCR', 'badge': 'Popular', 'icon': ''},
 {'name': 'Bengaluru', 'badge': 'Tech', 'icon': ''},
 {'name': 'Hyderabad', 'badge': 'Popular', 'icon': ''},
 {'name': 'Ahmedabad', 'badge': 'Garba Hub', 'icon': ''},
 {'name': 'Pune', 'badge': 'Culture', 'icon': ''},
 {'name': 'Kolkata', 'badge': 'Festival', 'icon': ''},
 {'name': 'Jaipur', 'badge': 'Heritage', 'icon': ''},
 {'name': 'Chandigarh', 'badge': 'City', 'icon': ''},
 ];

 final List<String> _allCities = [
 'Agra', 'Ahmedabad', 'Ajmer', 'Aligarh', 'Amritsar', 'Ayodhya',
 'Bareilly', 'Bengaluru', 'Bhopal', 'Bhubaneswar', 'Chandigarh',
 'Chennai', 'Coimbatore', 'Dehradun', 'Delhi-NCR', 'Goa',
 'Gorakhpur', 'Gwalior', 'Hyderabad', 'Indore', 'Jabalpur',
 'Jaipur', 'Jalandhar', 'Jammu', 'Jodhpur', 'Kanpur', 'Kochi',
 'Kolkata', 'Kota', 'Lucknow', 'Ludhiana', 'Madurai', 'Mangaluru',
 'Meerut', 'Mumbai', 'Nagpur', 'Nashik', 'Noida', 'Patna', 'Prayagraj',
 'Pune', 'Raipur', 'Ranchi', 'Surat', 'Udaipur', 'Vadodara', 'Varanasi',
 ];

 void _showLocationDisclosureModal() {
 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (ctx) {
 return Container(
 padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
 decoration: const BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Top drag notch
 Container(
 width: 44,
 height: 4,
 decoration: BoxDecoration(
 color: const Color(0xFFE5E7EB),
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 const SizedBox(height: 12),
 Align(
 alignment: Alignment.topRight,
 child: IconButton(
 visualDensity: VisualDensity.compact,
 icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
 onPressed: () => Navigator.pop(ctx),
 ),
 ),

 // BMS Cartoon / Searcher illustration
 Container(
 width: 140,
 height: 110,
 decoration: BoxDecoration(
 color: const Color(0xFFFFF1F2),
 borderRadius: BorderRadius.circular(20),
 ),
 child: Stack(
 alignment: Alignment.center,
 children: [
 const Icon(Icons.map_outlined, size: 70, color: Color(0xFFFDA4AF)),
 Positioned(
 top: 18,
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(
 color: Color(0xFFE11D48),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.location_on, color: Colors.white, size: 24),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),

 Text(
 'Hey there! Where are you?',
 style: GoogleFonts.inter(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF111827),
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'Don’t miss out on Dandiya, DJ Nights, Activities & a lot more happening near you!',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 13,
 color: const Color(0xFF6B7280),
 height: 1.4,
 ),
 ),
 const SizedBox(height: 18),

 // Legal / Consent explanation box (Exact BMS text structure)
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: const Color(0xFFF3F4F6)),
 ),
 child: Text(
 'Milo collects your location data to recommend shows and events near you, send real-time alerts and venue notifications, and curate your feed for your area. Location is collected only while using the app.\nYou can turn location off anytime in Settings.',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: const Color(0xFF4B5563),
 height: 1.45,
 ),
 ),
 ),
 const SizedBox(height: 24),

 // Detect My Location Button
 SizedBox(
 width: double.infinity,
 height: 50,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFE11D48), // BMS Crimson
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14),
 ),
 ),
                     onPressed: () async {
                      Navigator.pop(ctx);
                      final detected = await MiloLocationService.instance.detectCurrentCity();
                      if (detected != null && detected.isNotEmpty) {
                        widget.onCitySelected(detected);
                      } else {
                        widget.onCitySelected('Lucknow');
                      }
                    },
 child: Text(
 'Detect My Location',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ),
 const SizedBox(height: 10),

 // Select Manually
 SizedBox(
 width: double.infinity,
 height: 48,
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFE11D48)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14),
 ),
 ),
 onPressed: () => Navigator.pop(ctx),
 child: Text(
 'Select Manually',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: const Color(0xFFE11D48),
 ),
 ),
 ),
 ),
 ],
 ),
 );
 },
 );
 }

 @override
 Widget build(BuildContext context) {
 final filtered = _allCities
 .where((c) => c.toLowerCase().contains(_filter.toLowerCase()))
 .toList();

 return Container(
 height: MediaQuery.of(context).size.height * 0.88,
 decoration: const BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
 ),
 child: Column(
 children: [
 // Header Bar
 Padding(
 padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
 child: Row(
 children: [
 IconButton(
 icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
 onPressed: () => Navigator.pop(context),
 ),
 Text(
 'Pick a Region',
 style: GoogleFonts.inter(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF111827),
 ),
 ),
 ],
 ),
 ),

 // Search Field
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 20),
 child: Container(
 height: 48,
 decoration: BoxDecoration(
 color: const Color(0xFFF3F4F6),
 borderRadius: BorderRadius.circular(12),
 ),
 padding: const EdgeInsets.symmetric(horizontal: 14),
 child: Row(
 children: [
 const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: TextField(
 controller: _searchCtrl,
 onChanged: (val) => setState(() => _filter = val),
 style: GoogleFonts.inter(
 fontSize: 14,
 color: const Color(0xFF1F2937),
 fontWeight: FontWeight.w500,
 ),
 decoration: InputDecoration(
 hintText: 'Search for your city',
 hintStyle: GoogleFonts.inter(
 fontSize: 14,
 color: const Color(0xFF9CA3AF),
 ),
 border: InputBorder.none,
 ),
 ),
 ),
 if (_filter.isNotEmpty)
 GestureDetector(
 onTap: () {
 _searchCtrl.clear();
 setState(() => _filter = '');
 },
 child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 18),
 ),
 ],
 ),
 ),
 ),

 // Auto Detect Button
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
 child: InkWell(
 onTap: _showLocationDisclosureModal,
 borderRadius: BorderRadius.circular(10),
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 8),
 child: Row(
 children: [
 const Icon(Icons.my_location_rounded,
 color: Color(0xFFE11D48), size: 20),
 const SizedBox(width: 12),
 Text(
 'Auto Detect My Location',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: const Color(0xFFE11D48),
 ),
 ),
 ],
 ),
 ),
 ),
 ),

 const Divider(color: Color(0xFFF3F4F6), thickness: 1, height: 16),

 // Cities Content
 Expanded(
 child: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 20),
 children: [
 if (_filter.isEmpty) ...[
 Text(
 'POPULAR CITIES',
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.2,
 color: const Color(0xFF9CA3AF),
 ),
 ),
 const SizedBox(height: 14),
 Wrap(
 spacing: 12,
 runSpacing: 14,
 children: _popularCities.map((c) {
 final isSelected = c['name'] == widget.currentCity;
 return InkWell(
 onTap: () => widget.onCitySelected(c['name']!),
 borderRadius: BorderRadius.circular(16),
 child: Container(
 width: (MediaQuery.of(context).size.width - 64) / 3,
 padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
 decoration: BoxDecoration(
 color: isSelected
 ? const Color(0xFFFFF1F2)
 : const Color(0xFFF9FAFB),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isSelected
 ? const Color(0xFFE11D48)
 : const Color(0xFFE5E7EB),
 width: isSelected ? 1.5 : 1,
 ),
 ),
 child: Column(
 children: [
 Text(c['icon']!, style: const TextStyle(fontSize: 24)),
 const SizedBox(height: 6),
 Text(
 c['name']!,
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: isSelected
 ? const Color(0xFFE11D48)
 : const Color(0xFF1F2937),
 ),
 ),
 ],
 ),
 ),
 );
 }).toList(),
 ),
 const SizedBox(height: 24),
 Text(
 'ALL CITIES',
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.2,
 color: const Color(0xFF9CA3AF),
 ),
 ),
 const SizedBox(height: 8),
 ],

 // Alphabetical List
 ...filtered.map((city) {
 final isSelected = city == widget.currentCity;
 return InkWell(
 onTap: () => widget.onCitySelected(city),
 child: Container(
 padding: const EdgeInsets.symmetric(vertical: 14),
 decoration: const BoxDecoration(
 border: Border(
 bottom: BorderSide(color: Color(0xFFF3F4F6)),
 ),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 city,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
 color: isSelected
 ? const Color(0xFFE11D48)
 : const Color(0xFF374151),
 ),
 ),
 if (isSelected)
 const Icon(Icons.check, color: Color(0xFFE11D48), size: 18),
 ],
 ),
 ),
 );
 }),
 const SizedBox(height: 40),
 ],
 ),
 ),
 ],
 ),
 );
 }
}
