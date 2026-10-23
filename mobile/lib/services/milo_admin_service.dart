import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'milo_db_service.dart';
import 'milo_session_service.dart';
import 'payment_approval_service.dart';

class AdminAction {
 final bool ok;
 final String message;
 const AdminAction(this.ok, this.message);
}

class CategoryShare {
 final String label;
 final double share;
 final String detail;
 const CategoryShare({required this.label, required this.share, required this.detail});
}

class MiloAdminService extends ChangeNotifier {
 static final MiloAdminService instance = MiloAdminService._();
 MiloAdminService._();

 static const Duration _ioTimeout = Duration(seconds: 5);

 bool isLoading = false;
 bool hasLoaded = false;
 String health = 'connecting';

 int totalUsers = 48290;
 int liveCount = 342;
 double gmv = 4280000;
 double escrowHolds = 1420000;
 int confirmedBookings = 0;
 int pendingReviewCount = 3;

 bool eventsFromFirestore = false;
 bool reportsFromFirestore = false;
 bool settlementsFromFirestore = false;

 List<EventModel> liveEvents = const [];
 List<EventModel> pendingEvents = _fallbackPendingEvents();
 List<Map<String, dynamic>> reports = _fallbackReports();
 List<Map<String, dynamic>> settlements = _fallbackSettlements();
 List<CategoryShare> categories = _fallbackCategories();

 int get pendingPaymentApprovals => PaymentApprovalService.instance.pendingCount;

 FirebaseFirestore? get _db {
 try {
 return FirebaseFirestore.instance;
 } catch (_) {
 return null;
 }
 }

 String get _adminName {
 if (MiloSessionService.currentUserName.isNotEmpty) return MiloSessionService.currentUserName;
 if (MiloSessionService.currentUserPhone.isNotEmpty) return MiloSessionService.currentUserPhone;
 return 'Super Admin';
 }

 String get _adminUid => MiloSessionService.currentUid;
 String get _adminPhone => MiloSessionService.currentUserPhone;

 Future<void> refresh() async {
 if (isLoading) return;
 isLoading = true;
 notifyListeners();

 final db = _db;
 if (db == null) {
 health = 'offline';
 isLoading = false;
 hasLoaded = true;
 notifyListeners();
 return;
 }

 try {
 await MiloDbService.instance.ensureSeeded().timeout(_ioTimeout);
 } catch (_) {}

 final tracker = _ReadTracker();
 await Future.wait([
 _loadUsers(db, tracker),
 _loadEvents(db, tracker),
 _loadBookings(db, tracker),
 _loadReports(db, tracker),
 _loadSettlements(db, tracker),
 ]);

 if (tracker.failed == 0 && tracker.server > 0) {
 health = 'connected';
 } else if (tracker.server > 0) {
 health = 'degraded';
 } else if (tracker.cache > 0) {
 health = 'cached';
 } else {
 health = 'offline';
 }

 isLoading = false;
 hasLoaded = true;
 notifyListeners();
 }

 // Reads 

 Future<void> _loadUsers(FirebaseFirestore db, _ReadTracker t) async {
 try {
 final snap = await db.collection('users').limit(10000).get().timeout(_ioTimeout);
 totalUsers = snap.docs.length;
 snap.metadata.isFromCache ? t.cache++ : t.server++;
 } catch (e) {
 t.failed++;
 debugPrint('MiloAdmin users read note: $e');
 }
 }

 Future<void> _loadEvents(FirebaseFirestore db, _ReadTracker t) async {
 try {
 final snap = await db.collection('events').limit(5000).get().timeout(_ioTimeout);
 final live = <EventModel>[];
 final pending = <EventModel>[];
 for (final doc in snap.docs) {
 final data = doc.data();
 final status = data['status']?.toString() ?? '';
 if (status != 'live' && status != 'pending_review') continue;
 final model = MiloDbService.mapEventDoc({...data, 'id': doc.id});
 if (status == 'live') {
 live.add(model);
 } else {
 pending.add(model);
 }
 }
 liveEvents = live;
 pendingEvents = pending;
 liveCount = live.length;
 pendingReviewCount = pending.length;
 eventsFromFirestore = true;
 _recomputeCategories();
 snap.metadata.isFromCache ? t.cache++ : t.server++;
 } catch (e) {
 t.failed++;
 debugPrint('MiloAdmin events read note: $e');
 }
 }

