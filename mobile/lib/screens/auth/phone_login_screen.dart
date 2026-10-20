import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'login_router.dart';
import 'otp_verification_screen.dart';
import 'profile_setup_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _agreedToTerms = true;
  bool _isLoading = false;

  void _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to terms & privacy policy to continue')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = MiloAuthService.instance;
    if (!auth.isPhoneAuthAvailable) {
      // Firebase not configured on this device → local demo OTP flow.
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(phoneNumber: phone, demoMode: true),
          ),
        );
      }
      return;
    }

    final error = await auth.sendOtp(
      phone: phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(phoneNumber: phone),
          ),
        );
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      onAutoVerified: (user) async {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await _afterSignedIn(phone);
      },
    );

    if (error != null && mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _afterSignedIn(String phone) async {
    if (!mounted) return;
    final hasProfile = await MiloAuthService.instance.hasProfile();
    if (!mounted) return;
    if (hasProfile) {
      await MiloAuthService.instance.restoreSession();
      if (!mounted) return;
      LoginRouter.go(context, MiloSessionService.currentRoleNotifier.value);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProfileSetupScreen(phoneNumber: phone)),
      );
    }
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
                  child: Icon(Icons.phone_iphone, color: MiloColors.bg, size: 28),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Mobile Number 📱',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: MiloColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We will send a 6-digit OTP to verify your account. Your number is never shared publicly.',
                style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),

              // Phone Input Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: MiloColors.bgSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MiloColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      '🇮🇳 +91',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MiloColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 24, color: MiloColors.border),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: MiloColors.textPrimary, letterSpacing: 1.5),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '98765 43210',
                          hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 15, letterSpacing: 1),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Terms & Privacy Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: MiloColors.primary,
                    checkColor: MiloColors.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I confirm I am 18+ and agree to Milo’s Terms & Privacy Policy.',
                      style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Submit Button
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
                  onPressed: _isLoading ? null : _sendOTP,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: MiloColors.bg),
                        )
                      : Text(
                          'Send OTP Code →',
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
