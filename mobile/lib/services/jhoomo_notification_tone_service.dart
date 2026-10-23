import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Service providing unique auditory tones and haptics for JHOOMO Notifications.
///
/// Implements:
/// 1. Native platform sound channel playback with synthesized melodic chime.
/// 2. Rich notification vibration patterns (subtle tactile feedback).
class JhoomoNotificationToneService {
  JhoomoNotificationToneService._();
  static final JhoomoNotificationToneService instance = JhoomoNotificationToneService._();

  static const MethodChannel _channel = MethodChannel('app.jhoomo.live/notification_tone');

  /// Play the signature JHOOMO chime (dual harmonic frequency chime: 520Hz -> 780Hz)
  Future<void> playJhoomoChime({bool withHaptic = true}) async {
    try {
      if (withHaptic) {
        await HapticFeedback.mediumImpact();
      }
      // Invoke native synthesizer channel
      await _channel.invokeMethod('playJhoomoChime');
    } catch (_) {
      // Fallback to system audio tone & haptic
      try {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  /// Play tone for payment approval / pass unlocked
  Future<void> playPassUnlockedSound() async {
    try {
      await HapticFeedback.heavyImpact();
      await _channel.invokeMethod('playSuccessChime');
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }
}
