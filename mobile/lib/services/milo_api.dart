import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Error thrown by every backend callable. [code] is the stable machine code
/// (e.g. `TICKET_SOLD_OUT`) and [message] is the user-safe copy.
class MiloApiException implements Exception {
 MiloApiException(this.code, this.message, {this.details = const {}});

 final String code;
 final String message;
 final Map<String, dynamic> details;

 bool get isAuthError => code == 'UNAUTHENTICATED';
 bool get isForbidden => code == 'FORBIDDEN' || code == 'KYC_INCOMPLETE';

 @override
 String toString() => 'MiloApiException($code): $message';
}

/// Client for the Milo v4 Firebase backend.
///
/// The backend is the single source of truth for price, inventory, consent,
/// refunds and check-ins — the app never decides those locally. Every call is
/// an HTTPS callable protected by Firebase Auth + App Check.
class MiloApi {
 MiloApi._();

 static final MiloApi instance = MiloApi._();

 static const String projectId = 'milo-da65c';
 static const String region = 'asia-south1';
 static const String functionsBaseUrl = 'https://$region-$projectId.cloudfunctions.net';

 final http.Client _client = http.Client();

 FirebaseAuth get _auth => FirebaseAuth.instance;

 Future<Map<String, String>> _headers() async {
 final headers = <String, String>{
 'Content-Type': 'application/json',
 'Accept': 'application/json',
 };
 final user = _auth.currentUser;
 if (user != null) {
 headers['Authorization'] = 'Bearer ${await user.getIdToken(true)}';
 }
 try {
 final appCheck = FirebaseAppCheck.instance;
 final value = await appCheck.getToken();
 if (value != null && value.isNotEmpty) headers['X-Firebase-AppCheck'] = value;
 } catch (_) {
 // App Check is best-effort in debug builds where no provider is configured.
 }
 return headers;
 }

 /// Invokes a callable function and returns its `result` payload.
 Future<Map<String, dynamic>> call(
 String name, [
 Map<String, dynamic> data = const {},
 ]) async {
 final uri = Uri.parse('$functionsBaseUrl/$name');
 late http.Response response;
 try {
 response = await _client
 .post(uri, headers: await _headers(), body: jsonEncode({'data': data}))
 .timeout(const Duration(seconds: 30));
 } catch (err) {
 throw MiloApiException('NETWORK_ERROR', 'Could not reach Milo. Check your connection.');
 }

 Map<String, dynamic> body;
 try {
 body = jsonDecode(response.body) as Map<String, dynamic>;
 } catch (_) {
 if (response.statusCode >= 200 && response.statusCode < 300) return const {};
 throw MiloApiException('INTERNAL', 'Unexpected response from Milo.');
 }

 if (response.statusCode >= 200 && response.statusCode < 300) {
 final result = body['result'];
 if (result is Map<String, dynamic>) return result;
 return const {};
 }

 final error = body['error'];
 if (error is Map<String, dynamic>) {
 final code = (error['message'] ?? 'INTERNAL').toString();
 final details = error['details'];
 final message = details is Map && details['message'] != null
 ? details['message'].toString()
 : _humanise(code);
 throw MiloApiException(
 code,
 message,
 details: details is Map ? Map<String, dynamic>.from(details) : const {},
 );
 }

 throw MiloApiException('INTERNAL', 'Something went wrong. Please try again.');
 }

 static String _humanise(String code) {
 switch (code) {
 case 'UNAUTHENTICATED':
 return 'Please sign in to continue.';
 case 'FORBIDDEN':
 return 'You do not have access to this.';
 case 'RATE_LIMITED':
 return 'Too many attempts. Please try again later.';
 case 'INSUFFICIENT_BALANCE':
 return 'Payment failed. Please try another method.';
 default:
 return 'Something went wrong. Please try again.';
 }
 }

 // account & profile 

 Future<Map<String, dynamic>> bootstrapUser() => call('bootstrapUser');

 Future<Map<String, dynamic>> completeProfile({
 required String displayName,
 required String dobIso,
 String? cityId,
 String? gender,
 List<String> interests = const [],
 String? bio,
 }) =>
 call('completeProfile', {
 'displayName': displayName,
 'dob': dobIso,
 'cityId': cityId,
 'gender': gender,
 'interests': interests,
 'bio': bio,
 });

