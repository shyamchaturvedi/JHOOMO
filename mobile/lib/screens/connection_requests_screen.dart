import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';

/// S-20 · Connection Requests Screen
/// Tabs: Received · Sent with sender summary, icebreaker, Accept / Decline actions
class ConnectionRequestsScreen extends StatefulWidget {
 const ConnectionRequestsScreen({super.key});

 @override
 State<ConnectionRequestsScreen> createState() => _ConnectionRequestsScreenState();
}

class _ConnectionRequestsScreenState extends State<ConnectionRequestsScreen>
 with SingleTickerProviderStateMixin {
 late TabController _tabController;

 // Mock initial requests
 final List<Map<String, dynamic>> _receivedRequests = [
 {
 'id': 'req_001',
 'fromUid': 'usr_aarav_sharma',
 'name': 'Aarav Sharma',
 'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
 'ageBand': '21-25',
 'eventName': 'Sunburn Arena ft. Alan Walker',
 'icebreaker': 'Hey! Also heading to Sunburn Arena, are you going with a squad or solo?',
 'mutualInterests': ['EDM', 'Festivals', 'Nightlife'],
 'time': '10m ago',
 'isVerified': true,
 },
 {
 'id': 'req_002',
 'fromUid': 'usr_priya_patel',
 'name': 'Priya Patel',
 'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
 'ageBand': '23-27',
 'eventName': 'Dandiya Raas Mahotsav 2026',
 'icebreaker': 'Need a garba partner for the pass rounds! Let me know if you want to team up.',
 'mutualInterests': ['Garba', 'Folk Dance'],
 'time': '2h ago',
 'isVerified': true,
 },
 ];

 final List<Map<String, dynamic>> _sentRequests = [
 {
 'id': 'req_003',
 'toUid': 'usr_rohan_verma',
 'name': 'Rohan V.',
 'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
 'ageBand': '22-26',
 'eventName': 'Standup Comedy Special - Zakir',
 'time': '1d ago',
 'status': 'Pending',
 },
 ];

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

 void _handleAccept(Map<String, dynamic> req) {
 setState(() {
 _receivedRequests.removeWhere((r) => r['id'] == req['id']);
 });
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Accepted connection with ${req['name']}! Direct chat unlocked.'),
 backgroundColor: MiloColors.accentGreen,
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 void _handleDecline(Map<String, dynamic> req) {
 setState(() {
 _receivedRequests.removeWhere((r) => r['id'] == req['id']);
 });
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Request declined quietly.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: MiloColors.bgSurface,
 appBar: AppBar(
 backgroundColor: MiloColors.bgSurface,
 elevation: 0,
 title: Text(
 'Connection Requests',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 bottom: TabBar(
 controller: _tabController,
 indicatorColor: MiloColors.primary,
 indicatorWeight: 3,
 labelColor: MiloColors.primary,
 unselectedLabelColor: Colors.white60,
 labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
 tabs: [
 Tab(text: 'Received (${_receivedRequests.length})'),
 Tab(text: 'Sent (${_sentRequests.length})'),
 ],
 ),
 ),
 body: TabBarView(
 controller: _tabController,
 children: [
 _buildReceivedTab(),
 _buildSentTab(),
 ],
 ),
 );
 }

 Widget _buildReceivedTab() {
 if (_receivedRequests.isEmpty) {
 return Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.white24),
 const SizedBox(height: 16),
 Text(
 'No pending requests',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'People you match with on Radar will appear here',
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
 ),
 ],
 ),
 );
 }

 return ListView.separated(
 padding: const EdgeInsets.all(16),
 itemCount: _receivedRequests.length,
 separatorBuilder: (_, __) => const SizedBox(height: 14),
 itemBuilder: (context, index) {
 final req = _receivedRequests[index];
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.cardSurface,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 CircleAvatar(
 radius: 24,
 backgroundImage: NetworkImage(req['avatar']),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 req['name'],
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 16,
 fontWeight: FontWeight.w700,
 ),
 ),
 if (req['isVerified'] == true) ...[
 const SizedBox(width: 4),
 const Icon(Icons.verified, size: 16, color: MiloColors.accentGreen),
 ],
 const SizedBox(width: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: Colors.white10,
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 req['ageBand'],
 style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
 ),
 ),
 ],
 ),
 const SizedBox(height: 3),
 Text(
 'Event: ${req['eventName']}',
 style: GoogleFonts.inter(
 color: MiloColors.primary,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Text(
 req['time'],
 style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
 ),
 ],
 ),
 if (req['icebreaker'] != null) ...[
 const SizedBox(height: 12),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.black26,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: Colors.white10),
 ),
 child: Text(
 '"${req['icebreaker']}"',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 13,
 fontStyle: FontStyle.italic,
 ),
 ),
 ),
 ],
 const SizedBox(height: 14),
 Row(
 children: [
 Expanded(
 child: OutlinedButton(
 onPressed: () => _handleDecline(req),
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white70,
 side: const BorderSide(color: Colors.white24),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(vertical: 10),
 ),
 child: const Text('Decline'),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton(
 onPressed: () => _handleAccept(req),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 padding: const EdgeInsets.symmetric(vertical: 10),
 elevation: 0,
 ),
 child: const Text('Accept'),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 },
 );
 }

 Widget _buildSentTab() {
 if (_sentRequests.isEmpty) {
 return Center(
 child: Text(
 'No sent requests',
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
 ),
 );
 }

 return ListView.separated(
 padding: const EdgeInsets.all(16),
 itemCount: _sentRequests.length,
 separatorBuilder: (_, __) => const SizedBox(height: 12),
 itemBuilder: (context, index) {
 final req = _sentRequests[index];
 return Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.cardSurface,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 CircleAvatar(
 radius: 20,
 backgroundImage: NetworkImage(req['avatar']),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 req['name'],
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 15,
 fontWeight: FontWeight.w600,
 ),
 ),
 Text(
 req['eventName'],
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.amber.withOpacity(0.15),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: Colors.amber.withOpacity(0.4)),
 ),
 child: Text(
 req['status'],
 style: GoogleFonts.inter(
 color: Colors.amber,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 );
 },
 );
 }
}
