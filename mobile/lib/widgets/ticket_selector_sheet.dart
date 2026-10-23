import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../models/models.dart';

/// S-11 · Tiered Ticket Selector Drawer
/// Bottom sheet shown from Event Details → Book Tickets CTA
class TicketSelectorSheet extends StatefulWidget {
 final EventModel event;
 final List<TicketTier> tiers;
 final Function(Map<String, int> selections) onContinue;

 const TicketSelectorSheet({
 super.key,
 required this.event,
 required this.tiers,
 required this.onContinue,
 });

 static Future<void> show(
 BuildContext context, {
 required EventModel event,
 required List<TicketTier> tiers,
 required Function(Map<String, int> selections) onContinue,
 }) {
 return showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (_) => TicketSelectorSheet(
 event: event,
 tiers: tiers,
 onContinue: onContinue,
 ),
 );
 }

 @override
 State<TicketSelectorSheet> createState() => _TicketSelectorSheetState();
}

class _TicketSelectorSheetState extends State<TicketSelectorSheet> {
 final Map<String, int> _quantities = {};
 bool _isLoading = false;

 int get _totalItems => _quantities.values.fold(0, (a, b) => a + b);

 double get _totalPrice {
 double total = 0;
 for (final tier in widget.tiers) {
 final qty = _quantities[tier.id] ?? 0;
 total += tier.price * qty;
 }
 return total;
 }

 void _increment(TicketTier tier) {
 final current = _quantities[tier.id] ?? 0;
 const maxPerOrder = 10;
 if (current < maxPerOrder && current < tier.available) {
 HapticFeedback.lightImpact();
 setState(() => _quantities[tier.id] = current + 1);
 }
 }

 void _decrement(TicketTier tier) {
 final current = _quantities[tier.id] ?? 0;
 if (current > 0) {
 HapticFeedback.lightImpact();
 setState(() => _quantities[tier.id] = current - 1);
 }
 }

