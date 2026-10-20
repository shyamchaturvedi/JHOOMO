import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/milo_theme.dart';

class GamesDateScreen extends StatefulWidget {
  const GamesDateScreen({super.key});

  @override
  State<GamesDateScreen> createState() => _GamesDateScreenState();
}

class _GamesDateScreenState extends State<GamesDateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Split bill state
  double _billAmount = 2400.0;
  int _peopleCount = 4;
  double _tipPercent = 10.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _launchGameModal(GameItem game) {
    int currentPromptIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: MiloColors.glassBorder),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: MiloColors.textMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(game.icon, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(game.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                              Text(game.players, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: MiloColors.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: MiloColors.border, height: 24),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: MiloColors.bgCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(color: MiloColors.primary.withValues(alpha: 0.15), blurRadius: 20),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Card #${currentPromptIndex + 1}',
                              style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              game.samplePrompts[currentPromptIndex],
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: MiloColors.textPrimary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiloColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setModalState(() {
                          currentPromptIndex = (currentPromptIndex + 1) % game.samplePrompts.length;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shuffle, color: MiloColors.bg, size: 18),
                          const SizedBox(width: 8),
                          Text('Next Prompt / Challenge →', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    final double totalWithTip = _billAmount + (_billAmount * (_tipPercent / 100));
    final double perPerson = totalWithTip / _peopleCount;

    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fun, Dates & Groups 🎉', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 20)),
            Text('Interactive party games & date planner', style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MiloColors.primaryLight,
          labelColor: MiloColors.primaryLight,
          unselectedLabelColor: MiloColors.textMuted,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Party Games'),
            Tab(text: 'Date Planner'),
            Tab(text: 'Split Bill'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Party Games ──
          ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: MockData.partyGames.length,
            itemBuilder: (context, index) {
              final game = MockData.partyGames[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: MiloColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: MiloColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MiloColors.border),
                      ),
                      child: Center(child: Text(game.icon, style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(game.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                              Text(game.players, style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(game.description, style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: MiloColors.primaryLight, size: 36),
                      onPressed: () => _launchGameModal(game),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Tab 2: Date Planner Wizard ──
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MiloColors.rose.withValues(alpha: 0.2), MiloColors.bgSurface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: MiloColors.rose.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: MiloColors.rose, size: 20),
                        const SizedBox(width: 8),
                        Text('AI Date Night Generator 💑', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select your preferred vibe, timing, and budget to craft the perfect couple outing!',
                      style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Romantic 🕯️', 'Playful & Games 🎳', 'Artistic & Live Music 🎸', 'Late Night Chai & Drive 🌙'].map((vibe) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: MiloColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: MiloColors.border),
                          ),
                          child: Text(vibe, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MiloColors.rose,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✨ Curated Date: Sunset Rooftop Acoustic -> Gelato Walk in Indiranagar!')),
                          );
                        },
                        child: Text('Generate Date Itinerary ✨', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Tab 3: Split-the-Bill Tool ──
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: MiloColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Party & Pass Bill Splitter 🧾', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Split tickets, food, or drinks seamlessly with friends.', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 20),

                    // Bill Amount Slider / Input
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill (₹)', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13)),
                        Text('₹${_billAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: MiloColors.primaryLight)),
                      ],
                    ),
                    Slider(
                      value: _billAmount,
                      min: 100,
                      max: 10000,
                      divisions: 99,
                      activeColor: MiloColors.primaryLight,
                      inactiveColor: MiloColors.bgCard,
                      onChanged: (val) => setState(() => _billAmount = val),
                    ),
                    const SizedBox(height: 12),

                    // People Count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Number of People', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13)),
                        Text('$_peopleCount Friends', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
                      ],
                    ),
                    Slider(
                      value: _peopleCount.toDouble(),
                      min: 2,
                      max: 20,
                      divisions: 18,
                      activeColor: MiloColors.cyan,
                      inactiveColor: MiloColors.bgCard,
                      onChanged: (val) => setState(() => _peopleCount = val.toInt()),
                    ),
                    const Divider(color: MiloColors.border, height: 28),

                    // Calculated Result Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: MiloColors.bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('EACH PERSON PAYS', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text(
                            '₹${perPerson.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: MiloColors.emerald),
                          ),
                          const SizedBox(height: 6),
                          Text('Total: ₹${totalWithTip.toStringAsFixed(0)} (with tip/tax)', style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share, color: MiloColors.bg, size: 16),
                        label: Text('Share UPI Split Request Link 📲', style: GoogleFonts.inter(color: MiloColors.bg, fontWeight: FontWeight.w800, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MiloColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Split Request of ₹${perPerson.toStringAsFixed(0)} per person copied to clipboard!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
