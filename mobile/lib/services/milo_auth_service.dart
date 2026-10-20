import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'milo_session_service.dart';

/// Firebase Authentication + Firestore profile service for Milo.
/// Handles real phone-OTP login, profile persistence and role resolution.
class MiloAuthService {
  static final MiloAuthService instance = MiloAuthService._();
  MiloAuthService._();

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String? _verificationId;
  String pendingPhone = '';

  User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  String get uid => currentUser?.uid ?? MiloSessionService.currentUid;

  static String normalizePhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('+91')) p = p.substring(3);
    if (p.startsWith('91') && p.length == 12) p = p.substring(2);
    if (p.startsWith('0')) p = p.substring(1);
    return p;
  }

  static String formatPhone(String phone) => '+91${normalizePhone(phone)}';

  bool get isPhoneAuthAvailable => _auth != null;

  /// Send OTP to [phone]. Returns null on success, error message otherwise.
  Future<String?> sendOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function(String message) onError,
    void Function(User user)? onAutoVerified,
  }) async {
    final auth = _auth;
    if (auth == null) {
      return 'Firebase is not configured on this device.';
    }

    final formatted = formatPhone(phone);
    pendingPhone = formatted;

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('MiloAuth: auto verification triggered');
          try {
            final result = await auth.signInWithCredential(credential);
            if (result.user != null && onAutoVerified != null) {
              onAutoVerified(result.user!);
            }
          } catch (e) {
            debugPrint('MiloAuth auto verify error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('MiloAuth verificationFailed: ${e.code} ${e.message}');
          onError(e.message ?? 'Phone verification failed. Check SHA-1 fingerprint in Firebase console.');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Unable to send OTP.';
    } catch (e) {
      return 'Unable to send OTP: $e';
    }
  }

  /// Verify the OTP. Returns null on success, error message otherwise.
  Future<String?> verifyOtp(String smsCode) async {
    final auth = _auth;
    final vid = _verificationId;
    if (auth == null) return 'Firebase is not configured on this device.';
    if (vid == null) return 'OTP session expired. Please request a new code.';

    try {
      final credential = PhoneAuthProvider.credential(verificationId: vid, smsCode: smsCode);
      final result = await auth.signInWithCredential(credential);
      if (result.user == null) return 'Verification failed. Please try again.';
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') return 'Incorrect OTP. Please try again.';
      return e.message ?? 'OTP verification failed.';
    } catch (e) {
      return 'OTP verification failed: $e';
    }
  }

  /// Load the Firestore profile for the signed-in user.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final db = _db;
    final user = currentUser;
    if (db == null || user == null) return null;
    try {
      final doc = await db.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('MiloAuth fetchProfile error: $e');
      return null;
    }
  }

  /// True when the user already completed profile setup.
  Future<bool> hasProfile() async {
    final profile = await fetchProfile();
    return profile != null && (profile['name'] ?? '').toString().isNotEmpty;
  }

  /// Create / update the user profile document in Firestore.
  Future<String?> saveProfile({
    required String name,
    required String phone,
    required int age,
    required String city,
    required MiloRole role,
    List<String> vibes = const [],
    String bio = '',
  }) async {
    final db = _db;
    final user = currentUser;
    if (db == null || user == null) return 'Not signed in.';

    try {
      await db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'phone': normalizePhone(phone),
        'age': age,
        'city': city,
        'vibes': vibes,
        'bio': bio,
        'role': role.name,
        'status': 'active',
        'discoverable': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('MiloAuth saveProfile error: $e');
      return 'Could not save profile: $e';
    }
  }

  /// Read role from Firestore. Returns null when unavailable.
  Future<MiloRole?> fetchRole() async {
    final profile = await fetchProfile();
    if (profile == null) return null;
    return _roleFromString(profile['role']?.toString());
  }

  /// Server-side admin allowlist check (milo_config/admins doc in Firestore).
  Future<bool> isPhoneAdmin({String? phone}) async {
    final db = _db;
    if (db == null) return false;
    final target = normalizePhone(phone ?? pendingPhone);
    try {
      final doc = await db.collection('milo_config').doc('admins').get();
      final data = doc.data();
      if (data == null) return false;
      final phones = List<String>.from(data['phones'] ?? [])
          .map((p) => normalizePhone(p))
          .toList();
      return phones.contains(target);
    } catch (e) {
      debugPrint('MiloAuth isPhoneAdmin error: $e');
      return false;
    }
  }

  /// Restore session from the persisted Firebase user + Firestore role.
  /// Returns true when a valid logged-in session was restored.
  Future<bool> restoreSession() async {
    final user = currentUser;
    if (user == null) return false;

    final profile = await fetchProfile();
    if (profile == null) return false;

    final role = _roleFromString(profile['role']?.toString()) ?? MiloRole.customer;
    await MiloSessionService.saveLoginSession(
      role: role,
      name: profile['name']?.toString() ?? '',
      phone: profile['phone']?.toString() ?? pendingPhone,
      uid: user.uid,
    );
    return true;
  }

  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (e) {
      debugPrint('MiloAuth signOut error: $e');
    }
  }

  MiloRole? _roleFromString(String? val) {
    switch (val) {
      case 'organizer':
        return MiloRole.organizer;
      case 'promoter':
        return MiloRole.promoter;
      case 'staff':
        return MiloRole.staff;
      case 'admin':
        return MiloRole.admin;
      case 'customer':
        return MiloRole.customer;
      default:
        return null;
    }
  }
}
