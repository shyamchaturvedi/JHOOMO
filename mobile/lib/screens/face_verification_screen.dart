import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

enum VerificationState {
  initial,
  scanning,
  blinkCheck,
  smileCheck,
  comparing,
  verified,
  failed,
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> with SingleTickerProviderStateMixin {
  VerificationState _state = VerificationState.initial;
  double _progress = 0.0;
  String _guidanceMessage = 'Align your face in the oval frame';
  late AnimationController _pulseController;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _startVerificationProcess() {
    setState(() {
      _state = VerificationState.scanning;
      _progress = 0.2;
      _guidanceMessage = 'Detecting facial contours... Hold still 👤';
    });

    _stepTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _state = VerificationState.blinkCheck;
        _progress = 0.5;
        _guidanceMessage = 'Liveness Test: Please Blink your eyes slowly 😉';
      });

      _stepTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() {
          _state = VerificationState.smileCheck;
          _progress = 0.75;
          _guidanceMessage = 'Great! Now give a gentle smile 😊';
        });

        _stepTimer = Timer(const Duration(milliseconds: 1800), () {
          if (!mounted) return;
          setState(() {
            _state = VerificationState.comparing;
            _progress = 0.9;
            _guidanceMessage = 'Matching real-time selfie with profile photo... 🔍';
          });

          _stepTimer = Timer(const Duration(milliseconds: 2200), () {
            if (!mounted) return;
            setState(() {
              _state = VerificationState.verified;
              _progress = 1.0;
              _guidanceMessage = 'Face Match 99.4% • 100% Authentic Verified! ✅';
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Live Selfie Verification 🛡️',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
          onPressed: () => Navigator.pop(context, _state == VerificationState.verified),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top safety trust banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MiloColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: MiloColors.primaryLight, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Anti-catfish & 100% genuine user guarantee. Your biometric face scan is encrypted & deleted post-match.',
                        style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Oval Camera Viewfinder with AI scanning laser
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing pulsing ring
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 250 + (_pulseController.value * 16),
                        height: 310 + (_pulseController.value * 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(140),
                          border: Border.all(
                            color: _state == VerificationState.verified
                                ? MiloColors.emerald.withValues(alpha: 0.8)
                                : MiloColors.primaryLight.withValues(alpha: 0.3 + (_pulseController.value * 0.4)),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _state == VerificationState.verified
                                  ? MiloColors.emerald.withValues(alpha: 0.4)
                                  : MiloColors.primary.withValues(alpha: 0.25),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Simulated Live Selfie Feed Oval
                  Container(
                    width: 240,
                    height: 300,
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface,
                      borderRadius: BorderRadius.circular(130),
                      border: Border.all(
                        color: _state == VerificationState.verified ? MiloColors.emerald : MiloColors.primaryLight,
                        width: 2.5,
                      ),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=600&q=80'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Biometric Mesh / Overlay effect when scanning
                  if (_state != VerificationState.initial && _state != VerificationState.verified)
                    Container(
                      width: 240,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(130),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MiloColors.primary.withValues(alpha: 0.2),
                            Colors.transparent,
                            MiloColors.cyan.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _state == VerificationState.blinkCheck
                              ? Icons.visibility
                              : _state == VerificationState.smileCheck
                                  ? Icons.sentiment_very_satisfied
                                  : Icons.face_retouching_natural,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 48,
                        ),
                      ),
                    ),

                  // Verified Tick Overlay
                  if (_state == VerificationState.verified)
                    Container(
                      width: 240,
                      height: 300,
                      decoration: BoxDecoration(
                        color: MiloColors.bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(130),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: MiloColors.emerald,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: MiloColors.bg, size: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'MATCH 99.4%',
                            style: GoogleFonts.inter(
                              color: MiloColors.emerald,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // AI Status & Guidance Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _guidanceMessage,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _state == VerificationState.verified ? MiloColors.emerald : MiloColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: MiloColors.bgSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _state == VerificationState.verified ? MiloColors.emerald : MiloColors.primaryLight,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AI Liveness 3D Scan',
                        style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}% Done',
                        style: GoogleFonts.inter(
                          color: _state == VerificationState.verified ? MiloColors.emerald : MiloColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Verification Checkpoints list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MiloColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStepIndicator('1. Face Mesh', _progress >= 0.2),
                    _buildStepIndicator('2. Blink Test', _progress >= 0.5),
                    _buildStepIndicator('3. Smile Test', _progress >= 0.75),
                    _buildStepIndicator('4. Match ID', _progress >= 1.0),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _state == VerificationState.verified ? MiloColors.emerald : MiloColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _state == VerificationState.initial
                      ? _startVerificationProcess
                      : _state == VerificationState.verified
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: MiloColors.bgSurface,
                                  content: Text(
                                    '🎉 Verified Badge added to your Milo Profile!',
                                    style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              );
                              Navigator.pop(context, true);
                            }
                          : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _state == VerificationState.verified
                            ? Icons.verified
                            : _state == VerificationState.initial
                                ? Icons.camera_front
                                : Icons.sync,
                        color: MiloColors.bg,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _state == VerificationState.initial
                            ? 'Capture Live Selfie & Verify 📸'
                            : _state == VerificationState.verified
                                ? 'Claim Blue Verified Badge 🛡️'
                                : 'Analyzing Facial Features...',
                        style: GoogleFonts.inter(
                          color: MiloColors.bg,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool isComplete) {
    return Row(
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: isComplete ? MiloColors.emerald : MiloColors.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isComplete ? FontWeight.w700 : FontWeight.w500,
            color: isComplete ? MiloColors.textPrimary : MiloColors.textMuted,
          ),
        ),
      ],
    );
  }
}
