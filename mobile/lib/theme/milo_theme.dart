import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens extracted directly from DESIGN.md (Vibrant Social Pulse)
class JhoomoTokens {
 // Surface & Canvas Hierarchy 
 static const Color surface = Color(0xFFF8F9FF); // Airy ambient canvas
 static const Color surfaceDim = Color(0xFFCBDBF5);
 static const Color surfaceBright = Color(0xFFF8F9FF);
 static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Pure White Cards & Sheets
 static const Color surfaceContainerLow = Color(0xFFEFF4FF);
 static const Color surfaceContainer = Color(0xFFE5EEFF);
 static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
 static const Color surfaceContainerHighest = Color(0xFFD3E4FE);

 // Typography & On-Surfaces 
 static const Color onSurface = Color(0xFF0B1C30); // Deep Midnight Navy (Primary text)
 static const Color onSurfaceVariant = Color(0xFF5C3F40);
 static const Color textSecondary = Color(0xFF64748B); // Slate Muted
 static const Color textMuted = Color(0xFF94A3B8); // Subtle Subtitle Gray
 static const Color textWhite = Color(0xFFFFFFFF);

 // Primary Brand & Accents 
 static const Color primary = Color(0xFFE11D48); // Hot Crimson-Pink (Hero CTAs)
 static const Color primaryDark = Color(0xFFB80035); // Deep Crimson
 static const Color primaryContainer = Color(0xFFE11D48);
 static const Color onPrimary = Color(0xFFFFFFFF);
 static const Color onPrimaryContainer = Color(0xFFFFFAF9);

 // Secondary & Tertiary 
 static const Color secondary = Color(0xFF0F172A); // Authoritative Navy Dark Cards
 static const Color secondaryContainer = Color(0xFFDAE2FD);
 static const Color tertiary = Color(0xFF69565C);
 static const Color tertiaryContainer = Color(0xFFFFE4EB); // Blush pink tint
 static const Color onTertiaryContainer = Color(0xFFFFF9F9);

 // Festive & Status 
 static const Color orangeAccent = Color(0xFFFF6A00); // Sunkissed Orange
 static const Color greenVerified = Color(0xFF10B981); // Emerald Green (Live Now / Verified)
 static const Color gold = Color(0xFFFFC857); // VIP / Navratri Gold
 static const Color cyan = Color(0xFF06B6D4); // Energetic Teal

 // Borders & Outlines 
 static const Color outline = Color(0xFFE2E8F0); // Subtle Border
 static const Color outlineVariant = Color(0xFFF1F5F9);
 static const Color glassBorder = Color(0x22E11D48);

 // Category Chip Pastels (From DESIGN.md and UI Mockup) 
 static const Color chipMusicBg = Color(0xFFECFDF5);
 static const Color chipMusicFg = Color(0xFF059669);
 static const Color chipDanceBg = Color(0xFFFFF7ED);
 static const Color chipDanceFg = Color(0xFFEA580C);
 static const Color chipFoodBg = Color(0xFFF0FDF4);
 static const Color chipFoodFg = Color(0xFF16A34A);
 static const Color chipTravelBg = Color(0xFFEFF6FF);
 static const Color chipTravelFg = Color(0xFF2563EB);
 static const Color chipTechBg = Color(0xFFF5F3FF);
 static const Color chipTechFg = Color(0xFF7C3AED);
}

// Global Color Aliases mapping old MiloColors to DESIGN.md
class MiloColors {
 static const Color primary = JhoomoTokens.primary;
 static const Color primaryLight = Color(0xFFFF4D79);
 static const Color primaryDark = JhoomoTokens.primaryDark;
 static const Color primaryGlow = Color(0x44E11D48);

 static const Color bg = JhoomoTokens.surface;
 static const Color bgSurface = JhoomoTokens.surfaceContainerLowest;
 static const Color bgCard = JhoomoTokens.surfaceContainerLowest;
 static const Color bgCardHover = JhoomoTokens.surfaceContainerLow;

 static const Color gold = JhoomoTokens.gold;
 static const Color amber = Color(0xFFFFA000);
 static const Color emerald = JhoomoTokens.greenVerified;
 static const Color rose = JhoomoTokens.primary;
 static const Color cyan = JhoomoTokens.cyan;