 Future<void> _onContinue() async {
 if (_totalItems == 0) return;
 setState(() => _isLoading = true);
 try {
 await widget.onContinue(_quantities);
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
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
 child: Column(
 children: [
 // Drag handle
 Padding(
 padding: const EdgeInsets.symmetric(vertical: 12),
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: MiloColors.textMuted.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(4),
 ),
 ),
 ),

 // Header
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 20),
 child: Row(
 children: [
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Select Tickets',
 style: GoogleFonts.outfit(
 fontSize: 20,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 Text(
 widget.event.title,
 style: GoogleFonts.inter(
 fontSize: 13,
 color: MiloColors.textSecondary,
 ),
 ),
 ],
 ),
 const Spacer(),
 IconButton(
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Icons.close_rounded),
 color: MiloColors.textMuted,
 ),
 ],
 ),
 ),

 const Divider(color: Color(0x20FFFFFF), height: 16),

 // Tiers list
 Expanded(
 child: ListView.builder(
 controller: controller,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 itemCount: widget.tiers.length,
 itemBuilder: (_, i) {
 final tier = widget.tiers[i];
 final qty = _quantities[tier.id] ?? 0;
 final isSoldOut = tier.available == 0;
 final isSellingFast = tier.available > 0 && tier.available <= 20;

 return Container(
 margin: const EdgeInsets.only(bottom: 12),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: isSoldOut
 ? MiloColors.bgCard.withValues(alpha: 0.5)
 : qty > 0
 ? MiloColors.primary.withValues(alpha: 0.08)
 : MiloColors.bgCard,
 borderRadius: BorderRadius.circular(16),
 border: Border.all(
 color: qty > 0
 ? MiloColors.primary.withValues(alpha: 0.4)
 : MiloColors.border,
 width: 1.2,
 ),
 ),
 child: Row(
 children: [
 // Tier info
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 tier.name,
 style: GoogleFonts.inter(
 fontSize: 15,
 fontWeight: FontWeight.w700,
 color: isSoldOut
 ? MiloColors.textMuted
 : MiloColors.textPrimary,
 ),
 ),
 if (tier.description.isNotEmpty) ...[
 const SizedBox(height: 4),
 Text(
 tier.description,
 style: GoogleFonts.inter(
 fontSize: 12,
 color: MiloColors.textMuted,
 ),
 ),
 ],
 if (tier.perks.isNotEmpty) ...[
 const SizedBox(height: 4),
 Wrap(
 spacing: 4,
 children: tier.perks.take(3).map((p) => Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.emerald.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 p,
 style: GoogleFonts.inter(
 fontSize: 10,
 color: MiloColors.emerald,
 ),
 ),
 )).toList(),
 ),
 ],
 const SizedBox(height: 6),
 Row(
 children: [
 Text(
 isSoldOut
 ? 'Sold Out'
 : '₹${tier.price.toStringAsFixed(0)}',
 style: GoogleFonts.outfit(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: isSoldOut
 ? MiloColors.textMuted
 : MiloColors.primaryLight,
 ),
 ),
 const SizedBox(width: 8),
 if (isSellingFast && !isSoldOut)
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.amber.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Icons.local_fire_department_rounded,
 size: 10, color: MiloColors.amber),
 const SizedBox(width: 3),
 Text(
 'Selling Fast',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: MiloColors.amber,
 ),
 ),
 ],
 ),
 ),
 if (isSoldOut)
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: MiloColors.textMuted.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Text(
 'Sold Out',
 style: GoogleFonts.inter(
 fontSize: 10,
 fontWeight: FontWeight.w700,
 color: MiloColors.textMuted,
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),

 // Qty stepper
 if (!isSoldOut) ...[
 const SizedBox(width: 12),
 Row(
 children: [
 _StepperBtn(
 icon: Icons.remove_rounded,
 onTap: qty > 0 ? () => _decrement(tier) : null,
 ),
 SizedBox(
 width: 36,
 child: Center(
 child: Text(
 '$qty',
 style: GoogleFonts.outfit(
 fontSize: 18,
 fontWeight: FontWeight.w800,
 color: qty > 0
 ? MiloColors.primaryLight
 : MiloColors.textMuted,
 ),
 ),
 ),
 ),
 _StepperBtn(
 icon: Icons.add_rounded,
 onTap: qty < 10 && qty < tier.available
 ? () => _increment(tier)
 : null,
 ),
 ],
 ),
 ],
 ],
 ),
 );
 },
 ),
 ),

 // Footer with total + Continue
 Container(
 padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
 decoration: BoxDecoration(
 color: MiloColors.bgSurface,
 border: Border(
 top: BorderSide(color: MiloColors.glassBorder, width: 1),
 ),
 ),
 child: SafeArea(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 if (_totalItems > 0) ...[
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 '$_totalItems ticket${_totalItems > 1 ? 's' : ''}',
 style: GoogleFonts.inter(
 fontSize: 13,
 color: MiloColors.textSecondary,
 ),
 ),
 Text(
 '₹${_totalPrice.toStringAsFixed(0)} + fees',
 style: GoogleFonts.outfit(
 fontSize: 16,
 fontWeight: FontWeight.w800,
 color: MiloColors.textPrimary,
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 ],
 SizedBox(
 width: double.infinity,
 height: 54,
 child: ElevatedButton(
 onPressed: _totalItems > 0 && !_isLoading ? _onContinue : null,
 style: ElevatedButton.styleFrom(
 backgroundColor: MiloColors.primary,
 disabledBackgroundColor: MiloColors.bgCard,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(14),
 ),
 elevation: 0,
 ),
 child: _isLoading
 ? const SizedBox(
 width: 22,
 height: 22,
 child: CircularProgressIndicator(
 color: Colors.white,
 strokeWidth: 2.5,
 ),
 )
 : Text(
 _totalItems == 0 ? 'Select tickets to continue' : 'Continue →',
 style: GoogleFonts.inter(
 fontSize: 16,
 fontWeight: FontWeight.w700,
 color: _totalItems > 0
 ? Colors.white
 : MiloColors.textMuted,
 ),
 ),
 ),
 ),
 ],
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

class _StepperBtn extends StatelessWidget {
 final IconData icon;
 final VoidCallback? onTap;

 const _StepperBtn({required this.icon, required this.onTap});

 @override
 Widget build(BuildContext context) {
 final enabled = onTap != null;
 return GestureDetector(
 onTap: onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 150),
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: enabled
 ? MiloColors.primary.withValues(alpha: 0.15)
 : MiloColors.bgCard,
 border: Border.all(
 color: enabled
 ? MiloColors.primary.withValues(alpha: 0.5)
 : MiloColors.border,
 ),
 ),
 child: Icon(
 icon,
 size: 16,
 color: enabled ? MiloColors.primaryLight : MiloColors.textMuted,
 ),
 ),
 );
 }
}
