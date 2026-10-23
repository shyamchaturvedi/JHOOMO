import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'milo_api.dart';
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
  await ensureUserDocument();
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

  /// Create the server-owned user document if it does not exist yet.
  /// Safe to call repeatedly; the backend is idempotent.
  Future<void> ensureUserDocument() async {
  if (currentUser == null) return;
  try {
  await MiloApi.instance.bootstrapUser();
  } catch (e) {
  debugPrint('MiloAuth ensureUserDocument note: $e');
  }
  }

  /// True when the user already completed profile setup.
  Future<bool> hasProfile() async {
  await ensureUserDocument();
  final profile = await fetchProfile();
  if (profile == null) return false;
  final name = (profile['name'] ?? profile['displayName'] ?? '').toString().trim();
  return name.isNotEmpty;
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
  await ensureUserDocument();
  await db.collection('users').doc(user.uid).set({
  'name': name,
  'displayName': name,
  'city': city,
  'vibes': vibes,
  'bio': bio,
  'discoverable': true,
  'updated_at': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return null;
  } catch (e) {
  debugPrint('MiloAuth saveProfile error: $e');
  return 'Could not save profile: $e';
  }
  }

  /// Roles are owned by the server. Local role switching is allowed only for
  /// customer/staff previews or debug builds; verified upgrades go through
  /// KYC / promoter onboarding callables.
  Future<String?> upgradeRole(MiloRole role) async {
  if (role == MiloRole.customer || role == MiloRole.staff || kDebugMode) {
  await MiloSessionService.updateRole(role);
  return null;
  }
  return 'Role upgrades require verification. Complete KYC or the promoter application to continue.';
  }

  /// Resolve the effective role from Firebase custom claims first, then the
  /// server-managed `users.roles` map. Legacy client-written `role` is only
  /// trusted in debug builds.
  Future<MiloRole?> fetchRole() async {
  final user = currentUser;
  if (user != null) {
  try {
  final token = await user.getIdTokenResult(true);
  final claims = token.claims ?? const <String, dynamic>{};
  if (claims['admin'] == true) return MiloRole.admin;
  if (claims['organizer'] == true) return MiloRole.organizer;
  if (claims['promoter'] == true) return MiloRole.promoter;
  if (claims['role'] == 'gate_staff') return MiloRole.staff;
  } catch (e) {
  debugPrint('MiloAuth fetchRole claims note: $e');
  }
  }

  final profile = await fetchProfile();
  if (profile == null) return null;
  final roles = profile['roles'];
  if (roles is Map) {
  if (roles['organizer'] == true) return MiloRole.organizer;
  if (roles['promoter'] == true) return MiloRole.promoter;
  }
  if (kDebugMode) {
  return _roleFromString(profile['role']?.toString());
  }
  return MiloRole.customer;
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

  final role = await fetchRole() ?? MiloRole.customer;
  await MiloSessionService.saveLoginSession(
  role: role,
  name: (profile['name'] ?? profile['displayName'] ?? '').toString(),
  phone: (profile['phone'] ?? user.phoneNumber ?? pendingPhone).toString(),
  uid: user.uid,
  );
  return true;
 }

 /// Real Google Sign-In with Firebase Auth
 Future<UserCredential?> signInWithGoogle() async {
 final auth = _auth;
 if (auth == null) {
 throw 'Firebase is not initialized.';
 }

 try {
 final googleSignIn = GoogleSignIn(
 scopes: ['email', 'profile'],
 );
 final googleUser = await googleSignIn.signIn();
 if (googleUser == null) {
 // User cancelled the Google sign-in dialog
 return null;
 }

 final googleAuth = await googleUser.authentication;
 final credential = GoogleAuthProvider.credential(
 accessToken: googleAuth.accessToken,
 idToken: googleAuth.idToken,
 );

  final userCredential = await auth.signInWithCredential(credential);
  if (userCredential.user != null) {
  await ensureUserDocument();
  }
  return userCredential;
 } catch (e) {
 debugPrint('MiloAuth signInWithGoogle error: $e');
 rethrow;
 }
 }

 Future<void> signOut() async {
 try {
 await _auth?.signOut();
 try {
 await GoogleSignIn().signOut();
 } catch (_) {}
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
