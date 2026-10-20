import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Handles Milo deep links of the form:
///   milo://m/e/<eventId>?ref=<CODE>
///   milo://m/<CODE>            (invite / referral code)
/// Captures the referral code + event id so the app can pre-apply the
/// promoter code and deep-link straight into the event page.
class MiloDeepLinkService {
  MiloDeepLinkService._();
  static final MiloDeepLinkService instance = MiloDeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  String pendingReferralCode = '';
  String pendingEventId = '';

  /// Call once from main() after Firebase init.
  Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);

      _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (e) => debugPrint('MiloDeepLink stream error: $e'),
      );
    } catch (e) {
      debugPrint('MiloDeepLink init note: $e');
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('MiloDeepLink received: $uri');
    // Expected: milo://m/<a>/<b>?ref=CODE  or  milo://m/<CODE>?ref=...
    final segments = uri.pathSegments;
    final ref = uri.queryParameters['ref']?.trim().toUpperCase() ?? '';

    if (segments.isNotEmpty && segments.first == 'e' && segments.length > 1) {
      pendingEventId = segments[1];
      if (ref.isNotEmpty) pendingReferralCode = ref;
    } else if (segments.isNotEmpty && segments.first == 'm' && segments.length > 1) {
      final code = segments[1].trim().toUpperCase();
      if (code != 'HOME') pendingReferralCode = ref.isNotEmpty ? ref : code;
    } else if (ref.isNotEmpty) {
      pendingReferralCode = ref;
    }
  }

  /// Consume the pending event id (returns and clears it).
  String takePendingEventId() {
    final id = pendingEventId;
    pendingEventId = '';
    return id;
  }

  /// Consume the pending referral code (returns and clears it).
  String takePendingReferralCode() {
    final code = pendingReferralCode;
    pendingReferralCode = '';
    return code;
  }
}
