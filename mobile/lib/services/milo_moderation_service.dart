import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'milo_session_service.dart';
import 'payment_approval_service.dart';

enum TargetType { user, post, comment, event }

class MiloReportModel {
  final String id;
  final String reporterUid;
  final String reporterName;
  final String targetUid;
  final String targetName;
  final TargetType targetType;
  final String reason;
  final String details;
  final String severity; // 'Low' | 'Medium' | 'High (Critical)'
  final String status; // 'open' | 'investigating' | 'action_taken' | 'dismissed'
  final String timestamp;
  final int duplicateCount;
  final List<String> reporterNames;

  const MiloReportModel({
    required this.id,
    required this.reporterUid,
    required this.reporterName,
    required this.targetUid,
    required this.targetName,
    required this.targetType,
    required this.reason,
    required this.details,
    this.severity = 'Medium',
    this.status = 'open',
    required this.timestamp,
    this.duplicateCount = 1,
    this.reporterNames = const [],
  });
}

class MiloModerationService extends ChangeNotifier {
  static final MiloModerationService instance = MiloModerationService._();
  MiloModerationService._() {
    _initLocalDemoReports();
  }

  final List<MiloReportModel> _reports = [];
  final List<Map<String, dynamic>> _userSafetyNotices = [];

  List<MiloReportModel> get reports => List.unmodifiable(_reports);
  List<MiloReportModel> get openReports => _reports.where((r) => r.status == 'open').toList();
  List<Map<String, dynamic>> get userSafetyNotices => List.unmodifiable(_userSafetyNotices);

  // Prohibited abuse / illegal words dictionary (English, Hinglish & Hindi)
  static final Set<String> _abusiveWords = {
    'scam', 'fraud', 'fake ticket', 'drugs', 'ganja', 'charas', 'weapon', 'chutiya',
    'bhosdike', 'harass', 'kill', 'threat', 'nude', 'porn', 'sex', 'assault', 'terror',
    'illegal', 'black ticket', 'black market', 'gali', 'suicide', 'bomb', 'extort'
  };

  /// Check any text for toxic / abuse / illegal content automatically.
  /// Returns null if clean, or an auto-flag explanation.
  static String? checkContentSafety(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    for (final word in _abusiveWords) {
      if (lower.contains(word)) {
        return 'Detected prohibited keyword or policy violation: "$word"';
      }
    }
    return null;
  }

  void _initLocalDemoReports() {
    if (_reports.isNotEmpty) return;
    _reports.addAll([
      MiloReportModel(
        id: 'rep_101',
        reporterUid: 'u_11',
        reporterName: 'Ananya S.',
        targetUid: 'u_bad_99',
        targetName: 'Deepak R. (User Profile)',
        targetType: TargetType.user,
        reason: 'Unsolicited spam messages outside event community',
        details: 'Sent 14 unsolicited promotional DMs after Dandiya meetup and was muted by multiple attendees.',
        severity: 'Medium',
        status: 'open',
        timestamp: '15 mins ago',
        duplicateCount: 3,
        reporterNames: ['Ananya S.', 'Rohan K.', 'Kavya T.'],
      ),
      MiloReportModel(
        id: 'rep_102',
        reporterUid: 'system_ai',
        reporterName: 'Automated AI Shield',
        targetUid: 'e_fake_01',
        targetName: 'VIP Pass Black Sale (Event/Post)',
        targetType: TargetType.post,
        reason: 'Illegal ticket scalping & black market solicitation',
        details: 'AI Shield detected black market ticket sales: "DM for 50% cash off-app passes".',
        severity: 'High (Critical)',
        status: 'open',
        timestamp: '42 mins ago',
        duplicateCount: 5,
        reporterNames: ['AI Safety Bot', 'Utsav Club Staff', 'Neha M.', 'Pooja V.', 'Aman D.'],
      ),
    ]);

    _userSafetyNotices.add({
      'id': 'notice_1',
      'title': '🛡️ Community Guidelines Notice',
      'body': 'Your account is in good standing. JHOOMO enforces zero tolerance for spam, scalping, and harassment.',
      'time': 'Just now',
      'isActionRequired': false,
    });
  }

