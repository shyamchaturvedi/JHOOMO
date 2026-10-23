import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/milo_db_service.dart';
import '../services/mock_data.dart';
import '../services/payment_approval_service.dart';
import '../models/models.dart';
import '../theme/milo_theme.dart';
import 'event_details_screen.dart';
import 'my_tickets_screen.dart';
import 'your_bookings_screen.dart';
import 'dandiya_special_screen.dart';
import 'notifications_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/bms_pick_region_sheet.dart';

class HomeScreen extends StatefulWidget {
 final Function(int)? onNavigateTab;
 final VoidCallback? onOpenMenu;

 const HomeScreen({super.key, this.onNavigateTab, this.onOpenMenu});

 @override
 State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
 String _selectedCity = 'Lucknow';
 String _selectedCategory = 'All';
 int _heroCurrentIndex = 0;
 late final PageController _heroPageController;
 Timer? _heroTimer;
 List<EventModel> _liveEvents = [];

 final List<Map<String, dynamic>> _quickActionShortcuts = [
 {
 'label': 'Events',
 'sub': 'Book Tickets',
 'icon': Icons.confirmation_number_rounded,
 'bg': Color(0xFFFFEEF2),
 'fg': JhoomoTokens.primary,
 'tab': 1,
 },
 {
 'label': 'Community',
 'sub': 'Event Posts',
 'icon': Icons.hub_rounded,
 'bg': Color(0xFFE0F2FE),
 'fg': Color(0xFF0284C7),
 'tab': 2,
 },
 {
 'label': 'My Events',
 'sub': 'Your Bookings',
 'icon': Icons.calendar_today_rounded,
 'bg': Color(0xFFFCE7F3),
 'fg': Color(0xFFDB2777),
 'action': 'tickets',
 },
 
 ];

