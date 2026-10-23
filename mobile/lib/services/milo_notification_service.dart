import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'milo_session_service.dart';
import 'jhoomo_notification_tone_service.dart';

/// Top-level background message handler required by FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('JHOOMO FCM Background Message: ${message.messageId} | ${message.notification?.title}');
}

class MiloNotificationService {
  MiloNotificationService._();
  static final MiloNotificationService instance = MiloNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  /// In-app notification callback so UI or SnackBar can display live alerts.
  Function(RemoteMessage)? onMessageReceived;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request Notification Permissions (critical for Android 13+ & iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Authorization Status: ${settings.authorizationStatus}');

      // 2. Set Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground: ${message.notification?.title} - ${message.notification?.body}');
        // Play signature JHOOMO chime tone
        JhoomoNotificationToneService.instance.playJhoomoChime();
        if (onMessageReceived != null) {
          onMessageReceived!(message);
        }
      });

      // 4. Message clicked / opened event
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Opened: ${message.data}');
      });

      // 5. Sync device FCM token to user profile
      await syncDeviceToken();

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });
    } catch (e) {
      debugPrint('MiloNotificationService init error: $e');
    }
  }

  /// Syncs current device's FCM token to Firestore users/{uid}/devices
  Future<void> syncDeviceToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM Device Token: $token');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = MiloSessionService.currentUid;
    if (uid.isEmpty) return;

    try {
      final deviceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(token);

      await deviceRef.set({
        'fcmToken': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Synced FCM token for UID $uid');
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }
}
