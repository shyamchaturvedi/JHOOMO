import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/milo_theme.dart';
import 'screens/home_screen.dart';
import 'screens/explore_events_screen.dart';
import 'screens/community/single_community_hub_screen.dart';
import 'screens/games_date_screen.dart';
import 'screens/profile_safety_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/event_details_screen.dart';
import 'models/models.dart';
import 'services/milo_db_service.dart';
import 'services/milo_deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Error Protection to prevent Android App from Stopping/Crashing
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Milo App Protected Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Milo Async Uncaught Error: $error');
    return true; // Prevents crash
  };

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }
  unawaited(MiloDeepLinkService.instance.init());
  runApp(const MiloApp());
}

class MiloApp extends StatelessWidget {
  const MiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MILO',
      debugShowCheckedModeBanner: false,
      theme: MiloTheme.theme,
      home: const SplashScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onNavigate(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingDeepLink());
  }

  Future<void> _handlePendingDeepLink() async {
    final deepLinks = MiloDeepLinkService.instance;
    final eventId = deepLinks.takePendingEventId();
    final refCode = deepLinks.takePendingReferralCode();
    if (!mounted) return;

    if (eventId.isNotEmpty) {
      try {
        final events = await MiloDbService.instance.getEvents();
        EventModel? event;
        for (final e in events) {
          if (e.id == eventId) {
            event = e;
            break;
          }
        }
        final found = event;
        if (found != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(event: found, initialPromoCode: refCode),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Deep link event lookup note: $e');
      }
    }

    if (refCode.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎟️ Referral code $refCode saved — apply it while booking any event.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _onNavigate),
      const ExploreEventsScreen(),
      const SingleCommunityHubScreen(),
      const GamesDateScreen(),
      const ProfileSafetyScreen(),
    ];

    final navItems = [
      {'icon': Icons.explore_rounded, 'activeIcon': Icons.explore, 'label': 'Explore'},
      {'icon': Icons.confirmation_number_outlined, 'activeIcon': Icons.confirmation_number_rounded, 'label': 'Events'},
      {'icon': Icons.hub_outlined, 'activeIcon': Icons.hub_rounded, 'label': 'Community'},
      {'icon': Icons.sports_esports_outlined, 'activeIcon': Icons.sports_esports_rounded, 'label': 'Games'},
      {'icon': Icons.shield_outlined, 'activeIcon': Icons.shield_rounded, 'label': 'Safety'},
    ];

    return Scaffold(
      backgroundColor: MiloColors.bg,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MiloColors.bgSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: MiloColors.glassBorder.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: MiloColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = _currentIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    MiloColors.primary.withValues(alpha: 0.25),
                                    MiloColors.cyan.withValues(alpha: 0.12),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.5), width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected
                                  ? (item['activeIcon'] as IconData)
                                  : (item['icon'] as IconData),
                              color: isSelected
                                  ? MiloColors.primaryLight
                                  : MiloColors.textMuted,
                              size: 21,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? MiloColors.primaryLight : MiloColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
