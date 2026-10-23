import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../models/models.dart';
import '../widgets/report_block_sheet.dart';

/// S-19 · Radar Profile Sheet
/// Bottom sheet shown when tapping an attendee card on Meet People Radar
class RadarProfileSheet extends StatelessWidget {
 final UserModel user;

 const RadarProfileSheet({super.key, required this.user});

 static Future<void> show(BuildContext context, UserModel user) {
 return showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (_) => RadarProfileSheet(user: user),
 );
 }

 @override
 Widget build(BuildContext context) {
 return DraggableScrollableSheet(
 initialChildSize: 0.75,
 minChildSize: 0.5,
 maxChildSize: 0.92,
 builder: (_, controller) {
 return Container(
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
 border: Border.all(color: MiloColors.glassBorder, width: 1.2),
 ),
 child: ListView(
 controller: controller,
 padding: EdgeInsets.zero,
 children: [
 // Drag handle
 Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 12),
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: MiloColors.textMuted.withValues(alpha: 0.4),
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ),
 ),

 // Hero avatar + name
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24),
 child: Column(
 children: [
 Stack(
 alignment: Alignment.bottomRight,
 children: [
 CircleAvatar(
 radius: 52,
 backgroundColor: MiloColors.bgCard,
 backgroundImage: user.avatarUrl.startsWith('http')
 ? NetworkImage(user.avatarUrl)
 : null,
 child: !user.avatarUrl.startsWith('http')
 ? Text(
 user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
 style: GoogleFonts.outfit(
 fontSize: 36,
 fontWeight: FontWeight.w900,
 color: MiloColors.primaryLight,
 ),
 )
 : null,
 ),
 if (user.isVerified)
 Container(
 padding: const EdgeInsets.all(4),
 decoration: BoxDecoration(
 color: MiloColors.emerald,
 shape: BoxShape.circle,
 border: Border.all(color: MiloColors.bgSurface, width: 2),
 ),
 child: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 user.name,
 style: GoogleFonts.outfit(
 fontSize: 24,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 4),
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.primary.withValues(alpha: 0.3)),
 ),
 child: Text(
 '${user.age} yrs · ${user.city}',
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.primaryLight,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 if (user.isOnline) ...[
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(20),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 6,
 height: 6,
 decoration: const BoxDecoration(
 color: MiloColors.emerald,
 shape: BoxShape.circle,
 ),
 ),
 const SizedBox(width: 4),
 Text(
 'Online',
 style: GoogleFonts.inter(
 fontSize: 11,
 color: MiloColors.emerald,
 fontWeight: FontWeight.w700,
 ),
 ),
 ],
 ),
 ),
 ],
 ],
 ),

 if (user.bio.isNotEmpty) ...[
 const SizedBox(height: 12),
 Text(
 user.bio,
 style: GoogleFonts.inter(
 fontSize: 14,
 color: MiloColors.textSecondary,
 height: 1.5,
 ),
 textAlign: TextAlign.center,
 ),
 ],

 const SizedBox(height: 16),

 // Shared events chip
 if (user.mutualEvent.isNotEmpty)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 decoration: BoxDecoration(
 color: MiloColors.cyan.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.cyan.withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.event_rounded, size: 14, color: MiloColors.cyan),
 const SizedBox(width: 6),
 Flexible(
 child: Text(
 'Also going to: ${user.mutualEvent}',
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.cyan,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 16),

 // Interests
 Wrap(
 spacing: 8,
 runSpacing: 8,
 alignment: WrapAlignment.center,
 children: user.interests.map((interest) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: MiloColors.border),
 ),
 child: Text(
 interest,
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.textSecondary,
 fontWeight: FontWeight.w500,
 ),
 ),
 )).toList(),
 ),

 const SizedBox(height: 16),

 // Reputation metrics
 Row(
 children: [
 _MetricCard(
 value: '${user.meetupsCount}',
 label: 'Meetups',
 icon: Icons.handshake_rounded,
 color: MiloColors.gold,
 ),
 const SizedBox(width: 8),
 _MetricCard(
 value: '${user.rating}',
 label: '${user.ratingCount} Ratings',
 icon: Icons.star_rounded,
 color: MiloColors.amber,
 ),
 const SizedBox(width: 8),
 _MetricCard(
 value: '${user.reliabilityScore}%',
 label: 'Reliable',
 icon: Icons.verified_user_rounded,
 color: MiloColors.emerald,
 ),
 ],
 ),

 const SizedBox(height: 12),

 // Compliment badges
 Wrap(
 spacing: 6,
 runSpacing: 6,
 alignment: WrapAlignment.center,
 children: user.complimentBadges.map((badge) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: MiloColors.gold.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: MiloColors.gold.withValues(alpha: 0.3)),
 ),
 child: Text(
 badge,
 style: GoogleFonts.inter(
 fontSize: 11,
 color: MiloColors.gold,
 fontWeight: FontWeight.w600,
 ),
 ),
 )).toList(),
 ),

 const SizedBox(height: 24),

 // CTA buttons
 Row(
 children: [
 Expanded(
 child: ElevatedButton.icon(
 onPressed: () => _sendHello(context),
 icon: const Icon(Icons.waving_hand_rounded, size: 18),
 label: Text(
 'Send Hello',
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14),
 ),
 ),
 ),
 ),
 ],
 ),

 const SizedBox(height: 12),

 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 onPressed: () => _reportUser(context),
 icon: const Icon(Icons.flag_outlined, size: 16),
 label: Text(
 'Report',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: MiloColors.textMuted,
 side: BorderSide(color: MiloColors.textMuted.withValues(alpha: 0.3)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: OutlinedButton.icon(
 onPressed: () => _blockUser(context),
 icon: const Icon(Icons.block_rounded, size: 16),
 label: Text(
 'Block',
 style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
 ),
 style: OutlinedButton.styleFrom(
 foregroundColor: MiloColors.primary,
 side: BorderSide(color: MiloColors.primary.withValues(alpha: 0.4)),
 padding: const EdgeInsets.symmetric(vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),
 ],
 ),
 ),
 ],
 ),
 );
 },
 );
 }

 void _sendHello(BuildContext context) {
 Navigator.pop(context);
 showDialog(
 context: context,
 builder: (_) => AlertDialog(
 backgroundColor: MiloColors.bgSurface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
 title: Text(
 'Say Hello! ',
 style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: MiloColors.textPrimary),
 ),
 content: Text(
 'Your hello request has been sent to ${user.name}.\nYou\'ll be notified if they accept.',
 style: GoogleFonts.inter(color: MiloColors.textSecondary),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: Text('OK', style: GoogleFonts.inter(color: MiloColors.primary, fontWeight: FontWeight.w700)),
 ),
 ],
 ),
 );
 }

 void _reportUser(BuildContext context) {
 Navigator.pop(context);
 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (_) => ReportBlockSheet(
 targetUid: user.id,
 targetName: user.name,
 ),
 );
 }

 void _blockUser(BuildContext context) {
 Navigator.pop(context);
 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (_) => ReportBlockSheet(
 targetUid: user.id,
 targetName: user.name,
 ),
 );
 }
}

class _MetricCard extends StatelessWidget {
 final String value;
 final String label;
 final IconData icon;
 final Color color;

 const _MetricCard({
 required this.value,
 required this.label,
 required this.icon,
 required this.color,
 });

 @override
 Widget build(BuildContext context) => Expanded(
 child: Container(
 padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.06),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withValues(alpha: 0.2)),
 ),
 child: Column(
 children: [
 Icon(icon, size: 16, color: color),
 const SizedBox(height: 4),
 Text(
 value,
 style: GoogleFonts.outfit(
 fontSize: 14,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 Text(
 label,
 style: GoogleFonts.inter(fontSize: 10, color: MiloColors.textMuted),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 ),
 );
}
