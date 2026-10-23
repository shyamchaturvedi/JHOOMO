import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class JhoomoAppLogo extends StatelessWidget {
 final double size;
 final bool showText;
 final bool showTagline;

 const JhoomoAppLogo({
 super.key,
 this.size = 38,
 this.showText = true,
 this.showTagline = false,
 });

 @override
 Widget build(BuildContext context) {
 return Row(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // JHOOMO 3D Dancing Silhouette Brand Badge 
 Container(
 width: size,
 height: size,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(size * 0.28),
 boxShadow: [
 BoxShadow(
 color: JhoomoColors.primary.withValues(alpha: 0.35),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(size * 0.28),
 child: Image.asset(
 'assets/icons/jhoomo_clean_badge.png',
 width: size,
 height: size,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Image.asset(
 'assets/icons/jhoomo_app_icon.png',
 width: size,
 height: size,
 fit: BoxFit.cover,
 ),
 ),
 ),
 ),
 if (showText) ...[
 const SizedBox(width: 10),
 Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 RichText(
 text: TextSpan(
 children: [
 TextSpan(
 text: 'Jhoo',
 style: GoogleFonts.outfit(
 fontSize: size * 0.62,
 fontWeight: FontWeight.w900,
 color: JhoomoColors.textPrimary,
 letterSpacing: -0.5,
 ),
 ),
 TextSpan(
 text: 'mo',
 style: GoogleFonts.outfit(
 fontSize: size * 0.62,
 fontWeight: FontWeight.w900,
 color: JhoomoColors.primary,
 letterSpacing: -0.5,
 ),
 ),
 ],
 ),
 ),
 if (showTagline)
 Text(
 'Events • People • Connections',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w500,
 color: JhoomoColors.textSecondary,
 letterSpacing: 0.3,
 ),
 ),
 ],
 ),
 ],
 ],
 );
 }
}

// Backward compatibility
typedef MiloAppLogo = JhoomoAppLogo;
