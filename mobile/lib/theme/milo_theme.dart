import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MiloColors {
  // ── Official Milo Design System Palette ──
  static const Color primary       = Color(0xFFE53945); // Primary Milo Red
  static const Color primaryLight  = Color(0xFFFF6B77); // Soft Luminous Red
  static const Color primaryDark   = Color(0xFFB81D28); // Deep Burgundy Red
  static const Color primaryGlow   = Color(0x55E53945); // Milo Red Glow

  // ── Deep Night Background & Surfaces ──
  static const Color bg            = Color(0xFF15131A); // Deep Night Dark Background
  static const Color bgSurface     = Color(0xFF211F28); // Elevated Surface
  static const Color bgCard        = Color(0xFF2A2733); // Card Background
  static const Color bgCardHover   = Color(0xFF353140); // Hover/Highlight Surface

  // ── Festive & Functional Accents ──
  static const Color gold          = Color(0xFFFFC857); // Accent Gold (Navratri/VIP)
  static const Color amber         = Color(0xFFFFA000); // Pending / Warning
  static const Color emerald       = Color(0xFF198754); // Success / Verified Green
  static const Color rose          = Color(0xFFFF3366); // Alert / Hot Rose
  static const Color cyan          = Color(0xFF00D2D3); // Cyan Accent

  // ── Typography Colors ──
  static const Color textPrimary   = Color(0xFFFFFFFF); // Pure Crisp White
  static const Color textSecondary = Color(0xFFA19FA8); // Muted Secondary Gray
  static const Color textMuted     = Color(0xFF777580); // Subtle Meta Gray

  // ── Borders & Glassmorphism ──
  static const Color border        = Color(0x22FFFFFF); // Translucent Rim Border
  static const Color glassWhite    = Color(0x10FFFFFF); // Frosted Glass Fill
  static const Color glassBorder   = Color(0x30E53945); // Milo Red Accent Border
}

class MiloGradients {
  static const LinearGradient primaryBrand = LinearGradient(
    colors: [Color(0xFFE53945), Color(0xFFFF6B77), Color(0xFFFFC857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redToDark = LinearGradient(
    colors: [Color(0xFFE53945), Color(0xFF8B1019), Color(0xFF15131A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkCard = LinearGradient(
    colors: [Color(0xFF2A2733), Color(0xFF1D1B24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGlow = LinearGradient(
    colors: [Color(0xFFFFC857), Color(0xFFFF9F1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class MiloTheme {
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MiloColors.bg,
        primaryColor: MiloColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: MiloColors.primary,
          secondary: MiloColors.primaryLight,
          surface: MiloColors.bgSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: MiloColors.textPrimary,
          displayColor: MiloColors.textPrimary,
        ),
      );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MiloColors.bgSurface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: MiloColors.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: MiloColors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
