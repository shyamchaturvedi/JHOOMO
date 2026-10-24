import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/scanner_tokens.dart';
import '../services/staff_auth_service.dart';
import 'scanner_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  final String? initialEventId;
  final String? initialStaffId;

  const StaffLoginScreen({
    super.key,
    this.initialEventId,
    this.initialStaffId,
  });

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController _eventIdCtrl = TextEditingController();
  final TextEditingController _staffIdCtrl = TextEditingController();
  final TextEditingController _passcodeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _eventIdCtrl.text = widget.initialEventId ?? 'ev_live_2026';
    _staffIdCtrl.text = widget.initialStaffId ?? 'st_gate01';
  }

  @override
  void dispose() {
    _eventIdCtrl.dispose();
    _staffIdCtrl.dispose();
    _passcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final eventId = _eventIdCtrl.text.trim();
    final staffId = _staffIdCtrl.text.trim();
    final passcode = _passcodeCtrl.text.trim();

    if (eventId.isEmpty || staffId.isEmpty) {
      setState(() => _errorMessage = 'Please enter Event ID & Staff ID');
      return;
    }
    if (passcode.length != 6) {
      setState(() => _errorMessage = 'Passcode must be exactly 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await StaffAuthService.instance.loginWithPasscode(
        eventId: eventId,
        staffId: staffId,
        passcode: passcode,
      );

      if (!mounted) return;

      if (res['ok'] == true && res['session'] != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScannerScreen(session: res['session'] as StaffAuthSession),
          ),
        );
      } else {
        setState(() => _errorMessage = res['error'] ?? 'Login failed. Check passcode.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error logging in: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScannerTokens.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Brand Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: ScannerTokens.surfaceCardElevated,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ScannerTokens.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner, color: ScannerTokens.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'JHOOMO STAFF SCANNER',
                          style: GoogleFonts.outfit(
                            color: ScannerTokens.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Gate Staff Login',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: ScannerTokens.textWhite,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit passcode provided by your event organizer.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: ScannerTokens.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ScannerTokens.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ScannerTokens.outline),
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _eventIdCtrl,
                        label: 'Event ID',
                        icon: Icons.event,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _staffIdCtrl,
                        label: 'Staff ID',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passcodeCtrl,
                        label: '6-Digit Passcode',
                        icon: Icons.lock,
                        isPasscode: true,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ScannerTokens.duplicateRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ScannerTokens.duplicateRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: ScannerTokens.duplicateRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(
                                    color: ScannerTokens.duplicateRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ScannerTokens.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Verify & Open Scanner',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Standalone Gate Scanner • Zero Bloat • Fast 0ms Admission',
                    style: GoogleFonts.inter(
                      color: ScannerTokens.textSlate,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPasscode = false,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: ScannerTokens.textWhite,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPasscode,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            color: ScannerTokens.textWhite,
            letterSpacing: isPasscode ? 6.0 : 0.0,
            fontSize: isPasscode ? 18 : 14,
            fontWeight: isPasscode ? FontWeight.w800 : FontWeight.w400,
          ),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Icon(icon, color: ScannerTokens.textSlate, size: 20),
            filled: true,
            fillColor: ScannerTokens.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ScannerTokens.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ScannerTokens.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ScannerTokens.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
