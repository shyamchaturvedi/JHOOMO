import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import '../../services/milo_auth_service.dart';
import '../../services/milo_session_service.dart';
import 'login_router.dart';

enum MiloUserRole {
 customer,
 organizer,
 promoter,
 staff,
 admin,
}

class ProfileSetupScreen extends StatefulWidget {
 final String phoneNumber;

 const ProfileSetupScreen({super.key, this.phoneNumber = ''});

 @override
 State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
 final TextEditingController _nameController = TextEditingController();
 DateTime _selectedDob = DateTime(DateTime.now().year - 23, 1, 1);
 String _selectedCity = 'Lucknow';
 MiloUserRole _selectedRole = MiloUserRole.customer;
 bool _isAdminAllowed = false;
 bool _saving = false;
 final List<String> _selectedVibes = [];

 String get _phone => widget.phoneNumber;

 @override
 void initState() {
 super.initState();
 _checkAdminAllowlist();
 }

 Future<void> _checkAdminAllowlist() async {
 // Only phone numbers listed in Firestore `milo_config/admins` can
 // select the Super Admin role — no more self-granted admin access.
 final allowed = await MiloAuthService.instance.isPhoneAdmin(phone: _phone);
 if (mounted) {
 setState(() => _isAdminAllowed = allowed);
 if (!allowed && _selectedRole == MiloUserRole.admin) {
 _selectedRole = MiloUserRole.customer;
 }
 }
 }

 final List<String> _availableVibes = [
 ' Garba Lover',
 ' DJ & EDM Beats',
 ' Acoustic Music',
 ' Standup & Open Mic',
 ' Couple Vibe',
 ' Board Gamers',
 ' Kitty & Brunches',
 ' Yoga & Fitness',
 ' Cafe Hopper',
 ' Startups & Tech',
 ];

