export '../services/milo_moderation_service.dart' show TargetType;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/milo_theme.dart';
import '../services/milo_moderation_service.dart';

/// S-25 · Block & Report Sheet
/// Modular bottom sheet for reporting bad actors, abusive comments, fake events, or blocking users
class ReportBlockSheet extends StatefulWidget {
  final String targetUid;
  final String targetName;
  final TargetType targetType;
  final String? eventId;

  const ReportBlockSheet({
    super.key,
    required this.targetUid,
    required this.targetName,
    this.targetType = TargetType.user,
    this.eventId,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetUid,
    required String targetName,
    TargetType targetType = TargetType.user,
    String? eventId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBlockSheet(
        targetUid: targetUid,
        targetName: targetName,
        targetType: targetType,
        eventId: eventId,
      ),
    );
  }

  @override
  State<ReportBlockSheet> createState() => _ReportBlockSheetState();
}

class _ReportBlockSheetState extends State<ReportBlockSheet> {
  final List<String> _reasons = [
    'Spam or Commercial Solicitation',
    'Abusive Words / Harassment',
    'Fake Event / Ticket Scalping',
    'Inappropriate / Explicit Content',
    'Fake Profile / Impersonation',
    'Physical Safety Threat / Illegal',
    'Other Policy Violation',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _blockAlso = true;
  bool _isSubmitting = false;

  void _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for reporting'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Record report in MiloModerationService (mirrored to Admin Dashboard & Firestore)
    await MiloModerationService.instance.submitReport(
      targetUid: widget.targetUid,
      targetName: widget.targetName,
      targetType: widget.targetType,
      reason: _selectedReason!,
      details: _detailsController.text.trim().isNotEmpty
          ? _detailsController.text.trim()
          : 'Reported via app safety sheet for ${_selectedReason!}',
    );

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: MiloColors.emerald, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Report submitted for ${widget.targetName}. Admin review in progress. ${_blockAlso && widget.targetType == TargetType.user ? "User blocked." : ""}',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MiloColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: MiloColors.glassBorder),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: MiloColors.primaryLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFE11D48), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report ${widget.targetName}',
                        style: GoogleFonts.inter(
                          color: MiloColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Confidential • Reviewed by JHOOMO Trust & Safety Team',
                        style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Reason for reporting',
              style: GoogleFonts.inter(
                color: MiloColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE11D48).withValues(alpha: 0.15),
                  backgroundColor: MiloColors.bgCard,
                  labelStyle: GoogleFonts.inter(
                    color: isSelected ? const Color(0xFFE11D48) : MiloColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFE11D48) : MiloColors.border,
                  ),
                  onSelected: (val) {
                    setState(() => _selectedReason = val ? reason : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Additional context (e.g. proof, exact message, or reason)...',
                hintStyle: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: MiloColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: MiloColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: MiloColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE11D48)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (widget.targetType == TargetType.user) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _blockAlso,
                activeColor: const Color(0xFFE11D48),
                title: Text(
                  'Also block ${widget.targetName} immediately',
                  style: GoogleFonts.inter(color: MiloColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Stops all direct chats, visibility on radar & comments',
                  style: GoogleFonts.inter(color: MiloColors.textMuted, fontSize: 11),
                ),
                onChanged: (val) => setState(() => _blockAlso = val ?? true),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Submit Report to Admin',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