 Future<Map<String, dynamic>> requestAccountDeletion({String? reason}) =>
 call('requestAccountDeletion', {'reason': reason});

 Future<Map<String, dynamic>> cancelAccountDeletion() => call('cancelAccountDeletion');

 Future<Map<String, dynamic>> exportMyData() => call('exportMyData');

 Future<Map<String, dynamic>> updatePrivacy({
 bool? ghostMode,
 bool? incognitoAttendance,
 bool? mutualInterestOnly,
 bool? readReceipts,
 bool? showFaceVerifiedBadge,
 }) =>
 call('updatePrivacy', {
 if (ghostMode != null) 'ghostMode': ghostMode,
 if (incognitoAttendance != null) 'incognitoAttendance': incognitoAttendance,
 if (mutualInterestOnly != null) 'mutualInterestOnly': mutualInterestOnly,
 if (readReceipts != null) 'readReceipts': readReceipts,
 if (showFaceVerifiedBadge != null) 'showFaceVerifiedBadge': showFaceVerifiedBadge,
 });

 // events & discovery 

 Future<Map<String, dynamic>> listEvents({
 String? cityId,
 List<String> categoryIds = const [],
 DateTime? fromAt,
 DateTime? toAt,
 String sort = 'soonest',
 int limit = 20,
 String? cursor,
 }) =>
 call('listEvents', {
 'cityId': cityId,
 'categoryIds': categoryIds,
 if (fromAt != null) 'fromAt': fromAt.millisecondsSinceEpoch,
 if (toAt != null) 'toAt': toAt.millisecondsSinceEpoch,
 'sort': sort,
 'limit': limit,
 'cursor': cursor,
 });

 Future<Map<String, dynamic>> searchEvents({
 required String query,
 String? cityId,
 int limit = 20,
 }) =>
 call('searchEvents', {'query': query, 'cityId': cityId, 'limit': limit});

 Future<Map<String, dynamic>> getEventDetails(String eventId) =>
 call('getEventDetails', {'eventId': eventId});

 Future<Map<String, dynamic>> toggleWishlist(String eventId) =>
 call('toggleWishlist', {'eventId': eventId});

 Future<Map<String, dynamic>> listWishlist() => call('listWishlist');

 // booking 

 Future<Map<String, dynamic>> createBooking({
 required String eventId,
 required Map<String, int> quantities,
 String? promoCode,
 String? idempotencyKey,
 }) =>
 call('createBooking', {
 'eventId': eventId,
 'quantities': quantities,
 'promoCode': promoCode,
 'idempotencyKey': idempotencyKey,
 });

 Future<Map<String, dynamic>> applyPromo({
 required String eventId,
 required String promoCode,
 required Map<String, int> quantities,
 }) =>
 call('applyPromo', {'eventId': eventId, 'promoCode': promoCode, 'quantities': quantities});

 Future<Map<String, dynamic>> cancelPendingBooking(String bookingId) =>
 call('cancelPendingBooking', {'bookingId': bookingId});

 Future<Map<String, dynamic>> getTicketQrToken(String ticketId) =>
 call('getTicketQrToken', {'ticketId': ticketId});

 Future<Map<String, dynamic>> generateTicketPdf(String ticketId) =>
 call('generateTicketPdf', {'ticketId': ticketId});

 Future<Map<String, dynamic>> requestRefund({
 required String bookingId,
 required String reason,
 String? note,
 }) =>
 call('requestRefund', {'bookingId': bookingId, 'reason': reason, 'note': note});

 // organiser 

 Future<Map<String, dynamic>> saveKycDraft(Map<String, dynamic> draft) =>
 call('saveKycDraft', draft);

 Future<Map<String, dynamic>> submitKyc(Map<String, dynamic> submission) =>
 call('submitKyc', submission);

 Future<Map<String, dynamic>> getKycStatus() => call('getKycStatus');

 Future<Map<String, dynamic>> saveEventDraft(Map<String, dynamic> draft) =>
 call('saveEventDraft', draft);