 @override
 void initState() {
 super.initState();
 _heroPageController = PageController(viewportFraction: 0.88, initialPage: 1000);
 _loadLiveData();
 _heroTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
 if (_heroPageController.hasClients && _liveEvents.isNotEmpty) {
 final current = _heroPageController.page?.round() ?? 1000;
 _heroPageController.animateToPage(
 current + 1,
 duration: const Duration(milliseconds: 600),
 curve: Curves.easeOutCubic,
 );
 }
 });
 }

 @override
 void dispose() {
 _heroTimer?.cancel();
 _heroPageController.dispose();
 super.dispose();
 }

 Future<void> _loadLiveData() async {
 try {
 final events = await MiloDbService.instance.getEvents();
 if (mounted && events.isNotEmpty) {
 setState(() {
 _liveEvents = events;
 });
 } else if (mounted) {
 setState(() {
 _liveEvents = MockData.events;
 });
 }
 } catch (e) {
 if (mounted) {
 setState(() {
 _liveEvents = MockData.events;
 });
 }
 }
 }

 Future<void> _refresh() async {
 await _loadLiveData();
 }

 void _showCityPicker() async {
 final result = await BMSPickRegionSheet.show(context, currentCity: _selectedCity);
 if (result != null && result.isNotEmpty && mounted) {
 setState(() => _selectedCity = result);
 }
 }

 @override
 Widget build(BuildContext context) {
 final sourceEvents = _liveEvents.isNotEmpty ? _liveEvents : MockData.events;
 final cityEvents = sourceEvents.where((e) {
 return e.city.toLowerCase() == _selectedCity.toLowerCase();
 }).toList();

 final allEvents = cityEvents.isNotEmpty ? cityEvents : sourceEvents;
 final heroList = allEvents.take(4).toList();

 return Scaffold(
 backgroundColor: JhoomoTokens.surface,
 body: SafeArea(
 bottom: false,
 child: RefreshIndicator(
 onRefresh: _refresh,
 color: JhoomoTokens.primary,
 backgroundColor: Colors.white,
 child: CustomScrollView(
 physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
 slivers: [
            // Header: BMS-Style Location Bar & Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left side: BMS Location Selector (Pin + City + Dropdown Chevron)
                    InkWell(
                      onTap: _showCityPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF1F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                size: 18,
                                color: JhoomoTokens.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCity,
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right side: Search & Notification Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF334155),
                              size: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Color(0xFF334155),
                                  size: 19,
                                ),
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: JhoomoTokens.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    "3",
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

 // Featured Immersive Hero Banner (e.g. Dandiya Night) 
 if (heroList.isNotEmpty)
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
 child: Column(
 children: [
 SizedBox(
 height: 190,
 child: PageView.builder(
 controller: _heroPageController,
 onPageChanged: (idx) => setState(() => _heroCurrentIndex = idx % heroList.length),
 itemBuilder: (context, index) {
 final event = heroList[index % heroList.length];
 return GestureDetector(
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
 );
 },
 child: Container(
 margin: const EdgeInsets.symmetric(horizontal: 7),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(22),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.15),
 blurRadius: 20,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(22),
 child: Stack(
 fit: StackFit.expand,
 children: [
 Image.network(
 event.imageUrl,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Container(color: JhoomoTokens.secondary),
 ),
 Container(
 decoration: const BoxDecoration(
 gradient: LinearGradient(
 colors: [
 Color(0xB30F172A),
 Color(0x330F172A),
 Color(0xCC0F172A),
 ],
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 event.title,
 style: GoogleFonts.dancingScript(
 fontSize: 26,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 4),
 Row(
 children: [
                                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${event.venue}, ${event.city}',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 13),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    event.date,
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
 ElevatedButton(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
 );
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: JhoomoTokens.primary,
 foregroundColor: Colors.white,
 elevation: 0,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 'Book Now',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
 ),
 const SizedBox(width: 4),
 const Icon(Icons.arrow_forward_rounded, size: 14),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 ),
 ),
 const SizedBox(height: 10),
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: List.generate(heroList.length, (dotIdx) {
 final isSelected = (_heroCurrentIndex % heroList.length) == dotIdx;
 return AnimatedContainer(
 duration: const Duration(milliseconds: 300),
 margin: const EdgeInsets.symmetric(horizontal: 3),
 width: isSelected ? 18 : 6,
 height: 5,
 decoration: BoxDecoration(
 color: isSelected ? JhoomoTokens.primary : const Color(0xFFCBD5E1),
 borderRadius: BorderRadius.circular(4),
 ),
 );
 }),
 ),
 ],
 ),
 ),
 ),

 // 4 Quick Action Category Tiles (Events, Meet People, My Events, VIP) 
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: _quickActionShortcuts.map((item) {
 return Expanded(
 child: GestureDetector(
 onTap: () {
 if (item['action'] == 'tickets') {
 Navigator.push(context, MaterialPageRoute(builder: (_) => const YourBookingsScreen()));
 } else if (item['tab'] != null && widget.onNavigateTab != null) {
 widget.onNavigateTab!(item['tab'] as int);
 }
 },
 child: Container(
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding: const EdgeInsets.symmetric(vertical: 14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: JhoomoTokens.outlineVariant),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.03),
 blurRadius: 10,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 42,
 height: 42,
 decoration: BoxDecoration(
 color: item['bg'] as Color,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Icon(item['icon'] as IconData, color: item['fg'] as Color, size: 22),
 ),
 const SizedBox(height: 8),
 Text(
 item['label'] as String,
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: JhoomoTokens.onSurface,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 item['sub'] as String,
 style: GoogleFonts.inter(
 fontSize: 10,
 color: JhoomoTokens.textMuted,
 fontWeight: FontWeight.w500,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }).toList(),
 ),
 ),
 ),

 // Popular Events Rail Header 
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Popular Events',
 style: GoogleFonts.inter(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.onSurface,
 letterSpacing: -0.3,
 ),
 ),
 GestureDetector(
 onTap: () {
 if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
 },
 child: Text(
 'See All >',
 style: GoogleFonts.inter(
 color: JhoomoTokens.primary,
 fontSize: 13,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 ),
 ),
 ),

 // Popular Events Dual Horizontal Cards 
 SliverToBoxAdapter(
 child: SizedBox(
 height: 250,
 child: ListView.builder(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 scrollDirection: Axis.horizontal,
 physics: const BouncingScrollPhysics(),
 itemCount: allEvents.length,
 itemBuilder: (context, index) {
 final event = allEvents[index];
 return Container(
 width: 175,
 margin: const EdgeInsets.symmetric(horizontal: 5),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: JhoomoTokens.outline),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.04),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Stack(
 children: [
 ClipRRect(
 borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
 child: Image.network(
 event.imageUrl,
 height: 105,
 width: double.infinity,
 fit: BoxFit.cover,
 ),
 ),
 Positioned(
 top: 8,
 left: 8,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: event.isTrending ? JhoomoTokens.primary : JhoomoTokens.greenVerified,
 borderRadius: BorderRadius.circular(20),
 ),
 child: Text(
 event.isTrending ? 'Trending' : 'Live Now',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 9,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ),
 ],
 ),
 Padding(
 padding: const EdgeInsets.all(10),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 event.title,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: JhoomoTokens.onSurface,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 3),
 Row(
 children: [
 const Icon(Icons.location_on_outlined, size: 12, color: JhoomoTokens.textSecondary),
 const SizedBox(width: 2),
 Expanded(
 child: Text(
 '${event.venue}, ${event.city}',
 style: GoogleFonts.inter(fontSize: 10, color: JhoomoTokens.textSecondary),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 const SizedBox(height: 2),
 Text(
 '${event.date.split(',')[0]} • 7:00 PM',
 style: GoogleFonts.inter(fontSize: 10, color: JhoomoTokens.textSecondary),
 ),
 const SizedBox(height: 6),
 Row(
 children: [
 const Icon(Icons.people_alt_rounded, size: 12, color: JhoomoTokens.primary),
 const SizedBox(width: 4),
 Text(
 '+${(event.startingPrice * 0.4).toInt() + 120} going',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w600,
 color: JhoomoTokens.primary,
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 '₹${event.startingPrice.toStringAsFixed(0)} onwards',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.onSurface,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 },
 ),
 ),
 ),

 // Upcoming Events Vertical Section Header 
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Upcoming Events',
 style: GoogleFonts.inter(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.onSurface,
 letterSpacing: -0.3,
 ),
 ),
 GestureDetector(
 onTap: () {
 if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
 },
 child: Text(
 'See All >',
 style: GoogleFonts.inter(
 color: JhoomoTokens.primary,
 fontSize: 13,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 ),
 ),
 ),

 // Upcoming Events Horizontal Strip List (As seen in UI Mockup) 
 SliverPadding(
 padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
 sliver: SliverList(
 delegate: SliverChildBuilderDelegate(
 (context, index) {
 final event = allEvents[index];
 return GestureDetector(
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
 );
 },
 child: Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: JhoomoTokens.outline),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.03),
 blurRadius: 10,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: Row(
 children: [
 ClipRRect(
 borderRadius: BorderRadius.circular(12),
 child: Image.network(
 event.imageUrl,
 width: 72,
 height: 72,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: JhoomoTokens.secondary),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 event.title,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: JhoomoTokens.onSurface,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 4),
 Text(
 event.venue,
 style: GoogleFonts.inter(
 fontSize: 11,
 color: JhoomoTokens.textSecondary,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 4),
 Text(
 '${event.date.split(',')[0]} • 7:30 PM',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: JhoomoTokens.textMuted,
 ),
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: JhoomoTokens.tertiaryContainer,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(
 '₹${event.startingPrice.toStringAsFixed(0)}',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w800,
 color: JhoomoTokens.primary,
 ),
 ),
 ),
 ],
 ),
 ),
 );
 },
 childCount: allEvents.length,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }
}