import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/milo_theme.dart';
import '../../screens/bank_account_settings_screen.dart';

/// S-46 · Settlements & Payouts Screen
/// Overview cards: Upcoming Payout, Paid to Date, On Hold.
/// Event payout breakdown: Gross Sales, Platform Fee, Net Payable, T+1 settlement status, UTR numbers.
class SettlementsScreen extends StatefulWidget {
 const SettlementsScreen({super.key});

 @override
 State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
 final List<Map<String, dynamic>> _settlements = [
 {
 'id': 'stl_8192',
 'eventName': 'Dandiya Raas Mahotsav 2026',
 'gross': 185000.0,
 'fee': 9250.0, // 5% platform fee
 'net': 175750.0,
 'status': 'Paid',
 'utr': 'HDFC002891289192',
 'settledDate': '18 Oct 2026',
 },
 {
 'id': 'stl_8193',
 'eventName': 'Sunburn Arena ft. Alan Walker',
 'gross': 420000.0,
 'fee': 21000.0,
 'net': 399000.0,
 'status': 'Processing (T+1)',
 'utr': 'Pending Bank Dispatch',
 'settledDate': 'Scheduled Tomorrow',
 },
 {
 'id': 'stl_8194',
 'eventName': 'Standup Comedy Night - Zakir Live',
 'gross': 65000.0,
 'fee': 3250.0,
 'net': 61750.0,
 'status': 'On Hold (Awaiting Event End)',
 'utr': 'Disbursed 24h post-event',
 'settledDate': '24 Oct 2026',
 },
 ];

 void _downloadStatement() {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Downloading GST Settlement Statement (PDF / CSV)...'),
 backgroundColor: MiloColors.accentGreen,
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
 'Settlements & Payouts',
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 18,
 fontWeight: FontWeight.w700,
 ),
 ),
 actions: [
 IconButton(
 icon: const Icon(Icons.download_rounded, color: Colors.white),
 tooltip: 'Download Statement',
 onPressed: _downloadStatement,
 ),
 ],
 ),
 body: ListView(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
 children: [
 // Total Cards
 Row(
 children: [
 Expanded(
 child: _buildMetricTile(
 'Upcoming Payout',
 '₹3,99,000',
 MiloColors.primaryLight,
 Icons.trending_up_rounded,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: _buildMetricTile(
 'Paid to Date',
 '₹1,75,750',
 MiloColors.accentGreen,
 Icons.account_balance_wallet_rounded,
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),

 // Bank Details Banner
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.cardSurface,
 borderRadius: BorderRadius.circular(14),
 border: Border.all(color: MiloColors.glassBorder),
 ),
 child: Row(
 children: [
 const Icon(Icons.account_balance_rounded, color: MiloColors.accentGreen, size: 22),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Direct Deposit: HDFC Bank ••••••9201',
 style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
 ),
 Text(
 'Verified via penny-drop • T+1 Escrow Auto-Release',
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
 ),
 ],
 ),
 ),
 TextButton(
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const BankAccountSettingsScreen()),
 );
 },
 child: Text(
 'Change',
 style: GoogleFonts.inter(color: MiloColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),

 Text(
 'EVENT SETTLEMENT LEDGER',
 style: GoogleFonts.inter(
 color: Colors.white38,
 fontSize: 11,
 fontWeight: FontWeight.w700,
 letterSpacing: 1.2,
 ),
 ),
 const SizedBox(height: 12),

 ..._settlements.map((s) {
 final isPaid = s['status'] == 'Paid';
 final isProcessing = s['status'].toString().contains('Processing');

 return Container(
 margin: const EdgeInsets.only(bottom: 14),
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
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Text(
 s['eventName'],
 style: GoogleFonts.inter(
 color: Colors.white,
 fontSize: 15,
 fontWeight: FontWeight.w700,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: isPaid
 ? MiloColors.accentGreen.withValues(alpha: 0.15)
 : (isProcessing
 ? Colors.blue.withValues(alpha: 0.15)
 : Colors.amber.withValues(alpha: 0.15)),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 s['status'],
 style: GoogleFonts.inter(
 color: isPaid
 ? MiloColors.accentGreen
 : (isProcessing ? Colors.blueAccent : Colors.amber),
 fontSize: 11,
 fontWeight: FontWeight.w700,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 const Divider(color: Colors.white10, height: 1),
 const SizedBox(height: 12),

 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildSubMetric('Gross Sales', '₹${s['gross'].toStringAsFixed(0)}'),
 _buildSubMetric('Platform Fee (5%)', '-₹${s['fee'].toStringAsFixed(0)}'),
 _buildSubMetric('Net Payable', '₹${s['net'].toStringAsFixed(0)}', isBold: true),
 ],
 ),
 const SizedBox(height: 12),

 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Settlement: ${s['settledDate']}',
 style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
 ),
 Text(
 'UTR: ${s['utr']}',
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
 ),
 ],
 ),
 ],
 ),
 );
 }),
 ],
 ),
 );
 }

 Widget _buildMetricTile(String title, String value, Color color, IconData icon) {
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
 Icon(icon, color: color, size: 18),
 const SizedBox(width: 8),
 Text(
 title,
 style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 value,
 style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
 ),
 ],
 ),
 );
 }

 Widget _buildSubMetric(String label, String value, {bool isBold = false}) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
 ),
 const SizedBox(height: 2),
 Text(
 value,
 style: GoogleFonts.inter(
 color: isBold ? MiloColors.accentGreen : Colors.white70,
 fontSize: 13,
 fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
 ),
 ),
 ],
 );
 }
}
