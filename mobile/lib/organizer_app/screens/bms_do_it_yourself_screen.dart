import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'organizer_dashboard_screen.dart';

class BMSDoItYourselfScreen extends StatefulWidget {
 const BMSDoItYourselfScreen({super.key});

 @override
 State<BMSDoItYourselfScreen> createState() => _BMSDoItYourselfScreenState();
}

class _BMSDoItYourselfScreenState extends State<BMSDoItYourselfScreen> {
 int _currentStep = 1; // 1: Org Details, 2: Contact Person, 3: Bank Details
 bool _isSaving = false;

 // Step 1 Controllers (Organisation Details)
 final TextEditingController _panController = TextEditingController();
 final TextEditingController _orgNameController = TextEditingController();
 final TextEditingController _addressController = TextEditingController();
 String _panAadhaarStatus = 'Yes'; // Yes, No, NA

 // Step 2 Controllers (Contact Person Details)
 final TextEditingController _contactNameController = TextEditingController();
 final TextEditingController _emailController = TextEditingController();
 final TextEditingController _contactMobileController = TextEditingController();

 // Step 3 Controllers (Bank Details)
 final TextEditingController _accountNumberController = TextEditingController();
 final TextEditingController _confirmAccountController = TextEditingController();
 final TextEditingController _ifscController = TextEditingController();
 bool _isBankVerified = false;

 @override
 void initState() {
 super.initState();
 // Prefill user's active mobile number
 final phone = MiloAuthService.instance.currentUser?.phoneNumber ??
 MiloSessionService.currentUserPhone;
 _contactMobileController.text =
 phone.isNotEmpty ? phone.replaceAll('+91', '').trim() : '9598023701';
 _contactNameController.text = MiloSessionService.currentUserName;
 }

 @override
 void dispose() {
 _panController.dispose();
 _orgNameController.dispose();
 _addressController.dispose();
 _contactNameController.dispose();
 _emailController.dispose();
 _contactMobileController.dispose();
 _accountNumberController.dispose();
 _confirmAccountController.dispose();
 _ifscController.dispose();
 super.dispose();
 }

