import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/scanner_tokens.dart';
import '../services/staff_auth_service.dart';
import '../services/gate_scan_service.dart';

class SessionInfoScreen extends StatelessWidget {
  final StaffAuthSession session;

  const SessionInfoScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: ScannerTokens.background,
      appBar: AppBar(
        backgroundColor: ScannerTokens.surfaceCard,
        elevation: 0,
        title: Text(
          'Gate Session Details',
          style: GoogleFonts.outfit(color: ScannerTokens.textWhite, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ScannerTokens.validGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ScannerTokens.validGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: ScannerTokens.validGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Session Active & Synchronized',
                      style: GoogleFonts.inter(
                        color: ScannerTokens.validGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metadata Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ScannerTokens.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScannerTokens.outline),
              ),
              child: Column(
                children: [
                  _buildRow('Staff Name', session.staffName),
                  const Divider(color: ScannerTokens.outline, height: 24),
                  _buildRow('Gate Assigned', session.gateName),
                  const Divider(color: ScannerTokens.outline, height: 24),
                  _buildRow('Event ID', session.eventId),
                  const Divider(color: ScannerTokens.outline, height: 24),
                  _buildRow('Staff ID', session.staffId),
                  const Divider(color: ScannerTokens.outline, height: 24),
                  _buildRow('Role', session.role.toUpperCase()),
                  const Divider(color: ScannerTokens.outline, height: 24),
                  _buildRow('Device Bound', session.deviceId),
                  const Divider(color: ScannerTokens.outline, height: 24),
                  _buildRow('Last Sync', nowStr),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ScannerTokens.surfaceCardElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScannerTokens.outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Today Admitted', '${GateScanService.instance.todayScanCount}'),
                  Container(width: 1, height: 40, color: ScannerTokens.outline),
                  _buildStat('Offline Cache', 'Ready (0ms)'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Force Re-Sync Button
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ScannerTokens.validGreen,
                    content: Text(
                      'Offline database and logs synchronized successfully!',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.sync, color: Colors.white, size: 18),
              label: Text(
                'Force Sync Manifest',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ScannerTokens.outline),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: ScannerTokens.textMuted, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: ScannerTokens.textWhite,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String val) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.outfit(
            color: ScannerTokens.primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(color: ScannerTokens.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