  /// Submit report from User/Community. If an item was already reported, groups them
  /// so admin sees "Reported by 4 users" (Instagram style deduplication).
  Future<void> submitReport({
    required String targetUid,
    required String targetName,
    required TargetType targetType,
    required String reason,
    required String details,
    String? reporterName,
  }) async {
    final repName = (reporterName != null && reporterName.isNotEmpty)
        ? reporterName
        : (MiloSessionService.currentUserName.isNotEmpty
            ? MiloSessionService.currentUserName
            : 'Verified Attendee');

    final repUid = MiloSessionService.currentUid.isNotEmpty ? MiloSessionService.currentUid : 'guest_reporter';

    // Check if target already has an open report
    final existingIndex = _reports.indexWhere((r) => r.targetUid == targetUid && r.status == 'open');

    if (existingIndex != -1) {
      final existing = _reports[existingIndex];
      final updatedReporters = List<String>.from(existing.reporterNames);
      if (!updatedReporters.contains(repName)) {
        updatedReporters.add(repName);
      }

      _reports[existingIndex] = MiloReportModel(
        id: existing.id,
        reporterUid: existing.reporterUid,
        reporterName: existing.reporterName,
        targetUid: existing.targetUid,
        targetName: existing.targetName,
        targetType: existing.targetType,
        reason: existing.reason,
        details: '${existing.details}\n[+ Additional Report from $repName: "$details"]',
        severity: updatedReporters.length >= 3 ? 'High (Critical)' : existing.severity,
        status: existing.status,
        timestamp: 'Just now',
        duplicateCount: updatedReporters.length,
        reporterNames: updatedReporters,
      );
    } else {
      _reports.insert(
        0,
        MiloReportModel(
          id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
          reporterUid: repUid,
          reporterName: repName,
          targetUid: targetUid,
          targetName: targetName,
          targetType: targetType,
          reason: reason,
          details: details,
          severity: reason.toLowerCase().contains('safety') || reason.toLowerCase().contains('threat') || reason.toLowerCase().contains('scalp')
              ? 'High (Critical)'
              : 'Medium',
          status: 'open',
          timestamp: 'Just now',
          duplicateCount: 1,
          reporterNames: [repName],
        ),
      );
    }

    // Attempt firestore mirror
    try {
      FirebaseFirestore.instance.collection('reports').add({
        'target_uid': targetUid,
        'target_name': targetName,
        'target_type': targetType.name,
        'reason': reason,
        'details': details,
        'reporter_name': repName,
        'reporter_uid': repUid,
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    notifyListeners();
  }

  /// Triggered automatically when abusive or illegal keyword is detected in a post/comment.
  void autoFlagAbuse({
    required String authorName,
    required String authorUid,
    required String flaggedText,
    required String detectedViolation,
    required TargetType type,
  }) {
    // 1. Send warning notice to offending user
    _userSafetyNotices.insert(0, {
      'id': 'notice_${DateTime.now().millisecondsSinceEpoch}',
      'title': '⚠️ Policy Warning: Content Flagged',
      'body': 'Your recent ${type.name} was flagged for "$detectedViolation". Repeat violations will lead to permanent account suspension.',
      'time': 'Just now',
      'isActionRequired': true,
      'flaggedText': flaggedText,
    });

    // Also inject into user's in-app notification center
    PaymentApprovalService.instance.injectDirectNotification({
      'id': 'notif-warn-${DateTime.now().millisecondsSinceEpoch}',
      'title': '⚠️ Safety Warning: Content Flagged',
      'body': 'Your recent ${type.name} was flagged by automated moderation for policy violations. Please review community guidelines.',
      'time': 'Just now',
      'type': 'safety_warning',
      'isUnread': true,
    });

    // 2. Submit high priority incident to Admin Moderation Dashboard
    submitReport(
      targetUid: authorUid,
      targetName: '$authorName (${type.name.toUpperCase()})',
      targetType: type,
      reason: 'AI Automated Flag: $detectedViolation',
      details: 'Automated filter intercepted content: "$flaggedText". User received official warning notice.',
      reporterName: 'Automated AI Shield',
    );
  }

  /// Admin Action: Dismiss Report
  void dismissReport(String reportId) {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      final r = _reports[idx];
      _reports[idx] = MiloReportModel(
        id: r.id,
        reporterUid: r.reporterUid,
        reporterName: r.reporterName,
        targetUid: r.targetUid,
        targetName: r.targetName,
        targetType: r.targetType,
        reason: r.reason,
        details: r.details,
        severity: r.severity,
        status: 'dismissed',
        timestamp: r.timestamp,
        duplicateCount: r.duplicateCount,
        reporterNames: r.reporterNames,
      );
      notifyListeners();
    }
  }

  /// Admin Action: Suspend Account / Block Content
  void takeActionSuspend(String reportId) {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      final r = _reports[idx];
      _reports[idx] = MiloReportModel(
        id: r.id,
        reporterUid: r.reporterUid,
        reporterName: r.reporterName,
        targetUid: r.targetUid,
        targetName: r.targetName,
        targetType: r.targetType,
        reason: r.reason,
        details: r.details,
        severity: r.severity,
        status: 'action_taken',
        timestamp: r.timestamp,
        duplicateCount: r.duplicateCount,
        reporterNames: r.reporterNames,
      );

      // Issue final suspension notice to target
      _userSafetyNotices.insert(0, {
        'id': 'notice_suspend_${DateTime.now().millisecondsSinceEpoch}',
        'title': '🚫 Account Restricted by Admin',
        'body': 'Your account has been restricted following verified incident reports (${r.reason}).',
        'time': 'Just now',
        'isActionRequired': true,
      });

      PaymentApprovalService.instance.injectDirectNotification({
        'id': 'notif-blocked-${DateTime.now().millisecondsSinceEpoch}',
        'title': '🚫 Account Suspended',
        'body': 'Your account or content has been suspended by administration due to repeated community violations.',
        'time': 'Just now',
        'type': 'account_blocked',
        'isUnread': true,
      });

      notifyListeners();
    }
  }
}
