import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

class BankAccountSettingsScreen extends StatefulWidget {
 const BankAccountSettingsScreen({super.key});

 @override
 State<BankAccountSettingsScreen> createState() => _BankAccountSettingsScreenState();
}

class _BankAccountSettingsScreenState extends State<BankAccountSettingsScreen> {
 final TextEditingController _accountHolderCtrl = TextEditingController(text: 'Sahil Kumar');
 final TextEditingController _accountNumberCtrl = TextEditingController(text: '50100492819201');
 final TextEditingController _ifscCtrl = TextEditingController(text: 'HDFC0001245');
 final TextEditingController _bankNameCtrl = TextEditingController(text: 'HDFC Bank Ltd');
 final TextEditingController _upiIdCtrl = TextEditingController(text: 'sahilkumar@okhdfcbank');

 bool _isSaved = true;
 bool _isVerified = true;

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Bank & Payout Settings ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18),
 ),
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.all(20),
 children: [
 // Payout Status Card
 Container(
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 (_isVerified && _isSaved ? MiloColors.emerald : MiloColors.amber).withValues(alpha: 0.2),
 MiloColors.bgSurface,
 ],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 ),
 borderRadius: BorderRadius.circular(22),
 border: Border.all(
 color: (_isVerified && _isSaved ? MiloColors.emerald : MiloColors.amber).withValues(alpha: 0.5),
 ),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.2),
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.verified_user_rounded, color: MiloColors.emerald, size: 24),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text('Payout Verified Account',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(width: 6),
 const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 16),
 ],
 ),
 const SizedBox(height: 3),
 Text('Direct NEFT / IMPS settlements in 3-5 working days',
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11)),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 Text('Bank Account Details (NEFT/RTGS)',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 12),

 _buildLabel('Account Holder Full Name'),
 _buildTextField(_accountHolderCtrl, 'As per PAN & Bank records'),
 const SizedBox(height: 14),

 _buildLabel('Bank Account Number'),
 _buildTextField(_accountNumberCtrl, 'e.g. 50100492819201', isSecret: true),
 const SizedBox(height: 14),

 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildLabel('IFSC Code'),
 _buildTextField(_ifscCtrl, 'e.g. HDFC0001245'),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildLabel('Bank Name'),
 _buildTextField(_bankNameCtrl, 'e.g. HDFC Bank'),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),

 Text('Instant UPI Payout ID (Optional)',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 10),
 _buildTextField(_upiIdCtrl, 'username@bankupi'),
 const SizedBox(height: 24),

 // Platform Escrow Policy Reminder
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.6),
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.info_outline_rounded, color: MiloColors.primaryLight, size: 18),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Milo holds event ticket proceeds in escrow. Payouts are automatically processed to this bank account within 3-5 business days after your event check-ins are verified.',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11, height: 1.4),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 30),

 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 elevation: 6,
 shadowColor: MiloColors.primaryGlow,
 ),
 onPressed: () {
 setState(() => _isSaved = true);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text(' Bank account details saved & verified successfully!',
 style: GoogleFonts.inter(color: MiloColors.emerald, fontWeight: FontWeight.w800)),
 ),
 );
 },
 child: Text(
 'Save & Verify Bank Account',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.bg, fontSize: 15),
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildLabel(String text) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 );
 }

 Widget _buildTextField(TextEditingController controller, String hint, {bool isSecret = false}) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: controller,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
 border: InputBorder.none,
 ),
 ),
 );
 }
}
