import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

class StaffDeepLinkData {
  final String eventId;
  final String staffId;
  final String? gateName;
  final String? eventName;

  StaffDeepLinkData({
    required this.eventId,
    required this.staffId,
    this.gateName,
    this.eventName,
  });
}

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StaffDeepLinkData? _pendingInvite;
  StaffDeepLinkData? get pendingInvite => _pendingInvite;

  Future<void> init(Function(StaffDeepLinkData data) onLinkReceived) async {
    try {
      // 1. Check initial link if app was opened via link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        final parsed = _parseUri(initialUri);
        if (parsed != null) {
          _pendingInvite = parsed;
          onLinkReceived(parsed);
        }
      }

      // 2. Listen to ongoing incoming links
      _appLinks.uriLinkStream.listen((uri) {
        final parsed = _parseUri(uri);
        if (parsed != null) {
          _pendingInvite = parsed;
          onLinkReceived(parsed);
        }
      });
    } catch (e) {
      debugPrint('DeepLinkService error: $e');
    }
  }

  StaffDeepLinkData? _parseUri(Uri uri) {
    // Expected formats:
    // https://jhoomo.in/staff/join?eventId=e1&staffId=st123&gate=Gate1
    // jhoomo-scanner://join?eventId=e1&staffId=st123
    final query = uri.queryParameters;
    final eventId = query['eventId'] ?? query['event'];
    final staffId = query['staffId'] ?? query['staff'];

    if (eventId != null && staffId != null) {
      return StaffDeepLinkData(
        eventId: eventId,
        staffId: staffId,
        gateName: query['gate'] ?? 'Main Gate',
        eventName: query['eventName'] ?? 'Live Event',
      );
    }
    return null;
  }
}