 static const Color textPrimary = JhoomoTokens.onSurface;
 static const Color textSecondary = JhoomoTokens.textSecondary;
 static const Color textMuted = JhoomoTokens.textMuted;

 static const Color border = JhoomoTokens.outline;
 static const Color glassWhite = Color(0xEEFFFFFF);
 static const Color glassBorder = JhoomoTokens.glassBorder;

 static const Color accentGreen = JhoomoTokens.greenVerified;
 static const Color cardSurface = JhoomoTokens.surfaceContainerLowest;
 static const Color accentPink = JhoomoTokens.primary;
}

typedef JhoomoColors = MiloColors;

class JhoomoGradients {
 // Vibrant Brand Icon Gradient (Crimson Rose to Orange)
 static const LinearGradient brandIcon = LinearGradient(
 colors: [Color(0xFFE11D48), Color(0xFFFF2E63), Color(0xFFFF7A00)],
 begin: Alignment.bottomLeft,
 end: Alignment.topRight,
 );

 // Primary Call-To-Action Button Gradient
 static const LinearGradient primaryCta = LinearGradient(
 colors: [Color(0xFFE11D48), Color(0xFFFF3366)],
 begin: Alignment.centerLeft,
 end: Alignment.centerRight,
 );

 // Soft Ambient Rose-to-Peach Canvas Overlay
 static const LinearGradient ambientHeader = LinearGradient(
 colors: [Color(0xFFFFEEF2), Color(0xFFFFF7ED), Color(0xFFF8F9FF)],
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 );

 // Dark Media Card Overlay for Concerts/Nightlife
 static const LinearGradient darkCardOverlay = LinearGradient(
 colors: [Color(0xF00F172A), Color(0x660F172A), Colors.transparent],
 begin: Alignment.bottomCenter,
 end: Alignment.topCenter,
 );

 static const LinearGradient goldGlow = LinearGradient(
 colors: [Color(0xFFFFC857), Color(0xFFFF9F1C)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 );

 static const LinearGradient primaryBrand = brandIcon;
 static const LinearGradient redToDark = brandIcon;
 static const LinearGradient darkCard = LinearGradient(
 colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 );
}

typedef MiloGradients = JhoomoGradients;

class JhoomoTheme {
 static ThemeData get lightTheme => ThemeData(
 brightness: Brightness.light,
 scaffoldBackgroundColor: JhoomoTokens.surface,
 primaryColor: JhoomoTokens.primary,
 colorScheme: const ColorScheme.light(
 primary: JhoomoTokens.primary,
 secondary: JhoomoTokens.secondary,
 surface: JhoomoTokens.surfaceContainerLowest,
 error: Color(0xFFBA1A1A),
 ),
 appBarTheme: const AppBarTheme(
 backgroundColor: Colors.transparent,
 elevation: 0,
 scrolledUnderElevation: 0,
 iconTheme: IconThemeData(color: JhoomoTokens.onSurface),
 titleTextStyle: TextStyle(
 color: JhoomoTokens.onSurface,
 fontSize: 20,
 fontWeight: FontWeight.w800,
 fontFamily: 'Inter',
 ),
 ),
 cardTheme: CardThemeData(
 color: JhoomoTokens.surfaceContainerLowest,
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(16),
 side: const BorderSide(color: JhoomoTokens.outline, width: 1),
 ),
 ),
 textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
 bodyColor: JhoomoTokens.onSurface,
 displayColor: JhoomoTokens.onSurface,
 ),
 );

 static ThemeData get theme => lightTheme;
}

typedef MiloTheme = JhoomoTheme;

class GlassCard extends StatelessWidget {
 final Widget child;
 final EdgeInsets? padding;
 final double borderRadius;
 final VoidCallback? onTap;

 const GlassCard({
 super.key,
 required this.child,
 this.padding,
 this.borderRadius = 16,
 this.onTap,
 });

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: padding ?? const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: JhoomoTokens.surfaceContainerLowest,
 borderRadius: BorderRadius.circular(borderRadius),
 border: Border.all(color: JhoomoTokens.outline, width: 1),
 boxShadow: [
 BoxShadow(
 color: const Color(0xFF0F172A).withValues(alpha: 0.04),
 blurRadius: 16,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: child,
 ),
 );
 }
}
