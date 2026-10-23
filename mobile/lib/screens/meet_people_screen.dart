import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/milo_theme.dart';
import 'chat/chat_conversation_screen.dart';

class MeetPeopleScreen extends StatefulWidget {
 const MeetPeopleScreen({super.key});

 @override
 State<MeetPeopleScreen> createState() => _MeetPeopleScreenState();
}

class _MeetPeopleScreenState extends State<MeetPeopleScreen> with SingleTickerProviderStateMixin {
 late TabController _tabController;
 final List<String> _sentRequests = [];
 bool _isDeckView = false;
 int _currentCardIndex = 0;

 @override
 void initState() {
 super.initState();
 _tabController = TabController(length: 2, vsync: this);
 }

 @override
 void dispose() {
 _tabController.dispose();
 super.dispose();
 }

 void _onSwipeLike(UserModel user) {
 setState(() {
 _sentRequests.add(user.id);
 if (_currentCardIndex < MockData.discoveryProfiles.length - 1) {
 _currentCardIndex++;
 } else {
 _currentCardIndex = 0;
 }
 });

 _showMatchDialog(user);
 }

 void _onSwipePass() {
 setState(() {
 if (_currentCardIndex < MockData.discoveryProfiles.length - 1) {
 _currentCardIndex++;
 } else {
 _currentCardIndex = 0;
 }
 });
 }

