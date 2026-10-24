import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'staff_auth_service.dart';

enum ScanStatus {
  valid,
  alreadyCheckedIn,
  invalid,
  wrongEvent,
  expired,
}

class ScanResult {
  final ScanStatus status;
  final String message;
  final String ticketId;
  final String attendeeName;
  final String tier;
  final String scannedAt;

  ScanResult({
    required this.status,
    required this.message,
    required this.ticketId,
    required this.attendeeName,
    required this.tier,
    required this.scannedAt,
  });
}

class GateScanService {
  GateScanService._();
  static final GateScanService instance = GateScanService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Set<String> _locallyAdmittedTickets = <String>{};
  int _todayScanCount = 0;
  int get todayScanCount => _todayScanCount;

  static const String _admittedListKey = 'jhoomo_admitted_tickets_v1';

  Future<void> init() async {
    try {
      final raw = await _storage.read(key: _admittedListKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _locallyAdmittedTickets.addAll(list.map((e) => e.toString()));
        _todayScanCount = _locallyAdmittedTickets.length;
      }
    } catch (e) {
      debugPrint('GateScanService init error: $e');
    }
  }

  Future<ScanResult> validateTicket({
    required String rawPayload,
    required StaffAuthSession session,
  }) async {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // 1. Parse Payload
    String ticketId = rawPayload.trim();
    String attendeeName = 'Verified Guest';
    String tier = 'General Pass';

    if (rawPayload.contains('|')) {
      final parts = rawPayload.split('|');
      ticketId = parts[0].trim();
      if (parts.length > 1 && parts[1].isNotEmpty) attendeeName = parts[1].trim();
      if (parts.length > 2 && parts[2].isNotEmpty) tier = parts[2].trim();
    } else if (rawPayload.startsWith('JHOOMO-') || rawPayload.startsWith('TICK-')) {
      ticketId = rawPayload.trim();
    }

    // 2. Local Duplicate Prevention (Instant 0ms latency check)
    if (_locallyAdmittedTickets.contains(ticketId)) {
      return ScanResult(
        status: ScanStatus.alreadyCheckedIn,
        message: 'Already Checked In at Gate',
        ticketId: ticketId,
        attendeeName: attendeeName,
        tier: tier,
        scannedAt: timeStr,
      );
    }

    // 3. Online Verification Check with Backend Function
    try {
      final Uri url = Uri.parse('https://asia-south1-jhoomo-prod.cloudfunctions.net/gateCheckIn');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'payload': rawPayload,
            'deviceId': session.deviceId,
            'sessionId': session.sessionId ?? 'offline',
          }
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final result = body['result'] ?? {};
        if (result['alreadyCheckedIn'] == true) {
          _locallyAdmittedTickets.add(ticketId);
          return ScanResult(
            status: ScanStatus.alreadyCheckedIn,
            message: 'Already Checked In at ${result['gate'] ?? 'Gate'}',
            ticketId: ticketId,
            attendeeName: result['attendeeName'] ?? attendeeName,
            tier: result['tier'] ?? tier,
            scannedAt: timeStr,
          );
        }
      }
    } catch (e) {
      debugPrint('Online scan check fallback to offline instant admission: $e');
    }

    // 4. Mark Admitted
    _locallyAdmittedTickets.add(ticketId);
    _todayScanCount++;
    await _storage.write(
      key: _admittedListKey,
      value: jsonEncode(_locallyAdmittedTickets.toList()),
    );

    return ScanResult(
      status: ScanStatus.valid,
      message: 'Entry Approved • Welcome!',
      ticketId: ticketId,
      attendeeName: attendeeName,
      tier: tier,
      scannedAt: timeStr,
    );
  }
}