 Future<Map<String, dynamic>> submitEventForReview(String eventId) =>
 call('submitEventForReview', {'eventId': eventId});

 Future<Map<String, dynamic>> updateLiveEvent(String eventId, Map<String, dynamic> patch) =>
 call('updateLiveEvent', {'eventId': eventId, ...patch});

 Future<Map<String, dynamic>> cancelEvent(String eventId, String reason) =>
 call('cancelEvent', {'eventId': eventId, 'reason': reason});

 Future<Map<String, dynamic>> listMyEvents() => call('listMyEvents');

 // gate 

 Future<Map<String, dynamic>> staffLogin({
 required String eventId,
 required String gate,
 required String passcode,
 }) =>
 call('staffLogin', {'eventId': eventId, 'gate': gate, 'passcode': passcode});

 Future<Map<String, dynamic>> gateCheckIn({
 required String eventId,
 required String gate,
 required String qrToken,
 String? clientScanId,
 }) =>
 call('gateCheckIn', {
 'eventId': eventId,
 'gate': gate,
 'qrToken': qrToken,
 'clientScanId': clientScanId,
 });

 Future<Map<String, dynamic>> getGateManifest(String eventId, String gate) =>
 call('getGateManifest', {'eventId': eventId, 'gate': gate});

 // radar & social 

 Future<Map<String, dynamic>> setRadarOptIn({
 required String eventId,
 required bool optedIn,
 required bool consentGranted,
 }) =>
 call('setRadarOptIn', {
 'eventId': eventId,
 'optedIn': optedIn,
 'consentGranted': consentGranted,
 });

 Future<Map<String, dynamic>> listRadarMembers({
 required String eventId,
 int limit = 20,
 String? cursor,
 }) =>
 call('listRadarMembers', {'eventId': eventId, 'limit': limit, 'cursor': cursor});

 Future<Map<String, dynamic>> sendConnectionRequest({
 required String toUid,
 required String eventId,
 String? message,
 }) =>
 call('sendConnectionRequest', {'toUid': toUid, 'eventId': eventId, 'message': message});

 Future<Map<String, dynamic>> respondConnection({
 required String connectionId,
 required bool accept,
 }) =>
 call('respondConnection', {'connectionId': connectionId, 'accept': accept});

 Future<Map<String, dynamic>> listConnections({String? status}) =>
 call('listConnections', {'status': status});

 Future<Map<String, dynamic>> blockUser(String uid, {String? reason}) =>
 call('blockUser', {'uid': uid, 'reason': reason});

 Future<Map<String, dynamic>> submitReport({
 required String targetType,
 required String targetId,
 required String reason,
 String? eventId,
 String? note,
 List<Map<String, dynamic>> evidence = const [],
 }) =>
 call('submitReport', {
 'targetType': targetType,
 'targetId': targetId,
 'reason': reason,
 'eventId': eventId,
 'note': note,
 'evidence': evidence,
 });

 Future<Map<String, dynamic>> createBeacon({
 required String eventId,
 required String title,
 required String spot,
 required DateTime meetAt,
 required int maxPeople,
 List<String> vibeTags = const [],
 String joinMode = 'open',
 }) =>
 call('createBeacon', {
 'eventId': eventId,
 'title': title,
 'spot': spot,
 'meetAt': meetAt.millisecondsSinceEpoch,
 'maxPeople': maxPeople,
 'vibeTags': vibeTags,
 'joinMode': joinMode,
 });

 Future<Map<String, dynamic>> joinBeacon(String beaconId) =>
 call('joinBeacon', {'beaconId': beaconId});

 Future<Map<String, dynamic>> listBeacons(String eventId) =>
 call('listBeacons', {'eventId': eventId});

 // chat 

 Future<Map<String, dynamic>> listChats({String? type, int limit = 30}) =>
 call('listChats', {'type': type, 'limit': limit});

 Future<Map<String, dynamic>> getChatMessages({
 required String chatId,
 int limit = 30,
 String? before,
 }) =>
 call('getChatMessages', {'chatId': chatId, 'limit': limit, 'before': before});

