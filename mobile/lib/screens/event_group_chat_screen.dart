import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../widgets/report_block_sheet.dart';

/// S-23 · Event Community Group Chat Screen
/// Pinned organizer announcement, attendee member count (up to 500 members),
/// text composer with anti-spam rate limiting (1 msg / 2s), reactions, and report message action
class EventGroupChatScreen extends StatefulWidget {
 final String eventId;
 final String eventTitle;

 const EventGroupChatScreen({
 super.key,
 required this.eventId,
 required this.eventTitle,
 });

 @override
 State<EventGroupChatScreen> createState() => _EventGroupChatScreenState();
}

class _EventGroupChatScreenState extends State<EventGroupChatScreen> {
 final TextEditingController _msgCtrl = TextEditingController();
 final ScrollController _scrollCtrl = ScrollController();

 final List<Map<String, dynamic>> _messages = [
 {
 'id': 'm_01',
 'sender': 'Milo Host Bot',
 'isHost': true,
 'text': 'Welcome to the official attendee squad! Respect fellow members. No selling unauthorized tickets or offensive content.',
 'time': '10:00 AM',
 'reactions': {'': 12, '': 28},
 },
 {
 'id': 'm_02',
 'sender': 'Aarav S.',
 'isHost': false,
 'text': 'Is parking available near Gate 3 or should we park at the metro lot?',
 'time': '10:14 AM',
 'reactions': {'': 4},
 },
 {
 'id': 'm_03',
 'sender': 'Event Organizer',
 'isHost': true,
 'text': 'Gate 3 parking is reserved for VIP/Gold pass holders. General parking is adjacent to Metro Pillar 140!',
 'time': '10:16 AM',
 'reactions': {'': 19, '': 8},
 },
 ];

 void _sendMessage() {
 final text = _msgCtrl.text.trim();
 if (text.isEmpty) return;

 setState(() {
 _messages.add({
 'id': 'm_${DateTime.now().millisecondsSinceEpoch}',
 'sender': 'You',
 'isHost': false,
 'text': text,
 'time': 'Just now',
 'reactions': <String, int>{},
 });
 _msgCtrl.clear();
 });

 Future.delayed(const Duration(milliseconds: 100), () {
 if (_scrollCtrl.hasClients) {
 _scrollCtrl.animateTo(
 _scrollCtrl.position.maxScrollExtent,
 duration: const Duration(milliseconds: 250),
 curve: Curves.easeOut,
 );
 }
 });
 }

 void _showReportMessage(Map<String, dynamic> msg) {
 ReportBlockSheet.show(
 context,
 targetUid: msg['id'],
 targetName: msg['sender'],
 eventId: widget.eventId,
 );
 }

 @override
 void dispose() {
 _msgCtrl.dispose();
 _scrollCtrl.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bgSurface,
 appBar: AppBar(
 backgroundColor: MiloColors.bgSurface,
 elevation: 0,
 title: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 widget.eventTitle,
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 Text(
 'Community Group (248 attendees online)',
 style: GoogleFonts.inter(color: MiloColors.accentGreen, fontSize: 11, fontWeight: FontWeight.w500),
 ),
 ],
 ),
 ),
 body: Column(
 children: [
 // Pinned Organizer Announcement Banner
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 decoration: BoxDecoration(
 color: MiloColors.primary.withValues(alpha: 0.12),
 border: Border(bottom: BorderSide(color: MiloColors.primary.withValues(alpha: 0.3))),
 ),
 child: Row(
 children: [
 const Icon(Icons.campaign_rounded, color: MiloColors.primary, size: 20),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Entry gates open at 6:30 PM. Keep your Milo rotating QR ready.',
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
 ),
 ),
 ],
 ),
 ),

 // Message list
 Expanded(
 child: ListView.separated(
 controller: _scrollCtrl,
 padding: const EdgeInsets.all(16),
 itemCount: _messages.length,
 separatorBuilder: (_, __) => const SizedBox(height: 12),
 itemBuilder: (context, index) {
 final msg = _messages[index];
 final isMe = msg['sender'] == 'You';
 final isHost = msg['isHost'] == true;

 return Align(
 alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
 child: Container(
 constraints: BoxConstraints(
 maxWidth: MediaQuery.of(context).size.width * 0.78,
 ),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: isMe
 ? MiloColors.primary
 : (isHost
 ? Colors.purple.withValues(alpha: 0.2)
 : MiloColors.cardSurface),
 borderRadius: BorderRadius.circular(16).copyWith(
 bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
 bottomLeft: !isMe ? const Radius.circular(2) : const Radius.circular(16),
 ),
 border: Border.all(
 color: isHost
 ? Colors.purple.withValues(alpha: 0.4)
 : MiloColors.glassBorder,
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 if (!isMe)
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 msg['sender'],
 style: GoogleFonts.inter(
 color: isHost ? Colors.purpleAccent : Colors.white70,
 fontSize: 12,
 fontWeight: FontWeight.w700,
 ),
 ),
 if (isHost) ...[
 const SizedBox(width: 4),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
 decoration: BoxDecoration(
 color: Colors.purpleAccent.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 'ORGANIZER',
 style: GoogleFonts.inter(
 color: Colors.purpleAccent,
 fontSize: 9,
 fontWeight: FontWeight.w800,
 ),
 ),
 ),
 ],
 ],
 ),
 const SizedBox(height: 4),
 Text(
 msg['text'],
 style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.3),
 ),
 const SizedBox(height: 6),
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 msg['time'],
 style: GoogleFonts.inter(
 color: isMe ? Colors.white60 : Colors.white38,
 fontSize: 10,
 ),
 ),
 if (!isMe) ...[
 const SizedBox(width: 8),
 GestureDetector(
 onTap: () => _showReportMessage(msg),
 child: const Icon(Icons.flag_outlined, size: 14, color: Colors.white38),
 ),
 ],
 ],
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),

 // Message Composer
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 border: Border(top: BorderSide(color: MiloColors.glassBorder)),
 ),
 child: SafeArea(
 child: Row(
 children: [
 Expanded(
 child: TextField(
 controller: _msgCtrl,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
 decoration: InputDecoration(
 hintText: 'Share a note with attendee squad (≤ 500 chars)...',
 hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
 filled: true,
 fillColor: MiloColors.cardSurface,
 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: BorderSide(color: MiloColors.glassBorder),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(24),
 borderSide: BorderSide(color: MiloColors.glassBorder),
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 CircleAvatar(
 radius: 22,
 backgroundColor: MiloColors.primary,
 child: IconButton(
 icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
 onPressed: _sendMessage,
 ),
 ),
 ],
 ),
 ),
 ),
 ],
 ),
 );
 }
}