 void _showMatchDialog(UserModel user) {
 showDialog(
 context: context,
 builder: (context) => BackdropFilter(
 filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
 child: Dialog(
 backgroundColor: Colors.transparent,
 insetPadding: const EdgeInsets.symmetric(horizontal: 24),
 child: Container(
 padding: const EdgeInsets.all(28),
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [MiloColors.bgSurface, MiloColors.bg],
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 ),
 borderRadius: BorderRadius.circular(32),
 border: Border.all(color: MiloColors.primaryLight, width: 1.5),
 boxShadow: [
 BoxShadow(
 color: MiloColors.primary.withValues(alpha: 0.3),
 blurRadius: 30,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.celebration_rounded, color: MiloColors.amber, size: 48),
 const SizedBox(height: 12),
 Text(
 'Vibe Connected! ',
 style: GoogleFonts.inter(
 fontSize: 22,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'You and ${user.name} both love ${user.vibes.first}!',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13),
 ),
 const SizedBox(height: 20),
 CircleAvatar(
 radius: 42,
 backgroundImage: NetworkImage(user.avatarUrl),
 ),
 const SizedBox(height: 24),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
 ),
 onPressed: () {
 Navigator.pop(context);
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => ChatConversationScreen(user: user),
 ),
 );
 },
 child: Text(
 'Say Hi ',
 style: GoogleFonts.inter(
 color: MiloColors.bg,
 fontWeight: FontWeight.w900,
 fontSize: 14,
 ),
 ),
 ),
 ),
 const SizedBox(height: 10),
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: Text(
 'Keep Browsing',
 style: GoogleFonts.inter(color: MiloColors.textMuted, fontWeight: FontWeight.w600),
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 'Meet & Vibe ',
 style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: MiloColors.textPrimary, fontSize: 20),
 ),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 'Privacy-Safe',
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.emerald),
 ),
 ),
 ],
 ),
 Text(
 'Mutual opt-in social discovery',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight),
 ),
 ],
 ),
 actions: [
 IconButton(
 icon: Icon(
 _isDeckView ? Icons.view_agenda_outlined : Icons.style_outlined,
 color: MiloColors.primaryLight,
 ),
 tooltip: 'Switch Mode',
 onPressed: () => setState(() => _isDeckView = !_isDeckView),
 ),
 ],
 bottom: TabBar(
 controller: _tabController,
 indicatorColor: MiloColors.primaryLight,
 indicatorWeight: 3,
 labelColor: MiloColors.primaryLight,
 unselectedLabelColor: MiloColors.textMuted,
 labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
 tabs: const [
 Tab(text: 'Discovery Radar'),
 Tab(text: 'Community Circles'),
 ],
 ),
 ),
 body: TabBarView(
 controller: _tabController,
 children: [
 // Tab 1: Discovery Radar (Deck / List) 
 _isDeckView ? _buildDeckView() : _buildRadarListView(),

 // Tab 2: Community Circles 
 _buildCommunityCirclesView(),
 ],
 ),
 );
 }

 Widget _buildDeckView() {
 final profiles = MockData.discoveryProfiles;
 if (profiles.isEmpty) return const SizedBox();
 final user = profiles[_currentCardIndex % profiles.length];

 return Padding(
 padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
 child: Column(
 children: [
 Expanded(
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(30),
 border: Border.all(color: MiloColors.glassBorder),
 boxShadow: [
 BoxShadow(
 color: MiloColors.primary.withValues(alpha: 0.15),
 blurRadius: 24,
 offset: const Offset(0, 8),
 ),
 ],
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(29),
 child: Stack(
 children: [
 Image.network(
 user.avatarUrl,
 height: double.infinity,
 width: double.infinity,
 fit: BoxFit.cover,
 ),
 Container(
 decoration: BoxDecoration(
 gradient: LinearGradient(
 colors: [
 Colors.transparent,
 MiloColors.bg.withValues(alpha: 0.4),
 MiloColors.bg.withValues(alpha: 0.95),
 ],
 begin: Alignment.topCenter,
 end: Alignment.bottomCenter,
 stops: const [0.3, 0.65, 1.0],
 ),
 ),
 ),
 Positioned(
 bottom: 20,
 left: 20,
 right: 20,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 '${user.name}, ${user.age}',
 style: GoogleFonts.inter(
 fontSize: 24,
 fontWeight: FontWeight.w900,
 color: Colors.white,
 ),
 ),
 if (user.isVerified) ...[
 const SizedBox(width: 6),
 const Icon(Icons.verified_rounded, size: 20, color: MiloColors.primaryLight),
 ],
 ],
 ),
 const SizedBox(height: 4),
 Row(
 children: [
 const Icon(Icons.near_me_rounded, size: 14, color: MiloColors.rose),
 const SizedBox(width: 4),
 Text(
 user.city,
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
 ),
 const SizedBox(width: 10),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.25),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: MiloColors.amber.withValues(alpha: 0.5)),
 ),
 child: Text(
 user.badgeLevel,
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.amber),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),

 // Rapido style Captain bar on swipe card
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: Colors.black.withValues(alpha: 0.55),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.star_rounded, color: MiloColors.amber, size: 15),
 const SizedBox(width: 3),
 Text(
 '${user.rating} (${user.ratingCount})',
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
 ),
 const SizedBox(width: 12),
 const Icon(Icons.handshake_rounded, color: MiloColors.primaryLight, size: 13),
 const SizedBox(width: 3),
 Text(
 '${user.meetupsCount} Meetups',
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),
 Text(
 user.bio,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, height: 1.3),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: user.vibes.map((v) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.85),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: MiloColors.primaryLight.withValues(alpha: 0.4)),
 ),
 child: Text(
 v,
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.primaryLight, fontWeight: FontWeight.w700),
 ),
 );
 }).toList(),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 const SizedBox(height: 16),
 // Action Buttons: Pass vs Like
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 _buildCircleActionButton(
 icon: Icons.close_rounded,
 color: MiloColors.rose,
 size: 60,
 onTap: _onSwipePass,
 ),
 const SizedBox(width: 28),
 _buildCircleActionButton(
 icon: Icons.star_rounded,
 color: MiloColors.amber,
 size: 48,
 onTap: () {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Super Vibe Sent to ${user.name}! ', style: GoogleFonts.inter(color: MiloColors.amber)),
 ),
 );
 _onSwipeLike(user);
 },
 ),
 const SizedBox(width: 28),
 _buildCircleActionButton(
 icon: Icons.favorite_rounded,
 color: MiloColors.emerald,
 size: 60,
 onTap: () => _onSwipeLike(user),
 ),
 ],
 ),
 ],
 ),
 );
 }

 Widget _buildCircleActionButton({
 required IconData icon,
 required Color color,
 required double size,
 required VoidCallback onTap,
 }) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 width: size,
 height: size,
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 shape: BoxShape.circle,
 border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
 boxShadow: [
 BoxShadow(
 color: color.withValues(alpha: 0.25),
 blurRadius: 14,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Center(
 child: Icon(icon, color: color, size: size * 0.48),
 ),
 ),
 );
 }

 String _selectedMatchCategory = 'All';

 final List<String> _matchCategories = [
 'All',
 ' College Students',
 ' Office & Work',
 ' Kitty & Social',
 ' Yoga & Fitness',
 ' Standup & Comedy',
 ' Festive & Events',
 ' Couples & Dating',
 ' Seniors & Walkers',
 ];

 Widget _buildRadarListView() {
 final filteredProfiles = MockData.discoveryProfiles.where((user) {
 if (_selectedMatchCategory == 'All') return true;
 final clean = _selectedMatchCategory.replaceAll(RegExp(r'[^\w\s/&]'), '').trim();
 return user.matchCategory.toLowerCase().contains(clean.toLowerCase()) ||
 user.lookingFor.toLowerCase().contains(clean.toLowerCase());
 }).toList();

 return Column(
 children: [
 // Match Filter Chips
 SizedBox(
 height: 48,
 child: ListView.builder(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
 scrollDirection: Axis.horizontal,
 physics: const BouncingScrollPhysics(),
 itemCount: _matchCategories.length,
 itemBuilder: (context, index) {
 final cat = _matchCategories[index];
 final isSelected = _selectedMatchCategory == cat;
 return GestureDetector(
 onTap: () => setState(() => _selectedMatchCategory = cat),
 child: Container(
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: isSelected ? MiloColors.primary : MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(
 color: isSelected ? MiloColors.primaryLight : MiloColors.glassBorder,
 ),
 ),
 child: Center(
 child: Text(
 cat,
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
 color: isSelected ? MiloColors.bg : MiloColors.textSecondary,
 ),
 ),
 ),
 ),
 );
 },
 ),
 ),

 // List of Matched Profiles
 Expanded(
 child: ListView.builder(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
 itemCount: filteredProfiles.length,
 itemBuilder: (context, index) {
 final user = filteredProfiles[index];
 final isRequested = _sentRequests.contains(user.id);

 return Container(
 margin: const EdgeInsets.only(bottom: 20),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.85),
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: MiloColors.glassBorder),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.2),
 blurRadius: 16,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Padding(
 padding: const EdgeInsets.all(18),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Stack(
 children: [
 CircleAvatar(
 radius: 28,
 backgroundImage: NetworkImage(user.avatarUrl),
 ),
 if (user.isOnline)
 Positioned(
 bottom: 0,
 right: 0,
 child: Container(
 width: 14,
 height: 14,
 decoration: BoxDecoration(
 color: MiloColors.emerald,
 shape: BoxShape.circle,
 border: Border.all(color: MiloColors.bgSurface, width: 2),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 '${user.name}, ${user.age}',
 style: GoogleFonts.inter(
 fontSize: 17,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 if (user.isVerified) ...[
 const SizedBox(width: 4),
 const Icon(Icons.verified_rounded, size: 16, color: MiloColors.primaryLight),
 ],
 ],
 ),
 const SizedBox(height: 3),
 Row(
 children: [
 const Icon(Icons.location_on_rounded, size: 13, color: MiloColors.rose),
 const SizedBox(width: 3),
 Text(user.city, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12)),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 user.badgeLevel,
 style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MiloColors.amber),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),

 // Rapido Captain Trust & Metrics Bar 
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceAround,
 children: [
 Row(
 children: [
 const Icon(Icons.star_rounded, color: MiloColors.amber, size: 16),
 const SizedBox(width: 4),
 Text(
 '${user.rating}',
 style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 Text(
 ' (${user.ratingCount})',
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted),
 ),
 ],
 ),
 Container(width: 1, height: 16, color: MiloColors.border),
 Row(
 children: [
 const Icon(Icons.handshake_rounded, color: MiloColors.primaryLight, size: 14),
 const SizedBox(width: 4),
 Text(
 '${user.meetupsCount} Meetups',
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MiloColors.textPrimary),
 ),
 ],
 ),
 Container(width: 1, height: 16, color: MiloColors.border),
 Row(
 children: [
 const Icon(Icons.verified_user_rounded, color: MiloColors.emerald, size: 13),
 const SizedBox(width: 4),
 Text(
 '${user.reliabilityScore}% Match',
 style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: MiloColors.emerald),
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),

 // Looking For Intent Badge
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.primary.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.handshake_rounded, color: MiloColors.primaryLight, size: 15),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'Looking for: ${user.lookingFor}',
 style: GoogleFonts.inter(
 color: MiloColors.primaryLight,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 10),

 Text(
 user.bio,
 style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 13, height: 1.4),
 ),
 const SizedBox(height: 12),
 if (user.mutualEvent.isNotEmpty)
 Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.amber.withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.celebration_rounded, color: MiloColors.amber, size: 14),
 const SizedBox(width: 6),
 Text(
 'Also attending: ${user.mutualEvent}',
 style: GoogleFonts.inter(color: MiloColors.amber, fontSize: 11, fontWeight: FontWeight.w700),
 ),
 ],
 ),
 ),
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: user.vibes.map((vibe) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: MiloColors.border),
 ),
 child: Text(
 vibe,
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textPrimary, fontWeight: FontWeight.w600),
 ),
 );
 }).toList(),
 ),
 const Divider(color: MiloColors.border, height: 24),
 Row(
 children: [
 Expanded(
 child: ElevatedButton.icon(
 icon: Icon(
 isRequested ? Icons.hourglass_top_rounded : Icons.connect_without_contact_rounded,
 size: 16,
 color: isRequested ? MiloColors.textMuted : MiloColors.bg,
 ),
 label: Text(
 isRequested ? 'Request Sent' : 'Connect & Plan',
 style: GoogleFonts.inter(
 fontWeight: FontWeight.w800,
 color: isRequested ? MiloColors.textMuted : MiloColors.bg,
 fontSize: 13,
 ),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: isRequested ? MiloColors.bgCard : MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 ),
 onPressed: () {
 setState(() {
 if (isRequested) {
 _sentRequests.remove(user.id);
 } else {
 _sentRequests.add(user.id);
 }
 });
 },
 ),
 ),
 const SizedBox(width: 10),
 Container(
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: IconButton(
 icon: const Icon(Icons.chat_bubble_outline_rounded, color: MiloColors.primaryLight, size: 18),
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => ChatConversationScreen(user: user),
 ),
 );
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),
 ],
 );
 }

 Widget _buildCommunityCirclesView() {
 return ListView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
 children: [
 _buildCommunityCard(
 title: 'Campus Study Squad & Hackathon Hub ',
 description: 'College students matching for exam preparation, hackathon teams, and evening Chai!',
 members: 310,
 tag: 'College Students',
 color: MiloColors.cyan,
 ),
 _buildCommunityCard(
 title: 'Bangalore Remote Founders & Tech Co-workers ',
 description: 'Freelancers, remote engineers, and startup founders meeting at cafes for focused work sprints.',
 members: 285,
 tag: 'Office & Work',
 color: MiloColors.primaryLight,
 ),
 _buildCommunityCard(
 title: 'Delhi Luxury Kitty & Tambola Gala ',
 description: 'Monthly high-tea brunches, themed outfit parties, and exciting cash-prize Tambola rounds.',
 members: 190,
 tag: 'Kitty Parties',
 color: MiloColors.rose,
 ),
 _buildCommunityCard(
 title: 'Sunrise Prana Yoga & Fitness Tribe ',
 description: 'Outdoor morning yoga flows, Tibetan singing bowl sessions, and weekend 5K marathon runs.',
 members: 220,
 tag: 'Yoga & Fitness',
 color: MiloColors.emerald,
 ),
 _buildCommunityCard(
 title: 'Open Mic & Standup Comedy Enthusiasts ',
 description: 'Aspiring comedians, poets, and audience members coordinating live comedy night meetups.',
 members: 145,
 tag: 'Standup Comedy',
 color: MiloColors.amber,
 ),
 _buildCommunityCard(
 title: 'Senior Citizens Morning Walk & Chess Club ',
 description: 'Friendly morning walks, park yoga, chess, and tea stall discussions for retirees and elders.',
 members: 110,
 tag: 'Seniors & Walkers',
 color: MiloColors.textSecondary,
 ),
 _buildCommunityCard(
 title: 'Lucknow Dandiya Squad 2026 ',
 description: 'Group of 240+ Dandiya lovers coordinating passes, matching outfits, and carpooling!',
 members: 248,
 tag: 'Festive Garba',
 color: MiloColors.primaryLight,
 ),
 _buildCommunityCard(
 title: 'Mumbai Couples Date & Salsa Club ',
 description: 'Couples planning joint salsa masterclasses, weekend brunches, and bowling nights.',
 members: 95,
 tag: 'Couples & Date',
 color: MiloColors.rose,
 ),
 ],
 );
 }

 Widget _buildCommunityCard({
 required String title,
 required String description,
 required int members,
 required String tag,
 required Color color,
 }) {
 return Container(
 margin: const EdgeInsets.only(bottom: 16),
 padding: const EdgeInsets.all(18),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.85),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color),
 ),
 child: Text(tag, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
 ),
 Row(
 children: [
 const Icon(Icons.people_alt_outlined, size: 14, color: MiloColors.textMuted),
 const SizedBox(width: 4),
 Text('$members members', style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12)),
 ],
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary)),
 const SizedBox(height: 6),
 Text(description, style: GoogleFonts.inter(color: MiloColors.textSecondary, fontSize: 12, height: 1.4)),
 const SizedBox(height: 14),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 side: const BorderSide(color: MiloColors.border),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 padding: const EdgeInsets.symmetric(vertical: 10),
 ),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 backgroundColor: MiloColors.bgSurface,
 content: Text('Joined $title! ', style: GoogleFonts.inter(color: MiloColors.primaryLight)),
 ),
 );
 },
 child: Text('Join Circle', style: GoogleFonts.inter(color: MiloColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 13)),
 ),
 ),
 ],
 ),
 );
 }
}