 final List<String> _cities = ['Lucknow', 'Ahmedabad', 'Bangalore', 'Mumbai', 'Delhi', 'Jaipur'];

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text('Setup Profile ', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 18)),
 ),
 body: SafeArea(
 child: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
 children: [
 Center(
 child: Stack(
 children: [
 Container(
 width: 100,
 height: 100,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(color: MiloColors.primaryLight, width: 2.5),
 boxShadow: [
 BoxShadow(color: MiloColors.primary.withValues(alpha: 0.3), blurRadius: 20),
 ],
 ),
 child: const CircleAvatar(
 backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80'),
 ),
 ),
 Positioned(
 bottom: 0,
 right: 0,
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: const BoxDecoration(
 color: MiloColors.primary,
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.camera_alt, size: 16, color: MiloColors.bg),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // Display Name
 Text('Full / Display Name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: _nameController,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
 decoration: InputDecoration(
 hintText: 'Enter your name',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted),
 border: InputBorder.none,
 ),
 ),
 ),
 const SizedBox(height: 18),

 // Age & City Row
 Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Date of Birth (18+)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: InkWell(
 onTap: _pickDateOfBirth,
 child: Row(
 children: [
 Expanded(
 child: Text(
 _dobLabel,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600),
 ),
 ),
 const Icon(Icons.calendar_today_rounded, size: 18, color: MiloColors.primaryLight),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Your City', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MiloColors.textSecondary)),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _selectedCity,
 dropdownColor: MiloColors.bgSurface,
 icon: const Icon(Icons.arrow_drop_down, color: MiloColors.primaryLight),
 isExpanded: true,
 items: _cities.map((city) {
 return DropdownMenuItem<String>(
 value: city,
 child: Text(city, style: GoogleFonts.inter(color: MiloColors.textPrimary, fontWeight: FontWeight.w600)),
 );
 }).toList(),
 onChanged: (val) => setState(() => _selectedCity = val ?? 'Lucknow'),
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 24),

 // Select Your Vibes
 Text('Select Your Vibes & Interests', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 6),
 Text('Helps connect you with like-minded event buddies.', style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted)),
 const SizedBox(height: 14),
 Wrap(
 spacing: 8,
 runSpacing: 10,
 children: _availableVibes.map((vibe) {
 final isSelected = _selectedVibes.contains(vibe);
 return GestureDetector(
 onTap: () {
 setState(() {
 if (isSelected) {
 _selectedVibes.remove(vibe);
 } else {
 _selectedVibes.add(vibe);
 }
 });
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary : MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: isSelected ? MiloColors.primaryLight : MiloColors.glassBorder),
 ),
 child: Text(
 vibe,
 style: GoogleFonts.inter(
 color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
 fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
 fontSize: 12,
 ),
 ),
 ),
 );
 }).toList(),
 ),
  // Role access is server-verified. Debug builds may preview roles locally.
  if (kDebugMode) ...[
  const SizedBox(height: 20),
  Text('Preview Account Role (Debug)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
  const SizedBox(height: 6),
  Text('Release builds always start as an attendee.', style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted)),
  const SizedBox(height: 12),
  _buildRoleOption(
  role: MiloUserRole.customer,
  title: 'Attendee / Customer ',
  subtitle: 'Discover shows, book passes, connect with people & enter events',
  badge: 'DEFAULT',
  ),
  const SizedBox(height: 8),
  _buildRoleOption(
  role: MiloUserRole.organizer,
  title: 'Event Organizer / Host ',
  subtitle: 'Publish Dandiya/Concerts, manage ticket tiers, view sales & RSVPs',
  badge: 'CREATOR',
  ),
  const SizedBox(height: 8),
  _buildRoleOption(
  role: MiloUserRole.promoter,
  title: 'Influencer & Promoter ',
  subtitle: 'Share event links, track exact ticket sales & earn 10% cash commission',
  badge: 'ATTRIBUTION',
  ),
  const SizedBox(height: 8),
  _buildRoleOption(
  role: MiloUserRole.staff,
  title: 'Security / Event Staff ',
  subtitle: 'Fast QR entry scanner, gate cash collection & attendance lookup',
  badge: 'OPERATIONS',
  ),
  const SizedBox(height: 8),
  _buildRoleOption(
  role: MiloUserRole.admin,
  title: 'Super Admin Central ',
  subtitle: _isAdminAllowed
  ? 'Platform analytics, moderation, fraud control & payouts'
  : 'Invite only — admin access is granted by Jhoomo operations',
  badge: _isAdminAllowed ? 'GOVERNANCE' : 'LOCKED',
  ),
  ] else ...[
  const SizedBox(height: 20),
  Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
  color: MiloColors.bgSurface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: MiloColors.glassBorder),
  ),
  child: Row(
  children: [
  const Icon(Icons.verified_user_outlined, color: MiloColors.primaryLight, size: 22),
  const SizedBox(width: 12),
  Expanded(
  child: Text(
  'Your account starts as an attendee. Organizer and promoter access unlock after KYC or application approval.',
  style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textSecondary, height: 1.4),
  ),
  ),
  ],
  ),
  ),
  ],
  const SizedBox(height: 32),

 // Finish Setup Button
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
 onPressed: _saving ? null : _completeProfileAndRoute,
 child: _saving
 ? const SizedBox(
 width: 22,
 height: 22,
 child: CircularProgressIndicator(strokeWidth: 2, color: MiloColors.textPrimary),
 )
 : Text(
 _buttonLabelForRole,
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 ),
 ),
 const SizedBox(height: 20),
 ],
 ),
 ),
 );
 }

 String get _buttonLabelForRole {
 switch (_selectedRole) {
 case MiloUserRole.customer:
 return 'Enter Customer App ';
 case MiloUserRole.organizer:
 return 'Open Organizer Studio ';
 case MiloUserRole.promoter:
 return 'Launch Promoter & Influencer Portal ';
 case MiloUserRole.staff:
 return 'Launch Staff QR Scanner ';
 case MiloUserRole.admin:
 return 'Enter Admin Console ';
 }
 }

 int get _age {
 final now = DateTime.now();
 var age = now.year - _selectedDob.year;
 if (now.month < _selectedDob.month ||
 (now.month == _selectedDob.month && now.day < _selectedDob.day)) {
 age -= 1;
 }
 return age;
 }

 String get _dobIso =>
 '${_selectedDob.year.toString().padLeft(4, '0')}-${_selectedDob.month.toString().padLeft(2, '0')}-${_selectedDob.day.toString().padLeft(2, '0')}';

 String get _dobLabel {
 const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
 return '${_selectedDob.day} ${months[_selectedDob.month - 1]} ${_selectedDob.year}';
 }

 Future<void> _pickDateOfBirth() async {
 final now = DateTime.now();
 final picked = await showDatePicker(
 context: context,
 initialDate: _selectedDob,
 firstDate: DateTime(now.year - 100),
 lastDate: DateTime(now.year - 18, now.month, now.day),
 helpText: 'Select your date of birth',
 );
 if (picked != null && mounted) {
 setState(() => _selectedDob = picked);
 }
 }

 void _completeProfileAndRoute() async {
 if (_saving) return;

 if (_age < 18) {
 ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('JHOOMO is for users aged 18 and above.')),
 );
 return;
 }

 final name = _nameController.text.trim().isNotEmpty
 ? _nameController.text.trim()
 : 'JHOOMO User';

  MiloRole debugRole;
  switch (_selectedRole) {
  case MiloUserRole.customer:
  debugRole = MiloRole.customer;
  break;
  case MiloUserRole.organizer:
  debugRole = MiloRole.organizer;
  break;
  case MiloUserRole.promoter:
  debugRole = MiloRole.promoter;
  break;
  case MiloUserRole.staff:
  debugRole = MiloRole.staff;
  break;
  case MiloUserRole.admin:
  debugRole = _isAdminAllowed ? MiloRole.admin : MiloRole.customer;
  break;
  }

  setState(() => _saving = true);

  String uid = '';
  var sessionRole = kDebugMode ? debugRole : MiloRole.customer;
  final auth = MiloAuthService.instance;
  if (auth.currentUser != null) {
  final error = await auth.saveProfile(
  name: name,
  phone: _phone,
  dobIso: _dobIso,
  city: _selectedCity,
  role: sessionRole,
  vibes: _selectedVibes,
  );
  if (error != null && mounted) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
  uid = auth.uid;
  if (!kDebugMode) {
  sessionRole = await auth.fetchRole() ?? MiloRole.customer;
  }
  } else {
  // Demo mode (no Firebase Auth on device) — local session only.
  uid = 'demo_${MiloAuthService.normalizePhone(_phone)}';
  }

  await MiloSessionService.saveLoginSession(
  role: sessionRole,
  name: name,
  phone: _phone.startsWith('+') ? _phone : '+91 $_phone',
  uid: uid,
  );

 if (mounted) {
 LoginRouter.go(context, sessionRole);
 }
 }

 Widget _buildRoleOption({
 required MiloUserRole role,
 required String title,
 required String subtitle,
 required String badge,
 }) {
 final isSelected = _selectedRole == role;
 return GestureDetector(
 onTap: () {
 if (role == MiloUserRole.admin && !_isAdminAllowed) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
              'Super Admin is invite-only. Add your phone number in Firestore → jhoomo_config/admins.'),
 ),
 );
 return;
 }
 setState(() => _selectedRole = role);
 },
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary.withValues(alpha: 0.15) : MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: isSelected ? MiloColors.primary : MiloColors.glassBorder,
 width: isSelected ? 1.5 : 1,
 ),
 ),
 child: Row(
 children: [
 Icon(
 isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
 color: isSelected ? MiloColors.primary : MiloColors.textMuted,
 size: 20,
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: MiloColors.textPrimary, fontSize: 14)),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 badge,
 style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 ),
 ],
 ),
 const SizedBox(height: 3),
 Text(subtitle, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 11)),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}
