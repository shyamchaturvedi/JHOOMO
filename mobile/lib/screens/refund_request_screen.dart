import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../models/models.dart';

/// S-16 · Cancellation & Refund Request Screen
class RefundRequestScreen extends StatefulWidget {
 final BookedTicket ticket;

 const RefundRequestScreen({super.key, required this.ticket});

 @override
 State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
 String _selectedReason = '';
 final _noteController = TextEditingController();
 bool _isLoading = false;
 bool _submitted = false;

 final List<String> _reasons = [
 'Plan changed',
 'Duplicate purchase',
 'Can\'t attend',
 'Found a better price',
 'Event information misleading',
 'Other',
 ];

 @override
 void dispose() {
 _noteController.dispose();
 super.dispose();
 }

 Future<void> _submitRefund() async {
 if (_selectedReason.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Please select a reason')),
 );
 return;
 }
 setState(() => _isLoading = true);
 await Future.delayed(const Duration(seconds: 2)); // Simulate API call
 if (mounted) {
 setState(() {
 _isLoading = false;
 _submitted = true;
 });
 }
 }

 @override
 Widget build(BuildContext context) {
 final ticket = widget.ticket;

 return Scaffold(
 backgroundColor: MiloColors.bg,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 title: Text(
 'Cancel & Refund',
 style: GoogleFonts.outfit(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 leading: IconButton(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MiloColors.textPrimary),
 ),
 ),
 body: _submitted ? _buildSuccess() : _buildForm(ticket),
 );
 }

 Widget _buildSuccess() {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(32),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 80,
 height: 80,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: MiloColors.emerald.withValues(alpha: 0.15),
 border: Border.all(color: MiloColors.emerald.withValues(alpha: 0.4)),
 ),
 child: const Icon(Icons.check_circle_outline_rounded,
 color: MiloColors.emerald, size: 44),
 ),
 const SizedBox(height: 20),
 Text(
 'Refund Requested!',
 style: GoogleFonts.outfit(
 fontSize: 24,
 fontWeight: FontWeight.w900,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 10),
 Text(
 'Your refund request has been submitted.\nRefunds typically take 5–7 business days.',
 style: GoogleFonts.inter(
 fontSize: 14,
 color: MiloColors.textSecondary,
 height: 1.6,
 ),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 32),
 // Refund tracker
 _RefundTracker(step: 1),
 const SizedBox(height: 32),
 SizedBox(
 width: double.infinity,
 height: 52,
 child: ElevatedButton(
 onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 child: Text(
 'Back to Home',
 style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildForm(BookedTicket ticket) {
 return SingleChildScrollView(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Booking summary
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 ticket.event.title,
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 '${ticket.tier.name} × ${ticket.quantity} • ${ticket.event.date}',
 style: GoogleFonts.inter(fontSize: 13, color: MiloColors.textSecondary),
 ),
 ],
 ),
 ),
 Text(
 '₹${ticket.totalAmount.toStringAsFixed(0)}',
 style: GoogleFonts.outfit(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: MiloColors.primaryLight,
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 20),

 // Refund policy
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: MiloColors.amber.withValues(alpha: 0.3)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Icons.info_outline_rounded, color: MiloColors.amber, size: 18),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 'Full refund available until 24 hours before the event.\nConvenience fee is non-refundable.',
 style: GoogleFonts.inter(
 fontSize: 13,
 color: MiloColors.amber,
 height: 1.5,
 ),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 24),

 Text(
 'Reason for cancellation',
 style: GoogleFonts.inter(
 fontSize: 14,
 fontWeight: FontWeight.w700,
 color: MiloColors.textPrimary,
 ),
 ),
 const SizedBox(height: 12),

 // Reason chips
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _reasons.map((r) {
 final isSelected = _selectedReason == r;
 return GestureDetector(
 onTap: () => setState(() => _selectedReason = r),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: isSelected
 ? MiloColors.primary.withValues(alpha: 0.15)
 : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: isSelected
 ? MiloColors.primary
 : MiloColors.border,
 width: isSelected ? 1.5 : 1,
 ),
 ),
 child: Text(
 r,
 style: GoogleFonts.inter(
 fontSize: 13,
 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
 color: isSelected ? MiloColors.primaryLight : MiloColors.textSecondary,
 ),
 ),
 ),
 );
 }).toList(),
 ),

 if (_selectedReason == 'Other') ...[
 const SizedBox(height: 16),
 TextField(
 controller: _noteController,
 style: GoogleFonts.inter(fontSize: 14, color: MiloColors.textPrimary),
 maxLines: 3,
 maxLength: 200,
 decoration: InputDecoration(
 hintText: 'Tell us more (optional)',
 hintStyle: GoogleFonts.inter(color: MiloColors.textMuted),
 filled: true,
 fillColor: MiloColors.bgCard,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide(color: MiloColors.border),
 ),
 enabledBorder: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide(color: MiloColors.border),
 ),
 counterStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
 ),
 ),
 ],

 const SizedBox(height: 24),

 // Refund amount breakdown
 Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(color: MiloColors.border),
 ),
 child: Column(
 children: [
 _RefundRow(label: 'Ticket amount', amount: ticket.totalAmount),
 _RefundRow(label: 'Platform fee (non-refundable)', amount: -(ticket.totalAmount * 0.05)),
 const Divider(color: Color(0x20FFFFFF), height: 20),
 _RefundRow(
 label: 'Estimated refund',
 amount: ticket.totalAmount * 0.95,
 isTotal: true,
 ),
 ],
 ),
 ),

 const SizedBox(height: 28),

 SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton(
 onPressed: _selectedReason.isNotEmpty && !_isLoading ? _submitRefund : null,
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 disabledBackgroundColor: MiloColors.bgCard,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
 ),
 child: _isLoading
 ? const SizedBox(
 width: 22, height: 22,
 child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
 )
 : Text(
 'Confirm Refund Request',
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: _selectedReason.isNotEmpty ? Colors.white : MiloColors.textMuted,
 ),
 ),
 ),
 ),
 const SizedBox(height: 32),
 ],
 ),
 );
 }
}

