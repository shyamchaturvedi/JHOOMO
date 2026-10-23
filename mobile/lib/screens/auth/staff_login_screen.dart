import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import '../../services/milo_staff_service.dart';
import '../../theme/milo_theme.dart';
import '../organizer/qr_scanner_screen.dart';

/// Gate staff log in with the phone number the organizer registered plus
/// the unique gate passcode they were handed. No OTP needed — the passcode
/// is the credential.
class StaffLoginScreen extends StatefulWidget {
 const StaffLoginScreen({super.key});

 @override
 State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
 final TextEditingController _phoneCtrl = TextEditingController();
 final TextEditingController _passCtrl = TextEditingController();
 bool _loading = false;

 @override
 void dispose() {
 _phoneCtrl.dispose();
 _passCtrl.dispose();
 super.dispose();
 }

 Future<void> _login() async {
 final phone = _phoneCtrl.text.trim();
 final pass = _passCtrl.text.trim();
 if (phone.length < 10) {
 _toast('Enter the mobile number your organizer registered (10 digits).', false);
 return;
 }
 if (pass.isEmpty) {
 _toast('Enter your gate passcode (e.g. GATE-123456).', false);
 return;
 }

 setState(() => _loading = true);
 final assignment = await MiloStaffService.instance
 .validateStaffLogin(phone: phone, passcode: pass);
 if (!mounted) return;
 setState(() => _loading = false);

 if (assignment == null) {
 _toast('No active gate pass found for this number + passcode. Ask your organizer.', false);
 return;
 }

 final name = (assignment['name'] ?? 'Gate Staff').toString();
 await MiloSessionService.saveLoginSession(
 role: MiloRole.staff,
 name: name,
 phone: MiloAuthService.normalizePhone(phone),
 );
 await MiloAuthService.instance.upgradeRole(MiloRole.staff);

 if (!mounted) return;
 Navigator.pushAndRemoveUntil(
 context,
 MaterialPageRoute(builder: (_) => const QRScannerScreen()),
 (route) => false,
 );
 }

 void _toast(String msg, bool ok) {
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(
 msg,
 style: GoogleFonts.inter(
 color: ok ? MiloColors.emerald : MiloColors.rose,
 fontWeight: FontWeight.w700,
 fontSize: 12,
 ),
 ),
 ));
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
 child: const Center(child: Icon(Icons.qr_code_scanner_rounded, color: MiloColors.bg, size: 28)),
 ),
 const SizedBox(height: 24),
 Text(
 'Gate Staff Login ',
 style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 const SizedBox(height: 8),
 Text(
 'Enter the mobile number and gate passcode your organizer assigned to you.',
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary, height: 1.4),
 ),
 const SizedBox(height: 28),
 _fieldLabel('Registered Mobile Number'),
 _input(_phoneCtrl, '98765 43210', keyboardType: TextInputType.phone, maxLength: 10),
 const SizedBox(height: 16),
 _fieldLabel('Gate Passcode'),
 _input(_passCtrl, 'GATE-123456', textCapitalization: TextCapitalization.characters),
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
 onPressed: _loading ? null : _login,
 child: _loading
 ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: MiloColors.bg))
 : Text('Open Gate Scanner →', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.bg)),
 ),
 ),
 const SizedBox(height: 16),
 Center(
 child: Text(
 'Passcodes are issued by the event organizer in Staff & Gate Access Control.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted, height: 1.4),
 ),
 ),
 const SizedBox(height: 24),
 ],
 ),
 ),
 ),
 );
 }

 Widget _fieldLabel(String label) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(label, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
 );
 }

 Widget _input(
 TextEditingController ctrl,
 String hint, {
 TextInputType? keyboardType,
 int? maxLength,
 TextCapitalization textCapitalization = TextCapitalization.none,
 }) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: ctrl,
 keyboardType: keyboardType,
 maxLength: maxLength,
 textCapitalization: textCapitalization,
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: MiloColors.textPrimary, letterSpacing: 1),
 decoration: InputDecoration(
 counterText: '',
 hintText: hint,
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 14, letterSpacing: 1),
 border: InputBorder.none,
 ),
 ),
 );
 }
}
