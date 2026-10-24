import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/scanner_tokens.dart';
import '../services/staff_auth_service.dart';
import '../services/gate_scan_service.dart';
import 'login_screen.dart';
import 'session_screen.dart';

class ScannerScreen extends StatefulWidget {
  final StaffAuthSession session;

  const ScannerScreen({super.key, required this.session});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  final TextEditingController _manualInputCtrl = TextEditingController();

  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isScreenLocked = true; // Screen Lock to avoid gate staff accidentally exiting
  String _lastPayload = '';
  DateTime? _lastScannedAt;

  @override
  void initState() {
    super.initState();
    GateScanService.instance.init();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _manualInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _processScan(String payload) async {
    final now = DateTime.now();
    if (_isProcessing) return;
    if (_lastPayload == payload &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!).inSeconds < 3) {
      return; // prevent rapid repeat
    }

    setState(() {
      _isProcessing = true;
      _lastPayload = payload;
      _lastScannedAt = now;
    });

    final res = await GateScanService.instance.validateTicket(
      rawPayload: payload,
      session: widget.session,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    _showResultModal(res);
  }

  void _showResultModal(ScanResult res) {
    Color statusColor;
    IconData statusIcon;

    switch (res.status) {
      case ScanStatus.valid:
        statusColor = ScannerTokens.validGreen;
        statusIcon = Icons.check_circle_rounded;
        break;
      case ScanStatus.alreadyCheckedIn:
        statusColor = ScannerTokens.duplicateRed;
        statusIcon = Icons.warning_rounded;
        break;
      default:
        statusColor = ScannerTokens.warningAmber;
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ScannerTokens.surfaceCardElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Icon(statusIcon, color: statusColor, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                res.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: ScannerTokens.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ScannerTokens.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ScannerTokens.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.attendeeName,
                          style: GoogleFonts.outfit(
                            color: ScannerTokens.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          res.tier,
                          style: GoogleFonts.inter(
                            color: ScannerTokens.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      res.scannedAt,
                      style: GoogleFonts.inter(
                        color: ScannerTokens.textSlate,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Scan Next Guest',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualLookupDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: ScannerTokens.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Manual Ticket ID Lookup',
            style: GoogleFonts.outfit(color: ScannerTokens.textWhite, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: _manualInputCtrl,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. JHOOMO-123456',
              hintStyle: GoogleFonts.inter(color: ScannerTokens.textSlate),
              filled: true,
              fillColor: ScannerTokens.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: ScannerTokens.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final txt = _manualInputCtrl.text.trim();
                Navigator.pop(context);
                if (txt.isNotEmpty) {
                  _processScan(txt);
                  _manualInputCtrl.clear();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ScannerTokens.primary),
              child: Text('Verify', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isScreenLocked,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isScreenLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: ScannerTokens.warningAmber,
              content: Text(
                'Screen Lock is ON. Turn off Screen Lock from top right to exit.',
                style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera Stream
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final rawVal = barcode.rawValue;
                  if (rawVal != null && rawVal.isNotEmpty) {
                    _processScan(rawVal);
                    break;
                  }
                }
              },
            ),

            // Target Reticle Overlay
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isProcessing ? ScannerTokens.warningAmber : ScannerTokens.primary,
                    width: 3,
                  ),
                ),
              ),
            ),

            // Top Status & Screen Lock Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gate Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ScannerTokens.outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.meeting_room, color: ScannerTokens.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            widget.session.gateName,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Controls: Torch + Screen Lock + Logout
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            _cameraController.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn ? ScannerTokens.orange : Colors.white,
                          ),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        ),
                        const SizedBox(width: 8),
                        // Screen Lock Toggle
                        GestureDetector(
                          onTap: () {
                            setState(() => _isScreenLocked = !_isScreenLocked);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(milliseconds: 1200),
                                backgroundColor: _isScreenLocked
                                    ? ScannerTokens.validGreen
                                    : ScannerTokens.duplicateRed,
                                content: Text(
                                  _isScreenLocked ? 'Screen Lock Active' : 'Screen Lock Disabled',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isScreenLocked
                                  ? ScannerTokens.validGreen.withValues(alpha: 0.2)
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isScreenLocked ? ScannerTokens.validGreen : ScannerTokens.outline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isScreenLocked ? Icons.lock : Icons.lock_open,
                                  color: _isScreenLocked ? ScannerTokens.validGreen : Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isScreenLocked ? 'LOCKED' : 'UNLOCKED',
                                  style: GoogleFonts.inter(
                                    color: _isScreenLocked ? ScannerTokens.validGreen : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_isScreenLocked) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SessionInfoScreen(session: widget.session),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final nav = Navigator.of(context);
                              await StaffAuthService.instance.logout();
                              if (!mounted) return;
                              nav.pushReplacement(
                                MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
                              );
                            },
                            icon: const Icon(Icons.exit_to_app, color: ScannerTokens.duplicateRed),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Floating Action & Scan Count Dock
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: ScannerTokens.surfaceCard.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ScannerTokens.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TODAY ADMITTED',
                          style: GoogleFonts.inter(
                            color: ScannerTokens.textMuted,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${GateScanService.instance.todayScanCount} Guests',
                          style: GoogleFonts.outfit(
                            color: ScannerTokens.textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showManualLookupDialog,
                      icon: const Icon(Icons.dialpad, size: 16, color: Colors.white),
                      label: Text(
                        'Manual Entry',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScannerTokens.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
