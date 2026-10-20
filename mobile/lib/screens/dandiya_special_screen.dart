import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mock_data.dart';
import '../theme/milo_theme.dart';
import 'event_details_screen.dart';

class DandiyaSpecialScreen extends StatelessWidget {
  const DandiyaSpecialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dandiyaEvents = MockData.events.where((e) => e.category.toLowerCase().contains('dandiya') || e.category.toLowerCase().contains('garba')).toList();

    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Dandiya & Garba Mahotsav 🪘✨',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 18),
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
          // Navratri Festive Spotlight Hero Banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53945), Color(0xFF91151F), Color(0xFF15131A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MiloColors.gold.withValues(alpha: 0.35), width: 1.2),
              boxShadow: [
                BoxShadow(color: MiloColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('SEASON 2026', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const Text('🪘💃✨', style: TextStyle(fontSize: 22)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Celebrate 9 Nights of Non-Stop Raas Garba!',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Authentic Gujarati food stalls, Live Dhol, Celebrity DJs & Traditional Dress Competitions.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeaturePill('Free Dandiya Sticks 🪄'),
                    _buildFeaturePill('Couple Passes 💑'),
                    _buildFeaturePill('Squad Tables 🎪'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Featured Dandiya & Garba Nights 🔥',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
          ),
          const SizedBox(height: 14),

          ...dandiyaEvents.map((event) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: MiloColors.glassBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Image.network(
                        event.imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(event.date, style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700)),
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
                          Text(event.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: MiloColors.textPrimary)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: MiloColors.rose),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text('${event.venue}, ${event.city}', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                  Text('Passes start at', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 10)),
                                  Text('₹${event.startingPrice.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.emerald)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: MiloGradients.primaryBrand,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Book Pass →', style: GoogleFonts.inter(color: MiloColors.bg, fontSize: 12, fontWeight: FontWeight.w900)),
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
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
