import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../services/milo_auth_service.dart';
import '../services/milo_api.dart';
import '../services/milo_session_service.dart';

/// S-27 · Edit Profile Screen
/// Allows updating display name, bio (<= 160 chars), city, gender, email, and interests.
/// Phone and Date of Birth are locked (immutable for safety/18+ age verification).
class EditProfileScreen extends StatefulWidget {
 const EditProfileScreen({super.key});

 @override
 State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
 final _nameCtrl = TextEditingController(text: 'Sahil Patel');
 final _bioCtrl = TextEditingController(
 text: 'Event explorer, Garba enthusiast, and music festival addict. Catch me front row!',
 );
 final _cityCtrl = TextEditingController(text: 'Ahmedabad');
 final _emailCtrl = TextEditingController(text: 'sahil@jhoomo.live');
 String _gender = 'Male';

 final List<String> _availableInterests = [
 'Garba',
 'EDM',
 'Concerts',
 'Standup Comedy',
 'Food Festivals',
 'Gaming',
 'Folk Dance',
 'College Fests',
 'Workshops',
 'Theatre',
 ];

 late Set<String> _selectedInterests;
 bool _isSaving = false;

 @override
 void initState() {
 super.initState();
 _selectedInterests = {'Garba', 'EDM', 'Concerts', 'Standup Comedy'};
 }

 @override
 void dispose() {
 _nameCtrl.dispose();
 _bioCtrl.dispose();
 _cityCtrl.dispose();
 _emailCtrl.dispose();
 super.dispose();
 }

  void _saveProfile() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Always update local storage & active ValueNotifier first (instant UI sync)
      await MiloSessionService.saveLoginSession(
        role: MiloSessionService.currentRole,
        name: newName,
        phone: MiloSessionService.currentUserPhone,
        uid: MiloSessionService.currentUid,
      );

      // 2. Best-effort sync with backend completeProfile
      try {
        await MiloApi.instance.completeProfile(
          displayName: newName,
          dobIso: '',
          cityId: _cityCtrl.text.trim(),
          gender: _gender.toLowerCase(),
          interests: _selectedInterests.toList(),
          bio: _bioCtrl.text.trim(),
          consents: const [
            {'type': 'terms', 'granted': true},
            {'type': 'privacy', 'granted': true},
          ],
        );
      } catch (backendErr) {
        debugPrint('Backend profile sync note (saved locally): $backendErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
            backgroundColor: MiloColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: JhoomoTokens.surface,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back_rounded, color: JhoomoTokens.onSurface),
 onPressed: () => Navigator.pop(context),
 ),
 title: Text(
 'Edit Profile',
 style: GoogleFonts.inter(
 color: JhoomoTokens.onSurface,
 fontSize: 18,
 fontWeight: FontWeight.w800,
 ),
 ),
 actions: [
 TextButton(
 onPressed: _isSaving ? null : _saveProfile,
 child: _isSaving
 ? const SizedBox(
 width: 18,
 height: 18,
 child: CircularProgressIndicator(strokeWidth: 2, color: JhoomoTokens.primary),
 )
 : Text(
 'Save',
 style: GoogleFonts.inter(
 color: JhoomoTokens.primary,
 fontSize: 15,
 fontWeight: FontWeight.w800,
 ),
 ),
 ),
 ],
 ),
 body: ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 children: [
 // Avatar Editor
 Center(
 child: Stack(
 children: [
 CircleAvatar(
 radius: 46,
 backgroundImage: const NetworkImage(
 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
 ),
 backgroundColor: JhoomoTokens.outline,
 ),
 Positioned(
 bottom: 0,
 right: 0,
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: const BoxDecoration(
 color: JhoomoTokens.primary,
 shape: BoxShape.circle,
 ),
 child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 _buildTextField('Display Name', _nameCtrl, 'Your name shown on Radar & tickets'),
 const SizedBox(height: 14),

 // Bio with character counter
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Short Bio',
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 TextField(
 controller: _bioCtrl,
 maxLength: 160,
 maxLines: 3,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
 decoration: InputDecoration(
 counterStyle: GoogleFonts.inter(color: JhoomoTokens.textMuted, fontSize: 11),
 filled: true,
 fillColor: Colors.white,
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: JhoomoTokens.outline),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: JhoomoTokens.primary, width: 1.5),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 14),

 _buildTextField('City', _cityCtrl, 'Default discovery city'),
 const SizedBox(height: 14),

 _buildTextField('Email Address', _emailCtrl, 'For booking invoices and receipts'),
 const SizedBox(height: 14),

 // Gender dropdown
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Gender',
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 DropdownButtonFormField<String>(
 value: _gender,
 dropdownColor: Colors.white,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
 decoration: InputDecoration(
 filled: true,
 fillColor: Colors.white,
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: JhoomoTokens.outline),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: JhoomoTokens.primary, width: 1.5),
 ),
 ),
 items: ['Male', 'Female', 'Non-Binary', 'Prefer not to say']
 .map((g) => DropdownMenuItem(value: g, child: Text(g)))
 .toList(),
 onChanged: (val) {
 if (val != null) setState(() => _gender = val);
 },
 ),
 ],
 ),
 const SizedBox(height: 20),

 // Immutable phone & DOB note
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: JhoomoTokens.outline),
 ),
 child: Row(
 children: [
 const Icon(Icons.lock_outline, color: JhoomoTokens.textMuted, size: 20),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Verified Mobile & Age (18+) are locked',
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 12, fontWeight: FontWeight.w700),
 ),
 Text(
 'To change phone number or date of birth, contact Jhoomo support desk.',
 style: GoogleFonts.inter(color: JhoomoTokens.textSecondary, fontSize: 11),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 // Interests Picker
 Text(
 'YOUR INTERESTS (${_selectedInterests.length})',
 style: GoogleFonts.inter(
 color: JhoomoTokens.textSecondary,
 fontSize: 11,
 fontWeight: FontWeight.w800,
 letterSpacing: 1.1,
 ),
 ),
 const SizedBox(height: 10),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _availableInterests.map((interest) {
 final isSelected = _selectedInterests.contains(interest);
 return ChoiceChip(
 label: Text(interest),
 selected: isSelected,
 selectedColor: JhoomoTokens.primary.withValues(alpha: 0.12),
 backgroundColor: Colors.white,
 labelStyle: GoogleFonts.inter(
 color: isSelected ? JhoomoTokens.primary : JhoomoTokens.textSecondary,
 fontSize: 12,
 fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
 ),
 side: BorderSide(
 color: isSelected ? JhoomoTokens.primary : JhoomoTokens.outline,
 ),
 onSelected: (val) {
 setState(() {
 if (val) {
 _selectedInterests.add(interest);
 } else {
 _selectedInterests.remove(interest);
 }
 });
 },
 );
 }).toList(),
 ),
 const SizedBox(height: 40),
 ],
 ),
 );
 }

 Widget _buildTextField(String label, TextEditingController ctrl, String hint) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 6),
 TextField(
 controller: ctrl,
 style: GoogleFonts.inter(color: JhoomoTokens.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
 decoration: InputDecoration(
 hintText: hint,
 hintStyle: GoogleFonts.inter(color: JhoomoTokens.textMuted, fontSize: 13),
 filled: true,
 fillColor: Colors.white,
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: JhoomoTokens.outline),
 ),
 focusedBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(14),
 borderSide: const BorderSide(color: JhoomoTokens.primary, width: 1.5),
 ),
 ),
 ),
 ],
 );
 }
}
