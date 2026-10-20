import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/milo_db_service.dart';
import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/milo_theme.dart';
import 'event_details_screen.dart';

class ExploreEventsScreen extends StatefulWidget {
  const ExploreEventsScreen({super.key});

  @override
  State<ExploreEventsScreen> createState() => _ExploreEventsScreenState();
}

class _ExploreEventsScreenState extends State<ExploreEventsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Popular';
  double _maxPrice = 5000;
  final TextEditingController _searchController = TextEditingController();
  List<EventModel> _liveEvents = [];

  final List<String> _categories = [
    'All',
    '🪘 Dandiya/Garba',
    '🎸 Live Concerts',
    '💑 Date Spots',
    '🎧 DJ & Parties',
    '💅 Kitty & Social',
    '🧘 Yoga & Fit',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await MiloDbService.instance.getEvents();
    if (mounted) {
      setState(() => _liveEvents = events);
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filters & Sorting 🎯',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _sortBy = 'Popular';
                                _maxPrice = 5000;
                              });
                              setState(() {});
                            },
                            child: Text('Reset', style: GoogleFonts.inter(color: MiloColors.rose, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Sort By', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Popular', 'Price: Low to High', 'Rating'].map((sort) {
                            final isSelected = _sortBy == sort;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() => _sortBy = sort);
                                setState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? MiloColors.primary : MiloColors.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSelected ? MiloColors.primaryLight : MiloColors.border),
                                ),
                                child: Text(
                                  sort,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? MiloColors.bg : MiloColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Max Budget', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
                          Text('Up to ₹${_maxPrice.toInt()}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.primaryLight)),
                        ],
                      ),
                      Slider(
                        value: _maxPrice,
                        min: 200,
                        max: 5000,
                        divisions: 24,
                        activeColor: MiloColors.primaryLight,
                        inactiveColor: MiloColors.bgCard,
                        onChanged: (val) {
                          setModalState(() => _maxPrice = val);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MiloColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('Apply Filters', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.bg)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceEvents = _liveEvents.isNotEmpty ? _liveEvents : MockData.events;
    var filteredEvents = sourceEvents.where((e) {
      final cleanCat = _selectedCategory.replaceAll(RegExp(r'[^\w\s/&]'), '').trim();
      final matchesCat = _selectedCategory == 'All' || e.category.toLowerCase().contains(cleanCat.toLowerCase());
      final matchesSearch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.venue.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.city.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesPrice = e.startingPrice <= _maxPrice;
      return matchesCat && matchesSearch && matchesPrice;
    }).toList();

    if (_sortBy == 'Price: Low to High') {
      filteredEvents.sort((a, b) => a.startingPrice.compareTo(b.startingPrice));
    } else if (_sortBy == 'Rating') {
      filteredEvents.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Book Events & Nights 🎟️',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 19),
                ),
              ],
            ),
            Text(
              'Verified venue entry & instant QR tickets',
              style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // BMS-Style Search & Quick Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search_rounded, color: MiloColors.primaryLight, size: 20),
                        hintText: 'Search events, artist, clubs, city...',
                        hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: MiloColors.textMuted, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showFilterModal,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MiloColors.glassBorder),
                    ),
                    child: const Icon(Icons.tune_rounded, color: MiloColors.primaryLight, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Categories Horizontal Filter
          SizedBox(
            height: 48,
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
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected ? MiloGradients.primaryBrand : null,
                      color: isSelected ? null : MiloColors.bgSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : MiloColors.glassBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Events Feed with Fast Filling & Rating Badges
          Expanded(
            child: filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: MiloColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No events match your filter',
                            style: GoogleFonts.inter(color: MiloColors.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
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
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: MiloColors.bgSurface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: MiloColors.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                    child: Image.network(
                                      event.imageUrl,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(height: 160, color: MiloColors.bgCard),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: MiloColors.bg.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        event.category,
                                        style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: MiloColors.rose.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '⚡ ${event.ticketsLeft} Passes Left',
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_rounded, size: 12, color: MiloColors.primaryLight),
                                            const SizedBox(width: 4),
                                            Text(event.date, style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, size: 16, color: MiloColors.amber),
                                            const SizedBox(width: 2),
                                            Text('${event.rating}', style: GoogleFonts.inter(color: MiloColors.amber, fontSize: 12, fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      event.title,
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 14, color: MiloColors.rose),
                                        const SizedBox(width: 4),
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
                                    const Divider(color: MiloColors.border, height: 22),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Starts at', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
                                            Text(
                                              '₹${event.startingPrice.toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.emerald),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            gradient: MiloGradients.primaryBrand,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: MiloColors.primaryGlow,
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'Book Now →',
                                            style: GoogleFonts.inter(color: MiloColors.bg, fontSize: 12, fontWeight: FontWeight.w900),
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
                  ),
          ),
        ],
      ),
    );
  }
}
