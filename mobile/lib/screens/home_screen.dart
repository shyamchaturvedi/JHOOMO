import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/milo_db_service.dart';
import '../services/mock_data.dart';
import '../models/models.dart';
import '../theme/milo_theme.dart';
import 'event_details_screen.dart';
import 'my_tickets_screen.dart';
import 'dandiya_special_screen.dart';
import 'create_beacon_screen.dart';
import 'notifications_screen.dart';
import 'chat/chat_conversation_screen.dart';
import '../widgets/app_logo.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

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
  List<BeaconModel> _liveBeacons = [];

  final List<String> _cities = ['Lucknow', 'Ahmedabad', 'Bangalore', 'Mumbai', 'Delhi', 'Jaipur'];
  final List<String> _categories = [
    'All',
    '🎓 College & Squad',
    '💻 Office & Work',
    '🎤 Standup Comedy',
    '💅 Kitty & Brunch',
    '🧘 Yoga & Fit',
    '🪘 Dandiya & Garba',
    '🎸 Live Music',
    '💑 Date Spots',
  ];

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController(viewportFraction: 0.92);
    _loadLiveData();
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_heroPageController.hasClients && _liveEvents.isNotEmpty) {
        final next = (_heroCurrentIndex + 1) % _liveEvents.take(4).length;
        _heroPageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _loadLiveData() async {
    final events = await MiloDbService.instance.getEvents();
    final beacons = await MiloDbService.instance.getActiveBeacons();
    if (mounted) {
      setState(() {
        _liveEvents = events;
        _liveBeacons = beacons;
      });
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                      decoration: BoxDecoration(
                        color: MiloColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Your City 📍',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MiloColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MiloColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '6 Cities Active',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.primaryLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._cities.map((city) {
                    final isSelected = _selectedCity == city;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? MiloColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected ? Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)) : null,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: Icon(
                          Icons.location_on_rounded,
                          color: isSelected ? MiloColors.primaryLight : MiloColors.textMuted,
                        ),
                        title: Text(
                          city,
                          style: GoogleFonts.inter(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? MiloColors.primaryLight : MiloColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: MiloColors.primaryLight)
                            : null,
                        onTap: () {
                          setState(() => _selectedCity = city);
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

  @override
  Widget build(BuildContext context) {
    final heroList = _liveEvents.isNotEmpty ? _liveEvents.take(4).toList() : MockData.events.take(4).toList();
    final allEvents = _liveEvents.isNotEmpty ? _liveEvents : MockData.events;
    final trendingEvents = allEvents.where((e) {
      if (_selectedCategory == 'All') return true;
      final cleanCat = _selectedCategory.replaceAll(RegExp(r'[^\w\s/&]'), '').trim();
      return e.category.toLowerCase().contains(cleanCat.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: MiloColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top Bar with Milo App Logo, Live City & Quick Actions ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MiloAppLogo(size: 34, showText: true, showTagline: false),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _showCityPicker,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me_rounded, color: MiloColors.primaryLight, size: 13),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '$_selectedCity, India',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: MiloColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: MiloColors.primaryLight, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderIconButton(
                          icon: Icons.confirmation_number_outlined,
                          badge: '2',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderIconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Live Vibe / Active Radar Story Rings ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: 98,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: MockData.discoveryProfiles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateBeaconScreen()),
                          );
                        },
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: MiloGradients.primaryBrand,
                                  boxShadow: [
                                    BoxShadow(
                                      color: MiloColors.primaryGlow,
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.add_rounded, color: MiloColors.bg, size: 30),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'My Vibe',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: MiloColors.primaryLight,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final profile = MockData.discoveryProfiles[index - 1];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatConversationScreen(userName: profile.name),
                          ),
                        );
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [MiloColors.cyan, MiloColors.primary, MiloColors.emerald],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: MiloColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: MiloColors.bgSurface,
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(profile.avatarUrl),
                                  ),
                                ),
                                if (profile.isOnline)
                                  Positioned(
                                    bottom: 0,
                                    right: 2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: MiloColors.emerald,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: MiloColors.bg, width: 2.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile.name.split(' ')[0],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MiloColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Featured Hero 3D Carousel ──
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: _heroPageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (idx) => setState(() => _heroCurrentIndex = idx),
                      itemCount: heroList.length,
                      itemBuilder: (context, index) {
                        final event = heroList[index];
                        return GestureDetector(
                          onTap: () {
                            if (index == 0) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DandiyaSpecialScreen()),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: MiloColors.primaryLight.withValues(alpha: 0.6),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: MiloColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(27),
                              child: Stack(
                                children: [
                                  // Background Image
                                  Image.network(
                                    event.imageUrl,
                                    height: double.infinity,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  // Gradient Overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          MiloColors.bg.withValues(alpha: 0.5),
                                          MiloColors.bg.withValues(alpha: 0.95),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [0.2, 0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                  // Badges on Top
                                  Positioned(
                                    top: 14,
                                    left: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: MiloColors.bgSurface.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: MiloColors.primaryLight),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, color: MiloColors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            index == 0 ? 'GARBA FEST 2026 ✨' : 'FEATURED',
                                            style: GoogleFonts.inter(
                                              color: MiloColors.primaryLight,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: MiloColors.rose.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '⚡ ${event.ticketsLeft} Passes Left',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Event Details Bottom
                                  Positioned(
                                    bottom: 14,
                                    left: 16,
                                    right: 16,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_month_rounded, size: 13, color: MiloColors.primaryLight),
                                            const SizedBox(width: 4),
                                            Text(
                                              event.date,
                                              style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(Icons.location_on_rounded, size: 13, color: MiloColors.rose),
                                            const SizedBox(width: 2),
                                            Expanded(
                                              child: Text(
                                                '${event.venue}, ${event.city}',
                                                style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '₹${event.startingPrice.toStringAsFixed(0)} on Milo',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: MiloColors.emerald,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: MiloGradients.primaryBrand,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Book VIP Pass →',
                                                style: GoogleFonts.inter(
                                                  color: MiloColors.bg,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
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
                  // Carousel Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(heroList.length, (idx) {
                      final isCurrent = _heroCurrentIndex == idx;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrent ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCurrent ? MiloColors.primaryLight : MiloColors.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // ── Live Hangout Radar Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MiloColors.emerald.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.radar_rounded, color: MiloColors.emerald, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Hangout Beacons',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: MiloColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateBeaconScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MiloColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '+ Broadcast',
                          style: GoogleFonts.inter(
                            color: MiloColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Horizontal Beacons ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: 126,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: (_liveBeacons.isNotEmpty ? _liveBeacons : MockData.liveBeacons).length,
                  itemBuilder: (context, index) {
                    final displayedBeacons = _liveBeacons.isNotEmpty ? _liveBeacons : MockData.liveBeacons;
                    final beacon = displayedBeacons[index];
                    return Container(
                      width: 270,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MiloColors.bgSurface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MiloColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: NetworkImage(beacon.userAvatar),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  beacon.userName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: MiloColors.textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MiloColors.emerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  beacon.timeAgo,
                                  style: GoogleFonts.inter(
                                    color: MiloColors.emerald,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            beacon.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: MiloColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                beacon.location,
                                style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: MiloColors.bgSurface,
                                      content: Text(
                                        'Connected with ${beacon.userName} on Hangout! 💬',
                                        style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: MiloColors.primary.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: MiloColors.primary),
                                  ),
                                  child: Text(
                                    'Join Vibe',
                                    style: GoogleFonts.inter(
                                      color: MiloColors.primaryLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Categories Horizontal Filter ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Text(
                  'Explore by Category',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MiloColors.textPrimary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected ? MiloGradients.primaryBrand : null,
                          color: isSelected ? null : MiloColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : MiloColors.glassBorder,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: MiloColors.primaryGlow,
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Trending Events Section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trending Events 🔥',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MiloColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(1);
                        }
                      },
                      child: Text(
                        'See All →',
                        style: GoogleFonts.inter(
                          color: MiloColors.primaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = trendingEvents[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailsScreen(event: event),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MiloColors.bgSurface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: MiloColors.glassBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    event.imageUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 96, height: 96, color: MiloColors.bgCard),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MiloColors.bg.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, size: 12, color: MiloColors.amber),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${event.rating}',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: MiloColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      event.category,
                                      style: GoogleFonts.inter(
                                        color: MiloColors.primaryLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    event.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: MiloColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${event.date.split(',')[0]} • ${event.venue}',
                                    style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${event.startingPrice.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: MiloColors.emerald,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: MiloColors.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.6)),
                                        ),
                                        child: Text(
                                          'Book Pass →',
                                          style: GoogleFonts.inter(
                                            color: MiloColors.primaryLight,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: trendingEvents.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(color: MiloColors.glassBorder),
            ),
            child: Icon(icon, color: MiloColors.primaryLight, size: 20),
          ),
          if (badge != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: MiloColors.rose,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
