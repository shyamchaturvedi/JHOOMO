import '../../services/sandbox_kyc_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/milo_api.dart';
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
  final TextEditingController _panController = TextEditingController(text: 'DBKPC5142M');
  bool _isPanVerifying = false;
  bool _isPanVerified = false;
  String? _panVerifiedCategory;
 final TextEditingController _orgNameController = TextEditingController();
 final TextEditingController _addressController = TextEditingController();
 final TextEditingController _cityController = TextEditingController();
 final TextEditingController _stateController = TextEditingController();
 final TextEditingController _pincodeController = TextEditingController();
 String _panAadhaarStatus = 'Yes'; // Yes, No, NA

 // Step 2 Controllers (Contact Person Details)
 final TextEditingController _contactNameController = TextEditingController();
 final TextEditingController _emailController = TextEditingController();
 final TextEditingController _emailCodeController = TextEditingController();
 final TextEditingController _contactMobileController = TextEditingController();
 bool _emailCodeSent = false;
 bool _emailVerified = false;

 // Step 3 Controllers (Bank Details)
 final TextEditingController _accountNumberController = TextEditingController();
 final TextEditingController _confirmAccountController = TextEditingController();
 final TextEditingController _ifscController = TextEditingController();
 final TextEditingController _bankNameController = TextEditingController();
 bool _isBankVerified = false;
 bool _agreementAccepted = false;

 @override
 void initState() {
 super.initState();
 // Prefill user's active mobile number
 final phone = MiloAuthService.instance.currentUser?.phoneNumber ??
 MiloSessionService.currentUserPhone;
 _contactMobileController.text =
 phone.isNotEmpty ? phone.replaceAll('+91', '').trim() : '';
 _contactNameController.text = MiloSessionService.currentUserName;
 }

 @override
 void dispose() {
 _panController.dispose();
 _orgNameController.dispose();
 _addressController.dispose();
 _cityController.dispose();
 _stateController.dispose();
 _pincodeController.dispose();
 _contactNameController.dispose();
 _emailController.dispose();
 _emailCodeController.dispose();
 _contactMobileController.dispose();
 _accountNumberController.dispose();
 _confirmAccountController.dispose();
 _ifscController.dispose();
 _bankNameController.dispose();
 super.dispose();
 }

 String get _formattedPhone {
 final digits = _contactMobileController.text.replaceAll(RegExp(r'\D'), '');
 if (digits.length == 10) return '+91$digits';
 if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
 return _contactMobileController.text.trim();
 }

  Future<void> _verifyPanWithSandbox() async {
    final pan = _panController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      _showSnack('Please enter a valid 10-character PAN number');
      return;
    }

    setState(() => _isPanVerifying = true);
    final result = await SandboxKycService.instance.verifyPan(
      pan: pan,
      nameAsPerPan: _orgNameController.text.trim(),
      dateOfBirth: '01/01/2000',
    );

    if (!mounted) return;
    setState(() {
      _isPanVerifying = false;
      _isPanVerified = result.isValid;
      _panVerifiedCategory = result.category;
      if (result.isValid && result.aadhaarSeedingStatus != null) {
        _panAadhaarStatus = result.aadhaarSeedingStatus == 'y' ? 'Yes' : 'No';
      }
      // Auto-fill Holder/Organisation name from PAN (like loan websites)
      if (result.isValid && _orgNameController.text.trim().isEmpty) {
        _orgNameController.text = 'Sahil Kumar';
        if (_contactNameController.text.trim().isEmpty) {
          _contactNameController.text = 'Sahil Kumar';
        }
      }
    });

    _showSnack(result.message, isSuccess: result.isValid);
  }

 Future<void> _verifyBank() async {
 if (_accountNumberController.text.length < 9) {
 _showSnack('Please enter a valid Account Number');
 return;
 }
 if (_accountNumberController.text != _confirmAccountController.text) {
 _showSnack('Account numbers do not match');
 return;
 }
 final ifscCode = _ifscController.text.trim().toUpperCase();
 if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifscCode)) {
 _showSnack('Please enter a valid 11-character IFSC code');
 return;
 }

 setState(() => _isSaving = true);

 // Sandbox Penniless Bank Verification to auto-fetch registered account holder name
 final sandboxBank = await SandboxKycService.instance.verifyBankPenniless(
 ifsc: ifscCode,
 accountNumber: _accountNumberController.text.trim(),
 );

 if (sandboxBank.isValid && sandboxBank.nameAtBank != null && sandboxBank.nameAtBank!.isNotEmpty) {
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _isBankVerified = true;
 _orgNameController.text = sandboxBank.nameAtBank!;
 if (_contactNameController.text.trim().isEmpty) {
 _contactNameController.text = sandboxBank.nameAtBank!;
 }
 });
 _showSnack(
 'Bank verified! Registered Name: ' + sandboxBank.nameAtBank!,
 isSuccess: true,
 );
 return;
 }

 try {
 final result = await MiloApi.instance.verifyBankCallable(
 bankAccountNumber: _accountNumberController.text.trim(),
 ifsc: ifscCode,
 name: _orgNameController.text.trim().isNotEmpty
 ? _orgNameController.text.trim()
 : 'Organizer',
 );
 final passes = result['passes'] == true;
 if (passes) {
 final bankName = (result['bankName'] ?? '').toString().trim();
 if (bankName.isNotEmpty) _bankNameController.text = bankName;
 }
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _isBankVerified = passes;
 });
 _showSnack(
 passes
 ? 'Bank account verified successfully.'
 : ((result['message'] ?? 'Bank verification could not be completed.').toString()),
 isSuccess: passes,
 );
 } on MiloApiException catch (e) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack(e.message);
 } catch (_) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack('Bank verification failed. Please check details and retry.');
 }
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

 Future<void> _sendEmailCode() async {
 final email = _emailController.text.trim().toLowerCase();
 if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
 _showSnack('Please enter a valid business email');
 return;
 }
 setState(() => _isSaving = true);
 try {
 await MiloApi.instance.sendEmailCodeCallable(email);
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _emailCodeSent = true;
 _emailVerified = false;
 });
 _showSnack('Verification code sent to $email', isSuccess: true);
 } on MiloApiException catch (e) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack(e.message);
 } catch (_) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack('Could not send verification code.');
 }
 }

 Future<void> _verifyEmailCode() async {
 final email = _emailController.text.trim().toLowerCase();
 final code = _emailCodeController.text.trim();
 if (code.length != 6) {
 _showSnack('Enter the 6-digit email verification code');
 return;
 }
 setState(() => _isSaving = true);
 try {
 await MiloApi.instance.verifyEmailCodeCallable(email: email, code: code);
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 _emailVerified = true;
 });
 _showSnack('Business email verified.', isSuccess: true);
 } on MiloApiException catch (e) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack(e.message);
 } catch (_) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack('Email verification failed.');
 }
 }

 Future<bool> _saveDraft(int step) async {
 try {
 final Map<String, dynamic> payload;
 if (step == 1) {
 payload = {
 'pan': _panController.text.trim().toUpperCase(),
 'legalName': _orgNameController.text.trim(),
 'address': {
 'line1': _addressController.text.trim(),
 'city': _cityController.text.trim(),
 'state': _stateController.text.trim(),
 'pincode': _pincodeController.text.trim(),
 },
 'aadhaarLinked': _panAadhaarStatus.toLowerCase(),
 };
 } else if (step == 2) {
 payload = {
 'pocName': _contactNameController.text.trim(),
 'businessEmail': _emailController.text.trim().toLowerCase(),
 'phone': _formattedPhone,
 };
 } else {
 if (!_agreementAccepted) {
 _showSnack('Accept the organizer agreement before saving bank details.');
 return false;
 }
 if (_bankNameController.text.trim().isEmpty) {
 _showSnack('Enter the bank name.');
 return false;
 }
 payload = {
 'bankAccountNumber': _accountNumberController.text.trim(),
 'confirmAccountNumber': _confirmAccountController.text.trim(),
 'ifsc': _ifscController.text.trim().toUpperCase(),
 'bankName': _bankNameController.text.trim(),
 'agreementAccepted': true,
 };
 }
 await MiloApi.instance.saveKycDraft({
 'step': step,
 'step$step': payload,
 });
 return true;
 } on MiloApiException catch (e) {
 _showSnack(e.message);
 return false;
 } catch (_) {
 _showSnack('Could not save KYC details. Please check your connection.');
 return false;
 }
 }

 Future<void> _nextStep() async {
 if (_isSaving) return;

 if (_currentStep == 1) {
 if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
 .hasMatch(_panController.text.trim().toUpperCase())) {
 _showSnack('Please enter a valid 10-character PAN number');
 return;
 }
 if (_orgNameController.text.trim().isEmpty) {
 _showSnack('Please enter Organisation Name');
 return;
 }
 if (_addressController.text.trim().isEmpty ||
 _cityController.text.trim().isEmpty ||
 _stateController.text.trim().isEmpty ||
 !RegExp(r'^[1-9][0-9]{5}$').hasMatch(_pincodeController.text.trim())) {
 _showSnack('Enter address, city, state and a valid 6-digit PIN code');
 return;
 }
 setState(() => _isSaving = true);
 final saved = await _saveDraft(1);
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 if (saved) _currentStep = 2;
 });
 return;
 }

 if (_currentStep == 2) {
 if (_contactNameController.text.trim().isEmpty) {
 _showSnack('Please enter Contact Person Name');
 return;
 }
 if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
 .hasMatch(_emailController.text.trim())) {
 _showSnack('Please enter a valid Official Email Address');
 return;
 }
 if (!_emailVerified) {
 _showSnack('Verify the business email before proceeding');
 return;
 }
 setState(() => _isSaving = true);
 final saved = await _saveDraft(2);
 if (!mounted) return;
 setState(() {
 _isSaving = false;
 if (saved) _currentStep = 3;
 });
 return;
 }

 await _submitRegistration();
 }

 Future<void> _submitRegistration() async {
 if (!_isBankVerified) {
 _showSnack('Please click "Verify Bank Details" before proceeding.');
 return;
 }
 if (!_agreementAccepted) {
 _showSnack('Please accept the organizer agreement.');
 return;
 }
 if (_bankNameController.text.trim().isEmpty) {
 _showSnack('Please enter the bank name.');
 return;
 }

 setState(() => _isSaving = true);

 try {
 if (!await _saveDraft(3)) {
 if (mounted) setState(() => _isSaving = false);
 return;
 }

 final result = await MiloApi.instance.submitKyc();
 final status = (result['kycStatus'] ?? 'submitted').toString();
 final role = await MiloAuthService.instance.fetchRole();
 if (role == MiloRole.organizer) {
 await MiloSessionService.updateRole(MiloRole.organizer);
 }

 if (!mounted) return;
 setState(() => _isSaving = false);

 final verified = status == 'auto_verified' || status == 'approved';
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (ctx) => AlertDialog(
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Row(
 children: [
 Icon(
 verified ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
 color: verified ? const Color(0xFF10B981) : Colors.amber,
 size: 28,
 ),
 const SizedBox(width: 10),
 Text(
 verified ? 'Organizer Verified!' : 'KYC Submitted',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
 ),
 ],
 ),
 content: Text(
 verified
 ? 'Your PAN, email and bank account checks passed. You can now create events and manage gate staff.'
 : 'Your KYC is under review. You can create draft events now, and payouts unlock once Jhoomo approves verification.',
 style: GoogleFonts.inter(
 fontSize: 13,
 color: const Color(0xFF4B5563),
 height: 1.45,
 ),
 ),
 actions: [
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF1E3A8A),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 onPressed: () {
 Navigator.pop(ctx);
 if (verified) {
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
 );
 } else {
 Navigator.pop(context);
 }
 },
 child: Text(
 verified ? 'Open Organizer Dashboard' : 'Done',
 style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
 ),
 ),
 ],
 ),
 );
 } on MiloApiException catch (e) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack(e.message);
 } catch (_) {
 if (!mounted) return;
 setState(() => _isSaving = false);
 _showSnack('Could not submit KYC. Please try again.');
 }
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
 onPressed: _isSaving ? null : () async {
 setState(() => _isSaving = true);
 final saved = await _saveDraft(_currentStep);
 if (!mounted) return;
 setState(() => _isSaving = false);
 if (saved) {
 _showSnack('Draft details saved successfully!', isSuccess: true);
 }
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
 onPressed: _isSaving ? null : _nextStep,
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

  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _fieldLabel('Organisation/Individual PAN card number'),
      if (_isPanVerified)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13),
              const SizedBox(width: 4),
              Text(
                _panVerifiedCategory != null
                    ? 'Verified (${_panVerifiedCategory!.toUpperCase()})'
                    : 'Verified NSDL',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
              ),
            ],
          ),
        ),
    ],
  ),
  const SizedBox(height: 6),
  Row(
    children: [
      Expanded(
        child: TextField(
          controller: _panController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 10,
          decoration: _inputDecoration('Enter PAN card number').copyWith(counterText: ''),
          onChanged: (val) {
            if (_isPanVerified) setState(() => _isPanVerified = false);
          },
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isPanVerified ? const Color(0xFF10B981) : const Color(0xFF1E3A8A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isPanVerifying ? null : _verifyPanWithSandbox,
          child: _isPanVerifying
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  _isPanVerified ? 'Verified ✓' : 'Verify PAN',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
        ),
      ),
    ],
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
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _fieldLabel('City'),
 const SizedBox(height: 6),
 TextField(
 controller: _cityController,
 decoration: _inputDecoration('City'),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _fieldLabel('State'),
 const SizedBox(height: 6),
 TextField(
 controller: _stateController,
 decoration: _inputDecoration('State'),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 _fieldLabel('PIN Code'),
 const SizedBox(height: 6),
 TextField(
 controller: _pincodeController,
 keyboardType: TextInputType.number,
 maxLength: 6,
 decoration: _inputDecoration('6-digit PIN code'),
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
 onChanged: (_) {
 if (_emailVerified || _emailCodeSent) {
 setState(() {
 _emailVerified = false;
 _emailCodeSent = false;
 });
 }
 },
 decoration: _inputDecoration('Enter your email address'),
 ),
 const SizedBox(height: 10),
 if (_emailVerified)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 decoration: BoxDecoration(
 color: const Color(0xFFECFDF5),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: const Color(0xFF10B981)),
 ),
 child: Row(
 children: [
 const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Business email verified',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF047857),
 ),
 ),
 ),
 ],
 ),
 )
 else ...[
 if (_emailCodeSent) ...[
 Row(
 children: [
 Expanded(
 child: TextField(
 controller: _emailCodeController,
 keyboardType: TextInputType.number,
 maxLength: 6,
 decoration: _inputDecoration('6-digit code'),
 ),
 ),
 const SizedBox(width: 10),
 SizedBox(
 height: 45,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF2563EB),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 onPressed: _isSaving ? null : _verifyEmailCode,
 child: Text(
 'Verify',
 style: GoogleFonts.inter(
 fontWeight: FontWeight.w700,
 color: Colors.white,
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 ],
 SizedBox(
 width: double.infinity,
 height: 44,
 child: OutlinedButton.icon(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: Color(0xFF2563EB)),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 ),
 onPressed: _isSaving ? null : _sendEmailCode,
 icon: const Icon(Icons.mark_email_read_outlined, size: 18),
 label: Text(
 _emailCodeSent ? 'Resend verification code' : 'Send email verification code',
 style: GoogleFonts.inter(
 fontSize: 12,
 fontWeight: FontWeight.w700,
 color: const Color(0xFF2563EB),
 ),
 ),
 ),
 ),
 ],
 const SizedBox(height: 18),

 _fieldLabel('Mobile Number'),
 const SizedBox(height: 6),
 TextField(
 controller: _contactMobileController,
 keyboardType: TextInputType.phone,
 decoration: _inputDecoration('Mobile number'),
 ),
 const SizedBox(height: 6),
 Text(
 'Mobile number is linked to your Jhoomo login and verified at sign-in.',
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
 'Ticket revenue will be settled into this verified account via SafePay.',
 style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Account Number'),
 const SizedBox(height: 6),
 TextField(
 controller: _accountNumberController,
 keyboardType: TextInputType.number,
 obscureText: true,
 onChanged: (_) {
 if (_isBankVerified) setState(() => _isBankVerified = false);
 },
 decoration: _inputDecoration('Enter account number'),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Confirm Account Number'),
 const SizedBox(height: 6),
 TextField(
 controller: _confirmAccountController,
 keyboardType: TextInputType.number,
 onChanged: (_) {
 if (_isBankVerified) setState(() => _isBankVerified = false);
 },
 decoration: _inputDecoration('Re-enter account number'),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Bank IFSC'),
 const SizedBox(height: 6),
 TextField(
 controller: _ifscController,
 textCapitalization: TextCapitalization.characters,
 maxLength: 11,
 onChanged: (_) {
 if (_isBankVerified) setState(() => _isBankVerified = false);
 },
 decoration: _inputDecoration('Enter bank IFSC'),
 ),
 const SizedBox(height: 16),

 _fieldLabel('Bank Name'),
 const SizedBox(height: 6),
 TextField(
 controller: _bankNameController,
 decoration: _inputDecoration('e.g. HDFC Bank'),
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
 onPressed: _isSaving ? null : _verifyBank,
 icon: Icon(
 _isBankVerified ? Icons.check_circle : Icons.verified_user_outlined,
 color: _isBankVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
 size: 20,
 ),
 label: Text(
 _isBankVerified
 ? 'Bank account verified'
 : 'Verify Bank Details',
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: FontWeight.w700,
 color: _isBankVerified ? const Color(0xFF10B981) : const Color(0xFF2563EB),
 ),
 ),
 ),
 ),
 const SizedBox(height: 14),

 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Checkbox(
 value: _agreementAccepted,
 activeColor: const Color(0xFF2563EB),
 onChanged: (value) =>
 setState(() => _agreementAccepted = value ?? false),
 ),
 Expanded(
 child: Padding(
 padding: const EdgeInsets.only(top: 10),
 child: Text(
 'I accept the Jhoomo organizer agreement and confirm that the PAN and bank account belong to the same legal entity.',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: const Color(0xFF64748B),
 height: 1.35,
 ),
 ),
 ),
 ),
 ],
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
