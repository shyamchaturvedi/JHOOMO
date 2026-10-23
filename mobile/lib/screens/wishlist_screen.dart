import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/milo_session_service.dart';
import '../services/milo_wishlist_service.dart';
import '../theme/milo_theme.dart';
import 'event_details_screen.dart';

class WishlistScreen extends StatefulWidget {
 const WishlistScreen({super.key});

 @override
 State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
 final MiloWishlistService _wishlist = MiloWishlistService.instance;
 List<EventModel> _events = [];
 bool _loading = true;

 @override
 void initState() {
 super.initState();
 _wishlist.addListener(_onChanged);
 _load();
 }

 @override
 void dispose() {
 _wishlist.removeListener(_onChanged);
 super.dispose();
 }

 void _onChanged() {
 if (mounted) _load();
 }

 Future<void> _load() async {
 await _wishlist.load(MiloSessionService.currentUid);
 final events = await _wishlist.resolveEvents();
 if (!mounted) return;
 setState(() {
 _events = events;
 _loading = false;
 });
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
 title: Text(
 'Saved Events',
 style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: JhoomoTokens.onSurface, fontSize: 18),
 ),
 ),
 body: _loading
 ? const Center(child: CircularProgressIndicator(color: MiloColors.primaryLight))
 : _events.isEmpty
 ? _buildEmpty()
 : ListView.builder(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.all(20),
 itemCount: _events.length,
 itemBuilder: (context, index) => _buildCard(_events[index]),
 ),
 );
 }

 Widget _buildEmpty() {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.favorite_border_rounded, size: 48, color: MiloColors.textMuted),
 const SizedBox(height: 14),
 Text(
 'No saved shows yet',
 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 ),
 const SizedBox(height: 6),
 Text(
 'Tap the heart on any event to save it here for later.',
 textAlign: TextAlign.center,
 style: GoogleFonts.inter(fontSize: 12, color: MiloColors.textMuted, height: 1.4),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildCard(EventModel ev) {
 return GestureDetector(
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => EventDetailsScreen(event: ev)),
 ),
 child: Container(
 margin: const EdgeInsets.only(bottom: 16),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 ClipRRect(
 borderRadius: BorderRadius.circular(14),
 child: Image.network(
 ev.imageUrl,
 width: 84,
 height: 84,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Container(width: 84, height: 84, color: MiloColors.bgCard),
 ),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 ev.title,
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 4),
 Text(
 '${ev.date.split(',').first} • ${ev.city}',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textMuted),
 ),
 const SizedBox(height: 8),
 Text(
 '₹${ev.startingPrice.toStringAsFixed(0)} onwards',
 style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: MiloColors.emerald),
 ),
 ],
 ),
 ),
 IconButton(
 icon: const Icon(Icons.favorite_rounded, color: MiloColors.rose),
 onPressed: () => _wishlist.toggle(MiloSessionService.currentUid, ev.id),
 ),
 ],
 ),
 ),
 );
 }
}
