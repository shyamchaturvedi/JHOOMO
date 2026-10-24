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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  bool _initDone = false;
  bool _minAnimationDone = false;

  @override
  void initState() {
    super.initState();

    // Single unified 60fps hardware-accelerated animation controller
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 1. Icon badge elastic entrance
    _badgeScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _badgeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    // 2. Soft pulsing brand ambient aura
    _glowScale = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOutQuad),
      ),
    );

    _glowOpacity = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.55, curve: Curves.easeIn),
      ),
    );

    // 3. Text entrance with smooth upward glide
    _textSlide = Tween<double>(begin: 22.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.40, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeIn),
      ),
    );

    _animController.forward().then((_) {
      _minAnimationDone = true;
      _tryNavigate();
    });

    _startBackgroundInit();
  }

  /// Run initialization completely in background without blocking frame rasterization
  Future<void> _startBackgroundInit() async {
    try {
      await MiloSessionService.initSession();
      MiloDbService.instance.ensureSeeded();
      PaymentApprovalService.instance.init();

      if (!MiloSessionService.isLoggedInNotifier.value) {
        await MiloAuthService.instance.restoreSession();
      } else {
        final role = await MiloAuthService.instance.fetchRole();
        if (role != null &&
            role != MiloSessionService.currentRoleNotifier.value) {
          await MiloSessionService.updateRole(role);
        }
      }
    } catch (e) {
      debugPrint('Background init note: $e');
    } finally {
      _initDone = true;
      if (mounted) _tryNavigate();
    }
  }

  void _tryNavigate() {
    if (!_initDone || !_minAnimationDone || !mounted) return;

    final target = MiloSessionService.isLoggedInNotifier.value
        ? LoginRouter.targetForRole(
            MiloSessionService.currentRoleNotifier.value)
        : const OnboardingScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          child: target,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Soft Warm Ambient Radial Backdrop
          Positioned(
            top: -100,
            left: -50,
            right: -50,
            height: 480,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 0.9,
                  colors: [
                    const Color(0xFFFFE4EB).withValues(alpha: 0.65),
                    const Color(0xFFFFF0F5).withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Animated Centerpiece: Aura + Badge + Typography
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Container with dynamic breathing aura
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft diffused aura bloom
                        Transform.scale(
                          scale: _glowScale.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: JhoomoTokens.primary.withValues(
                                    alpha: _glowOpacity.value,
                                  ),
                                  blurRadius: 55,
                                  spreadRadius: 15,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Logo Badge with 3D drop shadow
                        Transform.scale(
                          scale: _badgeScale.value,
                          child: Opacity(
                            opacity: _badgeOpacity.value,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: JhoomoTokens.primary
                                        .withValues(alpha: 0.32),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFFF6A00)
                                        .withValues(alpha: 0.18),
                                    blurRadius: 22,
                                    offset: const Offset(4, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.asset(
                                  'assets/icons/jhoomo_clean_badge.png',
                                  width: 112,
                                  height: 112,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/icons/jhoomo_app_icon.png',
                                    width: 112,
                                    height: 112,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Brand Typography & Tagline
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Jhoo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -1.2,
                                  ),
                                ),
                                Text(
                                  'mo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: JhoomoTokens.primary,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Events • Squads • Memories',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
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

          // 3. Bottom Trust & Security Pill
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEEF2F6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      '100% Consent-First & Verified Booking',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
