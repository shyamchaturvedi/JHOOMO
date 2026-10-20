import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import 'onboarding_screen.dart';

import '../../services/milo_session_service.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_db_service.dart';
import '../../services/payment_approval_service.dart';
import 'login_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Main intro controller
  late AnimationController _mainController;
  late Animation<double> _badgeScale;
  late Animation<double> _badgeOpacity;
  late Animation<double> _badgeRotation;
  late Animation<double> _contentSlide;
  late Animation<double> _contentOpacity;

  // Continuous ambient glow & pulse controller
  late AnimationController _pulseController;
  late Animation<double> _glowRadius;
  late Animation<double> _ringExpand;
  late Animation<double> _ringOpacity;

  // Shimmer streak controller for the brand logo
  late AnimationController _shimmerController;
  late Animation<double> _shimmerPos;

  @override
  void initState() {
    super.initState();

    // 1. Entrance choreography controller (0 to 1800ms)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Spring elastic scale for the logo badge
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_mainController);

    _badgeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    // Subtle 3D-tilt entrance
    _badgeRotation = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Subtitle & tagline slide up
    _contentSlide = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeIn),
      ),
    );

    // 2. Ambient breathing glow and sonar ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _glowRadius = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _ringExpand = Tween<double>(begin: 0.6, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _ringOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // 3. Shimmer reflection across logo
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(period: const Duration(milliseconds: 2600));

    _shimmerPos = Tween<double>(begin: -1.2, end: 1.8).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutCubic),
    );

    _mainController.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Keep splash animation visible long enough to appreciate the opening choreography
    await Future.delayed(const Duration(milliseconds: 2800));
    await MiloSessionService.initSession();

    // Firebase bootstrap: seed demo data & start booking/payment sync.
    MiloDbService.instance.ensureSeeded();
    PaymentApprovalService.instance.init();

    try {
      if (!MiloSessionService.isLoggedInNotifier.value) {
        await MiloAuthService.instance.restoreSession();
      } else {
        final role = await MiloAuthService.instance.fetchRole();
        if (role != null && role != MiloSessionService.currentRoleNotifier.value) {
          await MiloSessionService.updateRole(role);
        }
      }
    } catch (e) {
      debugPrint('Splash Firebase restore note: $e');
    }

    if (!mounted) return;

    if (MiloSessionService.isLoggedInNotifier.value) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 650),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: LoginRouter.targetForRole(MiloSessionService.currentRoleNotifier.value),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 650),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const OnboardingScreen(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: MiloColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Ambient Floating Glow Orbs ──
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Stack(
                children: [
                  // Top-Right Crimson Glow
                  Positioned(
                    top: -60,
                    right: -60,
                    child: Container(
                      width: 260 * _glowRadius.value,
                      height: 260 * _glowRadius.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            MiloColors.primary.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Center Deep Amber/Red Stage Light
                  Positioned(
                    top: size.height * 0.32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 300 * _glowRadius.value,
                        height: 300 * _glowRadius.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MiloColors.primary.withValues(alpha: 0.30),
                              blurRadius: 110,
                              spreadRadius: 35,
                            ),
                            BoxShadow(
                              color: MiloColors.amber.withValues(alpha: 0.16),
                              blurRadius: 80,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Animated Sonar Ripple Ring around the center logo
                  Positioned(
                    top: size.height * 0.38,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 140 * _ringExpand.value,
                        height: 140 * _ringExpand.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MiloColors.primaryLight.withValues(alpha: _ringOpacity.value),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Center Stage: Animated Hero Logo & Taglines ──
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_mainController, _shimmerController]),
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated 3D & Scaling Brand Badge
                    Transform.rotate(
                      angle: _badgeRotation.value,
                      child: Transform.scale(
                        scale: _badgeScale.value,
                        child: Opacity(
                          opacity: _badgeOpacity.value.clamp(0.0, 1.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer neon backlight aura
                              Container(
                                width: 220,
                                height: 86,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MiloColors.primary.withValues(alpha: 0.65),
                                      blurRadius: 36,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: MiloColors.amber.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),

                              // Physical 3D Crimson Gradient Badge with Shimmer Sweep
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE50914), // Netflix/BMS crimson
                                        Color(0xFFC00427),
                                        Color(0xFF8B0000), // Deep wine burgundy
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      width: 1.6,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Logo Text + Mascot Star
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'milo',
                                            style: GoogleFonts.outfit(
                                              fontSize: 48,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -1.2,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.star_rounded,
                                            color: MiloColors.amber,
                                            size: 32,
                                          ),
                                        ],
                                      ),

                                      // Shimmer light sweep reflection
                                      Positioned.fill(
                                        child: FractionallySizedBox(
                                          widthFactor: 0.4,
                                          alignment: Alignment(_shimmerPos.value, 0),
                                          child: Transform.rotate(
                                            angle: 0.4,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withValues(alpha: 0.0),
                                                    Colors.white.withValues(alpha: 0.35),
                                                    Colors.white.withValues(alpha: 0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Animated Tagline & Lucknow Cultural Hook
                    Transform.translate(
                      offset: Offset(0, _contentSlide.value),
                      child: Opacity(
                        opacity: _contentOpacity.value.clamp(0.0, 1.0),
                        child: Column(
                          children: [
                            // Glowing Pills / Category subtitle
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: MiloColors.bgSurface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: MiloColors.primaryLight.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flash_on_rounded, size: 14, color: MiloColors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MEET  •  VIBE  •  SHOWS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: MiloColors.primaryLight,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Milna Aasaan. Events Yaadgaar. ✨',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: MiloColors.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lucknow\'s #1 Premium Entertainment & Meetup Hub 🪘',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: MiloColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Bottom Cinematic Loading Indicator & Safety Tag ──
          Positioned(
            bottom: 42,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _contentOpacity.value.clamp(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stylized glowing progress line
                        SizedBox(
                          width: 140,
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              backgroundColor: MiloColors.bgCard,
                              valueColor: AlwaysStoppedAnimation<Color>(MiloColors.primaryLight),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: MiloColors.emerald, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              '100% Verified Entry  •  Zero Catfish  •  BMS Partner',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MiloColors.textMuted,
                                letterSpacing: 0.3,
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
        ],
      ),
    );
  }
}
