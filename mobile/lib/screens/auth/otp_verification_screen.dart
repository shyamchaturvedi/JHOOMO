import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'login_router.dart';
import 'profile_setup_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool demoMode;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.demoMode = false,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _navigated = false;
  int _autoCheckTicks = 0;

  @override
  void initState() {
    super.initState();
    _watchAutoVerification();
  }

  /// Firebase may auto-verify on Android (instant verification / SMS
  /// retriever). Poll briefly so the user is not stuck on this screen.
  Future<void> _watchAutoVerification() async {
    if (widget.demoMode) return;
    while (_autoCheckTicks < 20 && mounted && !_navigated) {
      await Future.delayed(const Duration(milliseconds: 600));
      _autoCheckTicks++;
      if (!mounted || _navigated) return;
      final user = MiloAuthService.instance.currentUser;
      if (user != null && user.phoneNumber != null) {
        final expected = MiloAuthService.formatPhone(widget.phoneNumber);
        if (user.phoneNumber == expected) {
          await _afterVerified();
          return;
        }
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter full 6-digit OTP code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    String? error;
    if (widget.demoMode) {
      await Future.delayed(const Duration(milliseconds: 700));
      error = null;
    } else {
      error = await MiloAuthService.instance.verifyOtp(otp);
    }

    if (!mounted) return;
    if (error != null) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _afterVerified();
  }

  Future<void> _afterVerified() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (!widget.demoMode && MiloAuthService.instance.currentUser != null) {
      final hasProfile = await MiloAuthService.instance.hasProfile();
      if (!mounted) return;
      if (hasProfile) {
        await MiloAuthService.instance.restoreSession();
        if (!mounted) return;
        LoginRouter.go(context, MiloSessionService.currentRoleNotifier.value);
        return;
      }
    } else if (MiloSessionService.isLoggedInNotifier.value) {
      // Returning demo user with an existing local session.
      if (!mounted) return;
      LoginRouter.go(context, MiloSessionService.currentRoleNotifier.value);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfileSetupScreen(phoneNumber: widget.phoneNumber)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiloColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: MiloGradients.primaryBrand,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(Icons.mark_email_read, color: MiloColors.bg, size: 28),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify 6-Digit Code 🔐',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: MiloColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.demoMode
                    ? 'Demo mode for +91 ${widget.phoneNumber} — enter any 6 digits to continue.'
                    : 'Code sent to +91 ${widget.phoneNumber}. Enter below to authenticate.',
                style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),

              // 6-digit OTP fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                    width: 46,
                    height: 54,
                    decoration: BoxDecoration(
                      color: MiloColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _controllers[index].text.isNotEmpty ? MiloColors.primaryLight : MiloColors.glassBorder,
                        width: _controllers[index].text.isNotEmpty ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: MiloColors.primaryLight),
                        decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                        onChanged: (val) {
                          if (val.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (val.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          setState(() {});
                          if (index == 5 && val.isNotEmpty) {
                            _verifyOTP();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Didn’t get code? ', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13)),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New OTP sent via SMS!')),
                      );
                    },
                    child: Text('Resend in 30s', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiloColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: MiloColors.primaryGlow,
                  ),
                  onPressed: _isVerifying ? null : _verifyOTP,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: MiloColors.bg),
                        )
                      : Text(
                          'Verify & Proceed →',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.bg),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