 Future<Map<String, dynamic>> sendMessage({
 required String chatId,
 required String clientMsgId,
 String? text,
 String? ciphertext,
 String? nonce,
 int? keyVersion,
 String type = 'text',
 }) =>
 call('sendMessage', {
 'chatId': chatId,
 'clientMsgId': clientMsgId,
 'text': text,
 'ciphertext': ciphertext,
 'nonce': nonce,
 'keyVersion': keyVersion,
 'type': type,
 });

 Future<Map<String, dynamic>> markChatRead(String chatId) =>
 call('markChatRead', {'chatId': chatId});

 Future<Map<String, dynamic>> joinEventGroupChat(String eventId) =>
 call('joinEventGroupChat', {'eventId': eventId});

 // safety 

 Future<Map<String, dynamic>> triggerSOS({
 required double latitude,
 required double longitude,
 double accuracyM = 50,
 String? eventId,
 String? notes,
 }) =>
 call('triggerSOS', {
 'latitude': latitude,
 'longitude': longitude,
 'accuracyM': accuracyM,
 'eventId': eventId,
 'notes': notes,
 });

 Future<Map<String, dynamic>> updateSOSLocation({
 required String alertId,
 required double latitude,
 required double longitude,
 double accuracyM = 50,
 }) =>
 call('updateSOSLocation', {
 'alertId': alertId,
 'latitude': latitude,
 'longitude': longitude,
 'accuracyM': accuracyM,
 });

 Future<Map<String, dynamic>> resolveSOS(String alertId, {String resolution = 'safe'}) =>
 call('resolveSOS', {'alertId': alertId, 'resolution': resolution});

 Future<Map<String, dynamic>> addEmergencyContact({
 required String name,
 required String phone,
 String? relationship,
 }) =>
 call('addEmergencyContact', {
 'name': name,
 'phone': phone,
 'relationship': relationship,
 });

 Future<Map<String, dynamic>> confirmEmergencyContact({
 required String contactId,
 required String status,
 }) =>
 call('confirmEmergencyContact', {'contactId': contactId, 'status': status});

 Future<Map<String, dynamic>> listEmergencyContacts() => call('listEmergencyContacts');

 // notifications & support 

 Future<Map<String, dynamic>> listNotifications({int limit = 30, String? cursor, bool unreadOnly = false}) =>
 call('listNotifications', {'limit': limit, 'cursor': cursor, 'unreadOnly': unreadOnly});

 Future<Map<String, dynamic>> markNotificationRead(String notificationId) =>
 call('markNotificationRead', {'notificationId': notificationId});

 Future<Map<String, dynamic>> markAllNotificationsRead() => call('markAllNotificationsRead');

 Future<Map<String, dynamic>> registerDevice({
 required String fcmToken,
 required String platform,
 String? appVersion,
 }) =>
 call('registerDevice', {
 'fcmToken': fcmToken,
 'platform': platform,
 'appVersion': appVersion,
 });

 Future<Map<String, dynamic>> updateNotificationPrefs(Map<String, bool> prefs) =>
 call('updateNotificationPrefs', {'prefs': prefs});

 Future<Map<String, dynamic>> createSupportTicket({
 required String category,
 required String subject,
 required String description,
 String? bookingId,
 List<String> attachments = const [],
 }) =>
 call('createSupportTicket', {
 'category': category,
 'subject': subject,
 'description': description,
 'bookingId': bookingId,
 'attachments': attachments,
 });

 Future<Map<String, dynamic>> listMySupportTickets() => call('listMySupportTickets');

 Future<Map<String, dynamic>> replySupportTicket({
 required String ticketId,
 required String text,
 }) =>
 call('replySupportTicket', {'ticketId': ticketId, 'text': text});

 Future<Map<String, dynamic>> listHelpArticles({String? category, String? search}) =>
 call('listHelpArticles', {'category': category, 'search': search});

 // promoter 

 Future<Map<String, dynamic>> becomePromoter({
 required String code,
 required String pan,
 String? legalName,
 }) =>
 call('becomePromoter', {'code': code, 'pan': pan, 'legalName': legalName});

 Future<Map<String, dynamic>> requestPromoterPayout({required int amountPaise, String? pan}) =>
 call('requestPromoterPayout', {'amountPaise': amountPaise, 'pan': pan});
}
