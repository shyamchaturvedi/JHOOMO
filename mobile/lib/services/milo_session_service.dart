import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum MiloRole {
 customer,
 organizer,
 promoter,
 staff,
 admin,
}

class MiloSessionService {
 static const _storage = FlutterSecureStorage();
 static const String _keyIsLoggedIn = 'milo_is_logged_in';
 static const String _keyUserRole = 'milo_user_role';
 static const String _keyUserName = 'milo_user_name';
 static const String _keyUserPhone = 'milo_user_phone';
 static const String _keyUserUid = 'milo_user_uid';

 static final ValueNotifier<MiloRole?> currentRoleNotifier = ValueNotifier<MiloRole?>(null);
 static final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('');

 static String currentUid = '';
 static String currentUserName = '';
 static String currentUserPhone = '';

 /// Initialize session on app startup
 static Future<void> initSession() async {
 try {
 final isLoggedIn = await _storage.read(key: _keyIsLoggedIn);
 if (isLoggedIn == 'true') {
 final roleStr = await _storage.read(key: _keyUserRole);
 final role = _stringToRole(roleStr);
 currentRoleNotifier.value = role;
 isLoggedInNotifier.value = true;
 currentUid = await _storage.read(key: _keyUserUid) ?? '';
 currentUserName = await _storage.read(key: _keyUserName) ?? '';
        userNameNotifier.value = currentUserName;
 currentUserPhone = await _storage.read(key: _keyUserPhone) ?? '';
 } else {
 currentRoleNotifier.value = null;
 isLoggedInNotifier.value = false;
 }
 } catch (e) {
 debugPrint('MiloSessionService init error: $e');
 }
 }

 /// Save login session with specific role
 static Future<void> saveLoginSession({
 required MiloRole role,
 required String name,
 required String phone,
 String uid = '',
 }) async {
 try {
 await _storage.write(key: _keyIsLoggedIn, value: 'true');
 await _storage.write(key: _keyUserRole, value: role.name);
 await _storage.write(key: _keyUserName, value: name);
      userNameNotifier.value = name;
      currentUserName = name;
 await _storage.write(key: _keyUserPhone, value: phone);
 if (uid.isNotEmpty) {
 await _storage.write(key: _keyUserUid, value: uid);
 }

 currentRoleNotifier.value = role;
 isLoggedInNotifier.value = true;
 currentUid = uid.isNotEmpty ? uid : currentUid;
 currentUserName = name;
 currentUserPhone = phone;
 } catch (e) {
 debugPrint('Save session error: $e');
 }
 }

 /// Update only the role (used when Firestore role differs from cached role)
 static Future<void> updateRole(MiloRole role) async {
 await _storage.write(key: _keyUserRole, value: role.name);
 currentRoleNotifier.value = role;
 }

 static MiloRole get currentRole => currentRoleNotifier.value ?? MiloRole.customer;

 /// Switch user role (e.g. Organizer switching to Customer preview)
 static Future<void> switchRole(MiloRole newRole) async {
 await _storage.write(key: _keyUserRole, value: newRole.name);
 currentRoleNotifier.value = newRole;
 }

 /// Logout and clear storage
 static Future<void> logout() async {
 await _storage.deleteAll();
 currentRoleNotifier.value = null;
 isLoggedInNotifier.value = false;
 currentUid = '';
 currentUserName = '';
 currentUserPhone = '';
 }

 static MiloRole _stringToRole(String? val) {
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
 default:
 return MiloRole.customer;
 }
 }

 static String getRoleDisplayName(MiloRole role) {
 switch (role) {
 case MiloRole.customer:
 return 'Customer / Attendee ';
 case MiloRole.organizer:
 return 'Event Organizer ';
 case MiloRole.promoter:
 return 'Influencer & Promoter ';
 case MiloRole.staff:
 return 'Gate Security / Staff ';
 case MiloRole.admin:
 return 'Super Admin ';
 }
 }
}