class _RefundRow extends StatelessWidget {
 final String label;
 final double amount;
 final bool isTotal;

 const _RefundRow({required this.label, required this.amount, this.isTotal = false});

 @override
 Widget build(BuildContext context) => Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 label,
 style: GoogleFonts.inter(
 fontSize: isTotal ? 14 : 13,
 fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
 color: isTotal ? MiloColors.textPrimary : MiloColors.textSecondary,
 ),
 ),
 Text(
 '${amount >= 0 ? '+' : ''}₹${amount.abs().toStringAsFixed(0)}',
 style: GoogleFonts.outfit(
 fontSize: isTotal ? 16 : 14,
 fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
 color: amount >= 0
 ? (isTotal ? MiloColors.emerald : MiloColors.textPrimary)
 : MiloColors.primary,
 ),
 ),
 ],
 ),
 );
}

class _RefundTracker extends StatelessWidget {
 final int step; // 0 = none, 1 = Requested, 2 = Approved, 3 = Processed, 4 = Credited

 const _RefundTracker({required this.step});

 @override
 Widget build(BuildContext context) {
 final steps = ['Requested', 'Approved', 'Processed', 'Credited'];
 return Row(
 children: List.generate(steps.length * 2 - 1, (i) {
 if (i.isOdd) {
 return Expanded(
 child: Container(
 height: 2,
 color: i ~/ 2 < step - 1
 ? MiloColors.emerald
 : MiloColors.bgCard,
 ),
 );
 }
 final s = i ~/ 2;
 final done = s < step;
 final active = s == step - 1;
 return Column(
 children: [
 Container(
 width: 28,
 height: 28,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: done
 ? MiloColors.emerald
 : active
 ? MiloColors.primary.withValues(alpha: 0.2)
 : MiloColors.bgCard,
 border: Border.all(
 color: done
 ? MiloColors.emerald
 : active
 ? MiloColors.primary
 : MiloColors.border,
 width: 1.5,
 ),
 ),
 child: Icon(
 done ? Icons.check_rounded : Icons.circle,
 size: done ? 16 : 8,
 color: done
 ? Colors.white
 : active
 ? MiloColors.primary
 : MiloColors.bgCard,
 ),
 ),
 const SizedBox(height: 4),
 Text(
 steps[s],
 style: GoogleFonts.inter(
 fontSize: 10,
 color: done || active ? MiloColors.textPrimary : MiloColors.textMuted,
 fontWeight: active ? FontWeight.w700 : FontWeight.w500,
 ),
 ),
 ],
 );
 }),
 );
 }
}