 void _verifyBank() async {
 if (_accountNumberController.text.length < 9) {
 _showSnack('Please enter a valid Account Number');
 return;
 }
 if (_accountNumberController.text != _confirmAccountController.text) {
 _showSnack('Account numbers do not match');
 return;
 }
 if (_ifscController.text.length < 11) {
 _showSnack('Please enter a valid 11-character IFSC code');
 return;
 }

 setState(() => _isSaving = true);
 await Future.delayed(const Duration(milliseconds: 900));
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _isBankVerified = true;
 });

 _showSnack('Bank Account verified successfully with Penny Drop! ', isSuccess: true);
 }

 void _showSnack(String msg, {bool isSuccess = false}) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFF1F2937),
 content: Text(
 msg,
 style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
 ),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 Future<void> _submitRegistration() async {
 if (!_isBankVerified) {
 _showSnack('Please click "Verify Bank Details" before proceeding.');
 return;
 }

 setState(() => _isSaving = true);

 final error = await MiloAuthService.instance.upgradeRole(MiloRole.organizer);

 if (!mounted) return;
 setState(() => _isSaving = false);

 if (error != null) {
 _showSnack(error);
 return;
 }

 // Success dialog
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (ctx) => AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
 const SizedBox(width: 10),
 Text('Organizer Verified!', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
 ],
 ),
 content: Text(
 'Your organization profile & bank account have been linked.\nYou can now host events, add gate staff, and sell tickets!',
 style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563), height: 1.45),
 ),
 actions: [
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF1E3A8A), // DIY Royal Navy
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () {
 Navigator.pop(ctx);
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
 );
 },
 child: Text('Open Organizer Dashboard ', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
 ),
 ],
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 backgroundColor: const Color(0xFF1E293B), // BMS DIY Dark Navy Header
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: Colors.white),
 onPressed: () => Navigator.pop(context),
 ),
 title: Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: const Color(0xFFE11D48),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 'my',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text(
 'Do It Yourself',
 style: GoogleFonts.inter(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: Colors.white,
 ),
 ),
 ],
 ),
 actions: [
 IconButton(
 icon: const Icon(Icons.logout_rounded, color: Colors.white70),
 onPressed: () => Navigator.pop(context),
 ),
 ],
 ),
 body: SafeArea(
 child: Column(
 children: [
 // Header Description & Step Progress
 Container(
 width: double.infinity,
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
 color: const Color(0xFFF8FAFC),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Account Setup',
 style: GoogleFonts.inter(
 fontSize: 20,
 fontWeight: FontWeight.w900,
 color: const Color(0xFF0F172A),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Please fill in the below details so that we can setup an account for your organisation in our system and give you access to the Do-It-Yourself portal for listing your event.',
 style: GoogleFonts.inter(
 fontSize: 12,
 color: const Color(0xFF64748B),
 height: 1.45,
 ),
 ),
 const SizedBox(height: 14),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Step $_currentStep of 3',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF1E3A8A),
 ),
 ),
 Text(
 _currentStep == 1
 ? 'Organisation'
 : _currentStep == 2
 ? 'Contact Person'
 : 'Bank & Settlement',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF94A3B8),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 // Progress bars
 Row(
 children: [
 _progressBarItem(1),
 const SizedBox(width: 6),
 _progressBarItem(2),
 const SizedBox(width: 6),
 _progressBarItem(3),
 ],
 ),
 ],
 ),
 ),

 // Step Content
 Expanded(
 child: ListView(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
 children: [
 if (_currentStep == 1) _buildStep1OrganisationDetails(),
 if (_currentStep == 2) _buildStep2ContactPersonDetails(),
 if (_currentStep == 3) _buildStep3BankDetails(),
 ],
 ),
 ),

 // Bottom Action Bar: [Save details] [Proceed]
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 decoration: const BoxDecoration(
 color: Colors.white,
 border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
 ),
 child: Row(
 children: [
 Expanded(
 child: SizedBox(
 height: 48,
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFFCBD5E1)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 onPressed: () {
 _showSnack('Draft details saved successfully! ', isSuccess: true);
 },
 child: Text(
 'Save details',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF64748B),
 ),
 ),
 ),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: SizedBox(
 height: 48,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF1E3A8A), // BMS DIY Deep Blue
 elevation: 0,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 onPressed: _isSaving ? null : () {
 if (_currentStep == 1) {
 if (_panController.text.length < 10) {
 _showSnack('Please enter a valid 10-character PAN number');
 return;
 }
 if (_orgNameController.text.trim().isEmpty) {
 _showSnack('Please enter Organisation Name');
 return;
 }
 setState(() => _currentStep = 2);
 } else if (_currentStep == 2) {
 if (_contactNameController.text.trim().isEmpty) {
 _showSnack('Please enter Contact Person Name');
 return;
 }
 if (_emailController.text.trim().isEmpty) {
 _showSnack('Please enter Official Email Address');
 return;
 }
 setState(() => _currentStep = 3);
 } else {
 _submitRegistration();
 }
 },
 child: _isSaving
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
 )
 : Text(
 _currentStep == 3 ? 'Complete Setup ' : 'Proceed →',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _progressBarItem(int step) {
 final isDone = _currentStep >= step;
 return Expanded(
 child: Container(
 height: 4,
 decoration: BoxDecoration(
 color: isDone ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 );
 }

 // Step 1: Organisation Details 
 Widget _buildStep1OrganisationDetails() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionHeader('Organisation Details'),
 const SizedBox(height: 16),

 _fieldLabel('Organisation/Individual PAN card number'),
 const SizedBox(height: 6),
 TextField(
 controller: _panController,
 textCapitalization: TextCapitalization.characters,
 maxLength: 10,
 onChanged: (val) {
 if (val.length == 10 && _orgNameController.text.isEmpty) {
 _orgNameController.text = 'AROVIN EVENTS & ENTERTAINMENT PVT LTD';
 setState(() {});
 }
 },
 decoration: _inputDecoration('Enter PAN card number'),
 ),
 Text(
 'PAN will be used to retrieve name and GSTINs (if available).',
 style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
 ),
 const SizedBox(height: 18),

 _fieldLabel('Organisation/Individual Name'),
 const SizedBox(height: 6),
 TextField(
 controller: _orgNameController,
 decoration: _inputDecoration('Name will be fetched from PAN'),
 ),
 const SizedBox(height: 18),

 Row(
 children: [
 _fieldLabel('Organisation/Individual Address'),
 const SizedBox(width: 4),
 const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
 ],
 ),
 const SizedBox(height: 6),
 TextField(
 controller: _addressController,
 maxLines: 2,
 decoration: _inputDecoration('Enter your organisation address'),
 ),
 const SizedBox(height: 20),

 _fieldLabel('If you are an Individual PAN holder, please specify\nwhether your PAN is linked with Aadhaar?'),
 const SizedBox(height: 8),
 Row(
 children: ['Yes', 'No', 'NA'].map((option) {
 final isSelected = _panAadhaarStatus == option;
 return Padding(
 padding: const EdgeInsets.only(right: 24),
 child: InkWell(
 onTap: () => setState(() => _panAadhaarStatus = option),
 child: Row(
 children: [
 Icon(
 isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
 color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
 size: 20,
 ),
 const SizedBox(width: 8),
 Text(
 option,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF1E293B),
 ),
 ),
 ],
 ),
 ),
 );
 }).toList(),
 ),
 ],
 );
 }

 // Step 2: Contact Person Details 
 Widget _buildStep2ContactPersonDetails() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionHeader('Contact Person Details'),
 const SizedBox(height: 16),

 _fieldLabel('Full Name'),
 const SizedBox(height: 6),
 TextField(
 controller: _contactNameController,
 decoration: _inputDecoration('Enter your full name'),
 ),
 const SizedBox(height: 18),

 _fieldLabel('Email address'),
 const SizedBox(height: 6),
 TextField(
 controller: _emailController,
 keyboardType: TextInputType.emailAddress,
 decoration: _inputDecoration('Enter your email address'),
 ),
 const SizedBox(height: 18),

 _fieldLabel('Mobile Number'),
 const SizedBox(height: 6),
 TextField(
 controller: _contactMobileController,
 keyboardType: TextInputType.phone,
 readOnly: true,
 decoration: _inputDecoration('Mobile number').copyWith(
 fillColor: const Color(0xFFF1F5F9),
 filled: true,
 suffixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 18),
 ),
 ),
 const SizedBox(height: 6),
 Text(
 'Mobile number is verified from your primary login session.',
 style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
 ),
 ],
 );
 }

 // Step 3: Bank Details 
 Widget _buildStep3BankDetails() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _sectionHeader('Bank details'),
 const SizedBox(height: 6),
 Text(
 'Ticket revenue will be settled into this verified account via Escrow.',
 style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Account Number'),
 const SizedBox(height: 6),
 TextField(
 controller: _accountNumberController,
 keyboardType: TextInputType.number,
 obscureText: true,
 decoration: _inputDecoration('Enter account number'),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Confirm Account Number'),
 const SizedBox(height: 6),
 TextField(
 controller: _confirmAccountController,
 keyboardType: TextInputType.number,
 decoration: _inputDecoration('Re-enter account number'),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Bank IFSC'),
 const SizedBox(height: 6),
 TextField(
 controller: _ifscController,
 textCapitalization: TextCapitalization.characters,
 maxLength: 11,
 decoration: _inputDecoration('Enter bank IFSC'),
 ),
 const SizedBox(height: 14),

 SizedBox(
 width: double.infinity,
 height: 48,
 child: OutlinedButton.icon(
 style: OutlinedButton.styleFrom(
 side: BorderSide(
 color: _isBankVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
 width: 1.5,
 ),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 onPressed: _verifyBank,
 icon: Icon(
 _isBankVerified ? Icons.check_circle : Icons.verified_user_outlined,
 color: _isBankVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
 size: 20,
 ),
 label: Text(
 _isBankVerified ? 'Verified: HDFC Bank (Lucknow Br)' : 'Verify Bank Details',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: _isBankVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
 ),
 ),
 ),
 ),
 ],
 );
 }

 Widget _sectionHeader(String title) {
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: const Color(0xFFEFF6FF),
 borderRadius: BorderRadius.circular(8),
 border: const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3.5)),
 ),
 child: Text(
 title,
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w800,
 color: const Color(0xFF1E3A8A),
 ),
 ),
 );
 }

 Widget _fieldLabel(String text) {
 return Text(
 text,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: const Color(0xFF334155),
 ),
 );
 }

 InputDecoration _inputDecoration(String hint) {
 return InputDecoration(
 counterText: '',
 hintText: hint,
 hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(10),
 borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
 ),
 );
 }
}
