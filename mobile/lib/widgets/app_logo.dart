import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class MiloAppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showTagline;

  const MiloAppLogo({
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
        // ── Milo Red Signature Entertainment Badge ──
        Container(
          padding: EdgeInsets.symmetric(horizontal: size * 0.32, vertical: size * 0.16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53945), Color(0xFFFF4D5B), Color(0xFFB81D28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: const [
              BoxShadow(
                color: MiloColors.primaryGlow,
                blurRadius: 14,
                spreadRadius: 1,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'milo',
                style: GoogleFonts.outfit(
                  fontSize: size * 0.58,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.star_rounded,
                color: MiloColors.amber,
                size: size * 0.36,
              ),
            ],
          ),
        ),
        if (showText && showTagline) ...[
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MEET | VIBE | SHOW',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: MiloColors.primaryLight,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Events & Meetup Passes',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: MiloColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class MiloBrandedWatermark extends StatelessWidget {
  final String label;

  const MiloBrandedWatermark({
    super.key,
    this.label = 'Verified by Milo Pass Network 🛡️',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MiloColors.bgSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiloAppLogo(size: 16, showText: false),
          const SizedBox(width: 6),
          Text(
            'MILO APP',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: MiloColors.primaryLight,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 10, color: MiloColors.border),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: MiloColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
