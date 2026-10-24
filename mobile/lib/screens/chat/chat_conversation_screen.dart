import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../theme/milo_theme.dart';

class ChatConversationScreen extends StatefulWidget {
 final UserModel? user;
 final String? userName;
 final String? chatId;
 final String? peerName;
 final bool isGroup;

 const ChatConversationScreen({
 super.key,
 this.user,
 this.userName,
 this.chatId,
 this.peerName,
 this.isGroup = false,
 });

 @override
 State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
 final TextEditingController _textController = TextEditingController();
 final List<Map<String, dynamic>> _messages = [
 {
 'text': 'Hey! Are you going to the Grand Dandiya Mahotsav this Saturday? ',
 'isMe': false,
 'time': '11:15 AM',
 },
 {
 'text': 'Yes! Got my pass booked through Jhoomo. The DJ line-up looks insane! ',
 'isMe': true,
 'time': '11:18 AM',
 },
 {
 'text': 'Awesome! Let\'s coordinate and match traditional outfits with the squad. ',
 'isMe': false,
 'time': '11:20 AM',
 },
 ];

 void _sendMessage() {
 final text = _textController.text.trim();
 if (text.isEmpty) return;

 setState(() {
 _messages.add({
 'text': text,
 'isMe': true,
 'time': 'Just now',
 });
 _textController.clear();
 });
 }

 @override
 Widget build(BuildContext context) {
  final displayName = widget.user?.name ?? widget.peerName ?? widget.userName ?? 'Jhoomo Attendee';
 final avatarUrl = widget.user?.avatarUrl ??
 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';

 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: MiloColors.bgSurface.withValues(alpha: 0.9),
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: MiloColors.textPrimary),
 onPressed: () => Navigator.pop(context),
 ),
 title: Row(
 children: [
 Stack(
 children: [
 CircleAvatar(radius: 19, backgroundImage: NetworkImage(avatarUrl)),
 Positioned(
 bottom: 0,
 right: 0,
 child: Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 color: MiloColors.emerald,
 shape: BoxShape.circle,
 border: Border.all(color: MiloColors.bgSurface, width: 1.5),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 displayName,
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: MiloColors.textPrimary),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 Text(' Identity Protected • Online', style: GoogleFonts.inter(color: MiloColors.emerald, fontSize: 10, fontWeight: FontWeight.w600)),
 ],
 ),
 ),
 ],
 ),
 actions: [
 IconButton(
 icon: const Icon(Icons.shield_outlined, color: MiloColors.primaryLight),
 onPressed: () {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Safety Shield Active: Exact GPS coordinates and phone numbers are never shared.')),
 );
 },
 ),
 ],
 ),
 body: Column(
 children: [
 // Safety Banner
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface.withValues(alpha: 0.6),
 border: const Border(bottom: BorderSide(color: MiloColors.border, width: 0.5)),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.lock_rounded, size: 13, color: MiloColors.primaryLight),
 const SizedBox(width: 6),
 Text(
 '256-Bit Encrypted Jhoomo Social Vibe Chat',
 style: GoogleFonts.inter(fontSize: 11, color: MiloColors.textSecondary, fontWeight: FontWeight.w600),
 ),
 ],
 ),
 ),

 // Messages List
 Expanded(
 child: ListView.builder(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.all(20),
 itemCount: _messages.length,
 itemBuilder: (context, index) {
 final msg = _messages[index];
 final isMe = msg['isMe'] as bool;

 return Align(
 alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
 child: Container(
 margin: const EdgeInsets.only(bottom: 12),
 constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 gradient: isMe
 ? MiloGradients.primaryBrand
 : null,
 color: isMe ? null : MiloColors.bgSurface,
 borderRadius: BorderRadius.only(
 topLeft: const Radius.circular(20),
 topRight: const Radius.circular(20),
 bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
 bottomRight: isMe ? Radius.zero : const Radius.circular(20),
 ),
 border: Border.all(
 color: isMe ? Colors.transparent : MiloColors.glassBorder,
 ),
 boxShadow: [
 BoxShadow(
 color: isMe ? MiloColors.primaryGlow : Colors.black.withValues(alpha: 0.2),
 blurRadius: 10,
 offset: const Offset(0, 3),
 ),
 ],
 ),
 child: Column(
 crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
 children: [
 Text(
 msg['text'] as String,
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
 color: isMe ? MiloColors.bg : MiloColors.textPrimary,
 height: 1.35,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 msg['time'] as String,
 style: GoogleFonts.inter(
 fontSize: 10,
 color: isMe ? MiloColors.bg.withValues(alpha: 0.7) : MiloColors.textMuted,
 ),
 ),
 ],
 ),
 ),
 );
 },
 ),
 ),

 // Message Input Bar
 Container(
 padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 border: const Border(top: BorderSide(color: MiloColors.border)),
 ),
 child: SafeArea(
 top: false,
 child: Row(
 children: [
 Expanded(
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(24),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: TextField(
 controller: _textController,
 style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 14),
 decoration: InputDecoration(
 hintText: 'Plan with $displayName...',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 13),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(vertical: 12),
 ),
 onSubmitted: (_) => _sendMessage(),
 ),
 ),
 ),
 const SizedBox(width: 10),
 GestureDetector(
 onTap: _sendMessage,
 child: Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 gradient: MiloGradients.primaryBrand,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(color: MiloColors.primaryGlow, blurRadius: 10),
 ],
 ),
 child: const Icon(Icons.send_rounded, color: MiloColors.bg, size: 20),
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
