import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import 'phone_login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'emoji': '🎟️⭐',
      'title': 'BMS-Style Shows & Grand Dandiya',
      'description': 'Book passes for Dandiya nights, DJ concerts, Standup comedy, College fests & Kitty brunches with seat-tier pricing and instant QR entry.',
    },
    {
      'emoji': '🤝✨',
      'title': 'Milna Aasaan: Universal Meetups',
      'description': 'Match with students, remote devs, yoga enthusiasts, senior walkers & party squads. Broadcast 2-hour Chai beacons without exposing private numbers.',
    },
    {
      'emoji': '👮‍♂️🎪',
      'title': 'Organizer & Gate Access Control',
      'description': 'Organizers create events, assign gate-specific staff passcodes, and prevent unauthorized intrusion into private halls.',
    },
    {
      'emoji': '🛡️🔒',
      'title': '3D Face Verification & Privacy Shield',
      'description': 'Anti-catfish selfie verification, Ghost mode, Incognito attendance, and 1-tap Emergency SOS & Fake Call exit safety.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
                    );
                  },
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: MiloColors.bgSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: MiloColors.glassBorder, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: MiloColors.primary.withValues(alpha: 0.2),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              slide['emoji']!,
                              style: const TextStyle(fontSize: 60),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          slide['title']!,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: MiloColors.textPrimary,
                            height: 1.25,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['description']!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MiloColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                final isSelected = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected ? MiloColors.primaryLight : MiloColors.bgCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 36),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiloColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: MiloColors.primaryGlow,
                  ),
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
                      );
                    }
                  },
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'Get Started 🚀' : 'Next →',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MiloColors.bg,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