 Future<void> _loadBookings(FirebaseFirestore db, _ReadTracker t) async {
 try {
 final snap = await db.collection('bookings').limit(10000).get().timeout(_ioTimeout);
 double total = 0;
 int confirmed = 0;
 for (final doc in snap.docs) {
 final data = doc.data();
 if (data['status'] != 'CONFIRMED') continue;
 total += (data['total_amount'] as num?)?.toDouble() ?? 0;
 confirmed++;
 }
 gmv = total;
 confirmedBookings = confirmed;
 snap.metadata.isFromCache ? t.cache++ : t.server++;
 } catch (e) {
 t.failed++;
 debugPrint('MiloAdmin bookings read note: $e');
 }
 }

 Future<void> _loadReports(FirebaseFirestore db, _ReadTracker t) async {
 try {
 var snap = await db.collection('reports').limit(200).get().timeout(_ioTimeout);
 if (snap.docs.isEmpty) {
 await _seedReports(db);
 snap = await db.collection('reports').limit(200).get().timeout(_ioTimeout);
 }
 reports = snap.docs.map((d) => _mapReport(d.id, d.data())).toList();
 reportsFromFirestore = true;
 snap.metadata.isFromCache ? t.cache++ : t.server++;
 } catch (e) {
 t.failed++;
 debugPrint('MiloAdmin reports read note: $e');
 }
 }

 Future<void> _loadSettlements(FirebaseFirestore db, _ReadTracker t) async {
 try {
 var snap = await db.collection('settlements').limit(200).get().timeout(_ioTimeout);
 if (snap.docs.isEmpty) {
 await _seedSettlements(db);
 snap = await db.collection('settlements').limit(200).get().timeout(_ioTimeout);
 }
 settlements = snap.docs.map((d) => _mapSettlement(d.id, d.data())).toList();
 settlementsFromFirestore = true;
 double held = 0;
 for (final row in settlements) {
 if (row['status'] == 'pending') {
 held += (row['net_payout'] as num?)?.toDouble() ?? 0;
 }
 }
 escrowHolds = held;
 snap.metadata.isFromCache ? t.cache++ : t.server++;
 } catch (e) {
 t.failed++;
 debugPrint('MiloAdmin settlements read note: $e');
 }
 }

 Future<void> _seedReports(FirebaseFirestore db) async {
 final batch = db.batch();
 for (final row in _reportSeeds()) {
 batch.set(db.collection('reports').doc(), {
 'reporter_name': row['reporter_name'],
 'reported_name': row['reported_name'],
 'reported_uid': row['reported_uid'],
 'reason': row['reason'],
 'details': row['details'],
 'severity': row['severity'],
 'status': 'open',
 'created_at': FieldValue.serverTimestamp(),
 });
 }
 await batch.commit().timeout(_ioTimeout);
 }

 Future<void> _seedSettlements(FirebaseFirestore db) async {
 final batch = db.batch();
 for (final row in _settlementSeeds()) {
 batch.set(db.collection('settlements').doc(), {
 'organizer': row['organizer'],
 'event': row['event'],
 'gross_amount': row['gross_amount'],
 'platform_fee': row['platform_fee'],
 'net_payout': row['net_payout'],
 'bank_account': row['bank_account'],
 'escrow_status': row['escrow_status'],
 'status': 'pending',
 'created_at': FieldValue.serverTimestamp(),
 });
 }
 await batch.commit().timeout(_ioTimeout);
 }

 // Actions 

