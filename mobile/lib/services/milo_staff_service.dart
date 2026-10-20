import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore persistence for gate/staff access (`staff_access`) and
/// gate check-in audit logs (`checkin_logs`).
///
/// Every method degrades gracefully: when Firestore is unreachable the
/// read methods return null/empty and the write methods return false so
/// calling screens can keep their local state working offline.
class MiloStaffService {
  static final MiloStaffService instance = MiloStaffService._();
  MiloStaffService._();

  static final Random _rng = Random.secure();

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('MiloStaff Firestore unavailable: $e');
      return null;
    }
  }

  static String generatePasscode() {
    final digits = List.generate(6, (_) => _rng.nextInt(10)).join();
    return 'GATE-$digits';
  }

  /// Fetch staff assignments, newest first. Pass [eventId] to filter.
  /// Returns null when the read fails so callers can keep fallback data.
  Future<List<Map<String, dynamic>>?> fetchStaff({String? eventId}) async {
    final db = _db;
    if (db == null) return null;
    try {
      final snap = await db
          .collection('staff_access')
          .orderBy('created_at', descending: true)
          .limit(200)
          .get();
      final rows = snap.docs
          .map((d) => <String, dynamic>{...d.data(), 'doc_id': d.id})
          .toList();
      if (eventId == null || eventId.isEmpty) return rows;
      return rows.where((r) => r['event_id'] == eventId).toList();
    } catch (e) {
      debugPrint('MiloStaff fetch note: $e');
      return null;
    }
  }

  /// Write a new staff assignment doc. Returns the doc id on success.
  Future<String?> addStaff({
    required String name,
    required String phone,
    required String eventId,
    required String eventTitle,
    required String role,
    required String gate,
    String passcode = '',
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      final ref = db.collection('staff_access').doc();
      await ref.set({
        'name': name,
        'phone': phone,
        'event_id': eventId,
        'event_title': eventTitle,
        'role': role,
        'gate': gate,
        'passcode': passcode.isNotEmpty ? passcode : generatePasscode(),
        'is_access_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('MiloStaff add note: $e');
      return null;
    }
  }

  /// Revoke access by flagging the doc (never deletes) so the audit trail
  /// and the Active/Revoked badge survive restarts.
  Future<bool> revokeStaff(String docId) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.collection('staff_access').doc(docId).set({
        'is_access_active': false,
        'revoked_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('MiloStaff revoke note: $e');
      return false;
    }
  }

  /// Find the active staff assignment matching the signed-in user
  /// (by name or phone) — used to lock the scanner to the staff gate.
  Future<Map<String, dynamic>?> activeAssignmentFor({
    required String name,
    String phone = '',
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      final snap = await db
          .collection('staff_access')
          .where('is_access_active', isEqualTo: true)
          .limit(100)
          .get();
      final normalizedPhone = _normalizePhone(phone);
      for (final d in snap.docs) {
        final row = d.data();
        final rowName = (row['name'] ?? '').toString();
        final rowPhone = _normalizePhone((row['phone'] ?? '').toString());
        if ((name.isNotEmpty && rowName == name) ||
            (normalizedPhone.isNotEmpty && rowPhone == normalizedPhone)) {
          return <String, dynamic>{...row, 'doc_id': d.id};
        }
      }
    } catch (e) {
      debugPrint('MiloStaff assignment note: $e');
    }
    return null;
  }

  Future<bool> logCheckIn({
    required String bookingRef,
    required String attendeeName,
    required String eventId,
    required String gate,
    required String staff,
    required String status,
  }) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.collection('checkin_logs').add({
        'booking_ref': bookingRef,
        'attendee_name': attendeeName,
        'event_id': eventId,
        'gate': gate,
        'staff': staff,
        'status': status,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('MiloStaff check-in log note: $e');
      return false;
    }
  }

  /// Recent check-in logs, newest first, filtered to [eventId].
  Future<List<Map<String, dynamic>>> fetchCheckInLogs(
    String eventId, {
    int limit = 30,
  }) async {
    final db = _db;
    if (db == null) return [];
    try {
      final snap = await db
          .collection('checkin_logs')
          .orderBy('created_at', descending: true)
          .limit(200)
          .get();
      final rows = snap.docs.map((d) => d.data()).toList();
      final filtered = eventId.isEmpty
          ? rows
          : rows.where((r) => r['event_id'] == eventId).toList();
      return filtered.take(limit).toList();
    } catch (e) {
      debugPrint('MiloStaff logs note: $e');
      return [];
    }
  }

  static String _normalizePhone(String p) {
    var v = p.trim().replaceAll(RegExp(r'[\s\-+]'), '');
    if (v.length == 12 && v.startsWith('91')) v = v.substring(2);
    if (v.startsWith('0')) v = v.substring(1);
    return v;
  }
}