 Future<AdminAction> approveEvent(EventModel event) async {
 final db = _db;
 if (db == null || !eventsFromFirestore) {
 return const AdminAction(false, 'Firestore unreachable — the listing was not published.');
 }
 try {
 await db.collection('events').doc(event.id).set({
 'status': 'live',
 'approved_by': _adminName,
 'approved_by_uid': _adminUid,
 'approved_at': FieldValue.serverTimestamp(),
 'updated_at': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 } on TimeoutException {
 _applyApproval(event);
 return AdminAction(true, 'Queued offline — "${event.title}" goes live automatically when Firestore reconnects.');
 } catch (e) {
 return AdminAction(false, 'Could not publish "${event.title}": $e');
 }
 _applyApproval(event);
 return AdminAction(true, '"${event.title}" is now live on the Explore feed.');
 }

 Future<AdminAction> rejectEvent(EventModel event, String reason) async {
 final db = _db;
 if (db == null || !eventsFromFirestore) {
 return const AdminAction(false, 'Firestore unreachable — the listing was not rejected.');
 }
 try {
 await db.collection('events').doc(event.id).set({
 'status': 'rejected',
 'rejection_reason': reason,
 'rejected_by': _adminName,
 'rejected_at': FieldValue.serverTimestamp(),
 'updated_at': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 } on TimeoutException {
 _applyRemoval(event);
 return AdminAction(true, 'Queued offline — "${event.title}" is marked rejected and hidden once Firestore reconnects.');
 } catch (e) {
 return AdminAction(false, 'Could not reject "${event.title}": $e');
 }
 _applyRemoval(event);
 return AdminAction(true, '"${event.title}" rejected — kept out of the live feed, reason saved for the host.');
 }

 Future<AdminAction> setEventVerified(EventModel event, bool value) async {
 final db = _db;
 if (db == null || !eventsFromFirestore) {
 return const AdminAction(false, 'Firestore unreachable — verification badge was not changed.');
 }
 try {
 await db.collection('events').doc(event.id).set({
 'is_verified_organizer': value,
 'updated_at': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 } on TimeoutException {
 _applyVerified(event, value);
 return const AdminAction(true, 'Queued offline — badge change syncs when Firestore reconnects.');
 } catch (e) {
 return AdminAction(false, 'Could not update verification: $e');
 }
 _applyVerified(event, value);
 return AdminAction(true, value
 ? '"${event.title}" marked verified — the green badge now shows in Explore.'
 : 'Verification badge removed from "${event.title}".');
 }

 Future<AdminAction> dismissReport(String id) async {
 final db = _db;
 if (db == null || !reportsFromFirestore) {
 return const AdminAction(false, 'Firestore unreachable — the report was not saved.');
 }
 try {
 await db.collection('reports').doc(id).set({
 'status': 'resolved',
 'resolved_by': _adminName,
 'resolved_by_uid': _adminUid,
 'resolved_at': FieldValue.serverTimestamp(),
 'updated_at': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 } on TimeoutException {
 _applyReportStatus(id, 'resolved');
 return const AdminAction(true, 'Queued offline — report marked resolved when Firestore reconnects.');
 } catch (e) {
 return AdminAction(false, 'Could not update report: $e');
 }
 _applyReportStatus(id, 'resolved');
 return const AdminAction(true, 'Report dismissed — status set to resolved in Firestore.');
 }

 Future<AdminAction> suspendReport(Map<String, dynamic> report) async {
 final db = _db;
 final id = report['id']?.toString() ?? '';
 final name = report['reported_name']?.toString() ?? 'user';
 final uid = report['reported_uid']?.toString() ?? '';
 if (db == null || !reportsFromFirestore) {
 return const AdminAction(false, 'Firestore unreachable — no suspension was recorded.');
 }

 bool userSuspended = false;
 String? userError;
 if (uid.isNotEmpty) {
 try {
 await db.collection('users').doc(uid).set({
 'status': 'suspended',
 'suspended_at': FieldValue.serverTimestamp(),
 'suspended_by': _adminName,
 'suspended_by_uid': _adminUid,
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 userSuspended = true;
 } catch (e) {
 userError = e.toString();
 }
 }

 try {
 await db.collection('reports').doc(id).set({
 'status': 'suspended',
 'updated_at': FieldValue.serverTimestamp(),
 'audit': {
 'action': 'suspend_account',
 'by_name': _adminName,
 'by_uid': _adminUid,
 'by_phone': _adminPhone,
 'at': FieldValue.serverTimestamp(),
 'account_suspended': userSuspended,
 },
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 } catch (e) {
 return AdminAction(false, 'Report status could not be saved ($e)${userSuspended ? ' — but the account of "$name" was suspended.' : ''}');
 }
 _applyReportStatus(id, 'suspended');

 if (uid.isEmpty) {
 return AdminAction(true, 'Report marked suspended — no linked account for "$name", so no user account was changed.');
 }
 if (userSuspended) {
 return AdminAction(true, '"$name" account suspended and report marked suspended.');
 }
 return AdminAction(false, 'Report marked suspended — but "$name" could not be updated: $userError');
 }

 Future<AdminAction> authorizeSettlement(String id, double netPayout, String bank) async {
 final db = _db;
 if (db == null || !settlementsFromFirestore) {
 return const AdminAction(false, 'Firestore unreachable — the payout was not authorized.');
 }
 try {
 await db.collection('settlements').doc(id).set({
 'status': 'authorized',
 'authorized_at': FieldValue.serverTimestamp(),
 'authorized_by': _adminName,
 'authorized_by_uid': _adminUid,
 }, SetOptions(merge: true)).timeout(_ioTimeout);
 } on TimeoutException {
 _applySettlementStatus(id, 'authorized');
 return AdminAction(true, 'Queued offline — payout of ${inr(netPayout)} for $bank syncs when Firestore reconnects.');
 } catch (e) {
 return AdminAction(false, 'Could not authorize payout: $e');
 }
 _applySettlementStatus(id, 'authorized');
 return AdminAction(true, 'Payout of ${inr(netPayout)} to $bank recorded as authorized in Firestore.');
 }

 // Local state updates 

 void _applyApproval(EventModel event) {
 pendingEvents = List.of(pendingEvents)..removeWhere((e) => e.id == event.id);
 liveEvents = List.of(liveEvents)..insert(0, event);
 liveCount = liveEvents.length;
 pendingReviewCount = pendingEvents.length;
 _recomputeCategories();
 notifyListeners();
 }

 void _applyRemoval(EventModel event) {
 pendingEvents = List.of(pendingEvents)..removeWhere((e) => e.id == event.id);
 pendingReviewCount = pendingEvents.length;
 notifyListeners();
 }

 void _applyVerified(EventModel event, bool value) {
 liveEvents = liveEvents.map((e) => e.id == event.id ? _withVerified(e, value) : e).toList();
 pendingEvents = pendingEvents.map((e) => e.id == event.id ? _withVerified(e, value) : e).toList();
 notifyListeners();
 }

 void _applyReportStatus(String id, String status) {
 reports = reports
 .map((r) => r['id'] == id ? {...r, 'status': status} : r)
 .toList();
 notifyListeners();
 }

 void _applySettlementStatus(String id, String status) {
 settlements = settlements
 .map((s) => s['id'] == id ? {...s, 'status': status} : s)
 .toList();
 notifyListeners();
 }

 void _recomputeCategories() {
 if (liveEvents.isEmpty) {
 categories = const [];
 return;
 }
 final counts = <String, int>{};
 for (final event in liveEvents) {
 counts.update(event.category, (v) => v + 1, ifAbsent: () => 1);
 }
 final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
 final total = liveEvents.length;
 categories = entries.take(5).map((e) {
 final share = e.value / total;
 return CategoryShare(
 label: e.key,
 share: share,
 detail: '${(share * 100).round()}% (${e.value} live event${e.value == 1 ? '' : 's'})',
 );
 }).toList();
 }

 EventModel _withVerified(EventModel e, bool value) => EventModel(
 id: e.id,
 title: e.title,
 category: e.category,
 date: e.date,
 time: e.time,
 venue: e.venue,
 city: e.city,
 googleMapsUrl: e.googleMapsUrl,
 startingPrice: e.startingPrice,
 imageUrl: e.imageUrl,
 organizerName: e.organizerName,
 isVerifiedOrganizer: value,
 rating: e.rating,
 tags: e.tags,
 ticketsLeft: e.ticketsLeft,
 isTrending: e.isTrending,
 description: e.description,
 ticketTiers: e.ticketTiers,
 organizerCoupons: e.organizerCoupons,
 customTermsAndConditions: e.customTermsAndConditions,
 autoReminder30Min: e.autoReminder30Min,
 );

 // Mappers 

 Map<String, dynamic> _mapReport(String id, Map<String, dynamic> data) => {
 'id': id,
 'reporter_name': data['reporter_name']?.toString() ?? 'Unknown reporter',
 'reported_name': data['reported_name']?.toString() ?? 'Unknown user',
 'reported_uid': data['reported_uid']?.toString() ?? '',
 'reason': data['reason']?.toString() ?? '',
 'details': data['details']?.toString() ?? '',
 'severity': data['severity']?.toString() ?? 'Medium',
 'status': data['status']?.toString() ?? 'open',
 'timestamp': _relative(data['created_at']),
 };

 Map<String, dynamic> _mapSettlement(String id, Map<String, dynamic> data) => {
 'id': id,
 'organizer': data['organizer']?.toString() ?? 'Organizer',
 'event': data['event']?.toString() ?? 'Milo Event',
 'gross_amount': (data['gross_amount'] as num?)?.toDouble() ?? 0,
 'platform_fee': (data['platform_fee'] as num?)?.toDouble() ?? 0,
 'net_payout': (data['net_payout'] as num?)?.toDouble() ?? 0,
 'bank_account': data['bank_account']?.toString() ?? 'Bank account on file',
 'escrow_status': data['escrow_status']?.toString() ?? '3-5 Day Hold Elapsed',
 'status': data['status']?.toString() ?? 'pending',
 };

 String _relative(dynamic value) {
 if (value is! Timestamp) return 'Recently';
 final diff = DateTime.now().difference(value.toDate());
 if (diff.inMinutes < 1) return 'Just now';
 if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
 if (diff.inHours < 24) return '${diff.inHours}h ago';
 return '${diff.inDays}d ago';
 }

 // Formatting 

 static String group(num value) {
 final n = value.round().toString();
 if (n.length <= 3) return n;
 final last3 = n.substring(n.length - 3);
 String rest = n.substring(0, n.length - 3);
 final parts = <String>[];
 while (rest.length > 2) {
 parts.insert(0, rest.substring(rest.length - 2));
 rest = rest.substring(0, rest.length - 2);
 }
 if (rest.isNotEmpty) parts.insert(0, rest);
 return '${parts.join(',')},$last3';
 }

 static String inr(num value) => '₹${group(value)}';

 static String compactInr(num value) {
 if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
 if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)} Lakh';
 return inr(value);
 }

 // Fallbacks (shown until a Firestore read succeeds) 

 static List<EventModel> _fallbackPendingEvents() => const [
 EventModel(
 id: 'pe_1',
 title: 'Bollywood Neon Dandiya Extravaganza 2026',
 category: 'Dandiya/Garba',
 date: '05 Oct 2026',
 time: '07:00 PM onwards',
 venue: 'Venue shared after approval',
 city: 'Ahmedabad',
 startingPrice: 499.0,
 imageUrl: '',
 organizerName: 'Royal Entertainment Group',
 isVerifiedOrganizer: false,
 tags: [],
 ticketsLeft: 2500,
 description: 'Awaiting Super Admin review.',
 ticketTiers: [],
 ),
 EventModel(
 id: 'pe_2',
 title: 'Midnight Rooftop Techno & Salsa Vibe',
 category: 'College & Squad',
 date: '02 Oct 2026',
 time: '10:00 PM onwards',
 venue: 'Venue shared after approval',
 city: 'Bangalore',
 startingPrice: 799.0,
 imageUrl: '',
 organizerName: 'Echo Beats Club',
 isVerifiedOrganizer: false,
 tags: [],
 ticketsLeft: 450,
 description: 'Awaiting Super Admin review.',
 ticketTiers: [],
 ),
 EventModel(
 id: 'pe_3',
 title: 'South Delhi Elite High-Tea Kitty & Tambola',
 category: 'Kitty/Parties',
 date: '28 Sep 2026',
 time: '03:00 PM onwards',
 venue: 'Venue shared after approval',
 city: 'Delhi',
 startingPrice: 1299.0,
 imageUrl: '',
 organizerName: 'Glamour Circle Delhi',
 isVerifiedOrganizer: false,
 tags: [],
 ticketsLeft: 120,
 description: 'Awaiting Super Admin review.',
 ticketTiers: [],
 ),
 ];

 static List<Map<String, dynamic>> _fallbackReports() => [
 {..._reportSeeds()[0], 'id': 'rep_1', 'status': 'open', 'timestamp': '15 mins ago'},
 {..._reportSeeds()[1], 'id': 'rep_2', 'status': 'open', 'timestamp': '42 mins ago'},
 ];

 static List<Map<String, dynamic>> _reportSeeds() => [
 {
 'reporter_name': 'Ananya S.',
 'reported_name': 'Deepak R.',
 'reported_uid': '',
 'reason': 'Unsolicited spam messages outside event community',
 'details': 'Sent 14 unsolicited promotional DMs after the Garba meetup and was muted by 6 attendees.',
 'severity': 'Medium',
 },
 {
 'reporter_name': 'Automated AI Shield',
 'reported_name': 'Vikas Event Promo Bot',
 'reported_uid': '',
 'reason': 'Suspicious ticket scalping & multiple IP logins',
 'details': 'Posted 3 duplicate listings with identical banners and requested off-app UPI transfers from 11 users.',
 'severity': 'High (Critical)',
 },
 ];

 static List<Map<String, dynamic>> _fallbackSettlements() => [
 {..._settlementSeeds()[0], 'id': 'st_101', 'status': 'pending'},
 {..._settlementSeeds()[1], 'id': 'st_102', 'status': 'pending'},
 ];

 static List<Map<String, dynamic>> _settlementSeeds() => [
 {
 'organizer': 'Garba Rass Premier',
 'event': 'Grand Dandiya Mahotsav 2026',
 'gross_amount': 845000.0,
 'platform_fee': 42250.0,
 'net_payout': 802750.0,
 'bank_account': 'HDFC Bank ••••••9201',
 'escrow_status': '3-5 Day Hold Elapsed (Safe to Release)',
 },
 {
 'organizer': 'Campus Vibe Network',
 'event': 'College Fest After-Hours & Gaming Night',
 'gross_amount': 124500.0,
 'platform_fee': 6225.0,
 'net_payout': 118275.0,
 'bank_account': 'ICICI Bank ••••••4412',
 'escrow_status': '3-5 Day Hold Elapsed',
 },
 ];

 static List<CategoryShare> _fallbackCategories() => const [
 CategoryShare(label: ' Dandiya & Cultural Festivals', share: 0.42, detail: '42% (20,280 Attendees)'),
 CategoryShare(label: ' College Fests & Hackathon Squads', share: 0.24, detail: '24% (11,580 Attendees)'),
 CategoryShare(label: ' Coworking & Remote Work Meets', share: 0.14, detail: '14% (6,760 Attendees)'),
 CategoryShare(label: ' Kitty Brunches & Ladies Circles', share: 0.11, detail: '11% (5,310 Attendees)'),
 CategoryShare(label: ' Yoga & Sunrise Walking Clubs', share: 0.09, detail: '9% (4,340 Attendees)'),
 ];
}

class _ReadTracker {
 int server = 0;
 int cache = 0;
 int failed = 0;
}
