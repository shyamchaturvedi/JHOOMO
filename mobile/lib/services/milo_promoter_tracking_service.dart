import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'milo_session_service.dart';

class PromoterReferralItem {
 final String id;
 final String promoterId;
 final String promoterName;
 final String promoterHandle; // e.g. @lucknow_vibes
 final String referralCode; // e.g. 'LKO_VIKAS'
 final String eventId;
 final String eventTitle;
 final String shareLink; // e.g. 'https://…/e/e1?ref=LKO_VIKAS'
 final int totalClicks;
 final int ticketsSold;
 final double grossRevenue; // e.g. ₹38,400
 final double commissionRatePercent; // e.g. 10.0%
 final double commissionEarned; // e.g. ₹3,840
 final String payoutStatus; // 'SETTLED' | 'PENDING_ESCROW'
 final String lastForwardedTime;

 const PromoterReferralItem({
 required this.id,
 required this.promoterId,
 required this.promoterName,
 required this.promoterHandle,
 required this.referralCode,
 required this.eventId,
 required this.eventTitle,
 required this.shareLink,
 required this.totalClicks,
 required this.ticketsSold,
 required this.grossRevenue,
 required this.commissionRatePercent,
 required this.commissionEarned,
 this.payoutStatus = 'PENDING_ESCROW',
 required this.lastForwardedTime,
 });

 PromoterReferralItem copyWith({
 int? totalClicks,
 int? ticketsSold,
 double? grossRevenue,
 double? commissionEarned,
 String? payoutStatus,
 String? lastForwardedTime,
 }) {
 return PromoterReferralItem(
 id: id,
 promoterId: promoterId,
 promoterName: promoterName,
 promoterHandle: promoterHandle,
 referralCode: referralCode,
 eventId: eventId,
 eventTitle: eventTitle,
 shareLink: shareLink,
 totalClicks: totalClicks ?? this.totalClicks,
 ticketsSold: ticketsSold ?? this.ticketsSold,
 grossRevenue: grossRevenue ?? this.grossRevenue,
 commissionRatePercent: commissionRatePercent,
 commissionEarned: commissionEarned ?? this.commissionEarned,
 payoutStatus: payoutStatus ?? this.payoutStatus,
 lastForwardedTime: lastForwardedTime ?? this.lastForwardedTime,
 );
 }
}

class PromoterAuditLog {
 final String id;
 final String promoterName;
 final String referralCode;
 final String eventTitle;
 final String buyerName;
 final String tierName;
 final int quantity;
 final double totalAmount;
 final double commissionEarned;
 final String timestamp;

 const PromoterAuditLog({
 required this.id,
 required this.promoterName,
 required this.referralCode,
 required this.eventTitle,
 required this.buyerName,
 required this.tierName,
 required this.quantity,
 required this.totalAmount,
 required this.commissionEarned,
 required this.timestamp,
 });
}

/// Promoter referral + sales audit store for Jhoomo.
///
/// Backed by Firestore (`referrals` + `promoter_audit_logs`) so links and
/// commission numbers survive restarts and sync across devices. The
/// synchronous API used by existing screens is preserved — writes are
/// optimistic in-memory updates plus an async Firestore write, reconciled
/// by snapshot listeners (same pattern as PaymentApprovalService).
class MiloPromoterTrackingService extends ChangeNotifier {
 static final MiloPromoterTrackingService instance = MiloPromoterTrackingService._();

 MiloPromoterTrackingService._() {
 _initDefaultPromoterData();
 unawaited(init());
 }

 final List<PromoterReferralItem> _referrals = [];
 final List<PromoterAuditLog> _auditLogs = [];

 StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _referralsSub;
 StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _auditLogsSub;
 bool _initialized = false;

 /// True once Firestore-backed sync is active; false means the in-memory
 /// demo dataset is authoritative (offline / not configured).
 bool firestoreOnline = false;

 List<PromoterReferralItem> get allReferrals => List.unmodifiable(_referrals);
 List<PromoterAuditLog> get auditLogs => List.unmodifiable(_auditLogs);

 /// Stable promoter identity derived from the logged-in session.
 String get sessionPromoterId {
 final uid = MiloSessionService.currentUid.trim();
 if (uid.isNotEmpty) return uid;
 return MiloSessionService.currentUserPhone.trim();
 }

 static const List<PromoterReferralItem> _demoReferrals = [
 PromoterReferralItem(
 id: 'REF-101',
 promoterId: 'prom-1',
 promoterName: 'Vikas Mishra (Lucknow Food & Beats)',
 promoterHandle: '@lucknow_vibes',
 referralCode: 'LKO_VIKAS',
 eventId: 'e1',
 eventTitle: 'Grand Dandiya Mahotsav 2026 ',
 shareLink: '${MiloConfig.webBaseUrl}/e/e1?ref=LKO_VIKAS',
 totalClicks: 840,
 ticketsSold: 46,
 grossRevenue: 41354, // 46 passes
 commissionRatePercent: 10.0,
 commissionEarned: 4135.40,
 payoutStatus: 'PENDING_ESCROW',
 lastForwardedTime: '12 mins ago',
 ),
 PromoterReferralItem(
 id: 'REF-102',
 promoterId: 'prom-2',
 promoterName: 'Ananya Verma (Hazratganj Youth Circle)',
 promoterHandle: '@ananya_lko',
 referralCode: 'ANANYA_DND',
 eventId: 'e1',
 eventTitle: 'Grand Dandiya Mahotsav 2026 ',
 shareLink: '${MiloConfig.webBaseUrl}/e/e1?ref=ANANYA_DND',
 totalClicks: 520,
 ticketsSold: 28,
 grossRevenue: 25172,
 commissionRatePercent: 10.0,
 commissionEarned: 2517.20,
 payoutStatus: 'PENDING_ESCROW',
 lastForwardedTime: '45 mins ago',
 ),
 PromoterReferralItem(
 id: 'REF-103',
 promoterId: 'prom-3',
 promoterName: 'Rohit Summit Clubbing Ambassador',
 promoterHandle: '@rohit_nightlife',
 referralCode: 'ROHIT_NEON',
 eventId: 'e2',
 eventTitle: 'Neon Garba & Electronic Beats ',
 shareLink: '${MiloConfig.webBaseUrl}/e/e2?ref=ROHIT_NEON',
 totalClicks: 310,
 ticketsSold: 14,
 grossRevenue: 15386,
 commissionRatePercent: 10.0,
 commissionEarned: 1538.60,
 payoutStatus: 'PENDING_ESCROW',
 lastForwardedTime: '2 hours ago',
 ),
 ];

 static const List<PromoterAuditLog> _demoAuditLogs = [
 PromoterAuditLog(
 id: 'AUD-001',
 promoterName: 'Vikas Mishra',
 referralCode: 'LKO_VIKAS',
 eventTitle: 'Grand Dandiya Mahotsav 2026 ',
 buyerName: 'Aman Srivastava (Gomti Nagar)',
 tierName: 'Couple Pass',
 quantity: 1,
 totalAmount: 928,
 commissionEarned: 92.80,
 timestamp: '18 mins ago',
 ),
 PromoterAuditLog(
 id: 'AUD-002',
 promoterName: 'Vikas Mishra',
 referralCode: 'LKO_VIKAS',
 eventTitle: 'Grand Dandiya Mahotsav 2026 ',
 buyerName: 'Kritika Roy (Indira Nagar)',
 tierName: 'VIP Group Squad (5 Pax)',
 quantity: 1,
 totalAmount: 2228,
 commissionEarned: 222.80,
 timestamp: '40 mins ago',
 ),
 PromoterAuditLog(
 id: 'AUD-003',
 promoterName: 'Ananya Verma',
 referralCode: 'ANANYA_DND',
 eventTitle: 'Grand Dandiya Mahotsav 2026 ',
 buyerName: 'Mohit Saxena (Hazratganj)',
 tierName: 'Single Entry Pass',
 quantity: 2,
 totalAmount: 1027,
 commissionEarned: 102.70,
 timestamp: '1 hr ago',
 ),
 ];

 FirebaseFirestore? get _db {
 try {
 return FirebaseFirestore.instance;
 } catch (_) {
 return null;
 }
 }

 void _initDefaultPromoterData() {
 if (_referrals.isNotEmpty || _auditLogs.isNotEmpty) return;
 // Top Lucknow Influencers / Event Promoters working on live events
 _referrals.addAll(_demoReferrals);
 // Initial audit log entries of actual ticket sales through referrals
 _auditLogs.addAll(_demoAuditLogs);
 }

 /// Idempotent init — starts Firestore sync and seeds demo rows when the
 /// collections are empty. Safe to call repeatedly.
 Future<void> init() async {
 if (_initialized) return;
 _initialized = true;

 final db = _db;
 if (db == null) return;

 try {
 await _seedDemoDataIfEmpty(db);

 _referralsSub = db
 .collection('referrals')
 .orderBy('created_at', descending: true)
 .limit(300)
 .snapshots(includeMetadataChanges: true)
 .listen((snap) {
 if (snap.docs.isNotEmpty) {
 _referrals
 ..clear()
 ..addAll(snap.docs.map((d) => _mapReferralDoc(d.id, d.data())));
 }
 firestoreOnline = true;
 notifyListeners();
 }, onError: (e) => debugPrint('PromoterTracking referrals stream error: $e'));

 _auditLogsSub = db
 .collection('promoter_audit_logs')
 .orderBy('created_at', descending: true)
 .limit(300)
 .snapshots(includeMetadataChanges: true)
 .listen((snap) {
 if (snap.docs.isNotEmpty) {
 _auditLogs
 ..clear()
 ..addAll(snap.docs.map((d) => _mapAuditDoc(d.id, d.data())));
 }
 firestoreOnline = true;
 notifyListeners();
 }, onError: (e) => debugPrint('PromoterTracking audit stream error: $e'));

 firestoreOnline = true;
 debugPrint('PromoterTrackingService: Firestore sync active');
 } catch (e) {
 debugPrint('PromoterTrackingService init fallback: $e');
 firestoreOnline = false;
 _initDefaultPromoterData();
 notifyListeners();
 }
 }

 Future<void> _seedDemoDataIfEmpty(FirebaseFirestore db) async {
 try {
 final promoterId = sessionPromoterId;

 final refSnap = await db.collection('referrals').limit(1).get();
 if (refSnap.docs.isEmpty) {
 final batch = db.batch();
 for (final r in _demoReferrals) {
 batch.set(
 db.collection('referrals').doc(r.id),
 _referralToDoc(r, promoterIdOverride: promoterId),
 );
 }
 await batch.commit();
 }

 final logSnap = await db.collection('promoter_audit_logs').limit(1).get();
 if (logSnap.docs.isEmpty) {
 final batch = db.batch();
 for (final l in _demoAuditLogs) {
 final matches = _demoReferrals.where((r) => r.referralCode == l.referralCode);
 final ref = matches.isNotEmpty ? matches.first : null;
 batch.set(
 db.collection('promoter_audit_logs').doc(l.id),
 _auditToDoc(
 l,
 referralId: ref?.id ?? '',
 eventId: ref?.eventId ?? '',
 promoterId: promoterId.isNotEmpty
 ? promoterId
 : (ref?.promoterId ?? ''),
 ),
 );
 }
 await batch.commit();
 }
 } catch (e) {
 debugPrint('PromoterTracking demo seed note: $e');
 }
 }

 /// Get referrals filtered by event (For Organizer view)
 List<PromoterReferralItem> getReferralsForEvent(String eventId) {
 return _referrals.where((r) => r.eventId == eventId).toList();
 }

 /// Get referrals for a specific promoter (For Influencer view)
 List<PromoterReferralItem> getReferralsForPromoter(String promoterCodeOrId) {
 return _referrals
 .where((r) =>
 r.referralCode.toUpperCase() == promoterCodeOrId.toUpperCase() ||
 r.promoterId == promoterCodeOrId)
 .toList();
 }

 /// Find referral by code
 PromoterReferralItem? findByCode(String code) {
 final clean = code.trim().toUpperCase();
 try {
 return _referrals.firstWhere((r) => r.referralCode.toUpperCase() == clean);
 } catch (_) {
 return null;
 }
 }

 /// Record a new ticket purchase made via an Influencer's referral code
 void recordTicketSaleFromReferral({
 required String referralCode,
 required String eventId,
 required String eventTitle,
 required String tierName,
 required int quantity,
 required double totalAmount,
 required String buyerName,
 }) {
 final clean = referralCode.trim().toUpperCase();
 final index = _referrals.indexWhere((r) => r.referralCode.toUpperCase() == clean);

 double commission = (totalAmount * 0.10); // 10% standard verified commission
 String promName = clean;
 String promHandle = '@${clean.toLowerCase()}';
 String referralDocId = '';
 String promoterId = '';

 if (index != -1) {
 final existing = _referrals[index];
 promName = existing.promoterName;
 promHandle = existing.promoterHandle;
 promoterId = existing.promoterId;
 referralDocId = existing.id;
 commission = totalAmount * (existing.commissionRatePercent / 100.0);

 _referrals[index] = existing.copyWith(
 ticketsSold: existing.ticketsSold + quantity,
 grossRevenue: existing.grossRevenue + totalAmount,
 commissionEarned: existing.commissionEarned + commission,
 lastForwardedTime: 'Just now',
 );
 } else {
 // Create new promoter entry dynamically
 final newItem = PromoterReferralItem(
 id: 'REF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
 promoterId: 'prom-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
 promoterName: 'Influencer ($clean)',
 promoterHandle: '@${clean.toLowerCase()}',
 referralCode: clean,
 eventId: eventId,
 eventTitle: eventTitle,
 shareLink: MiloConfig.eventLink(eventId, ref: clean),
 totalClicks: 12,
 ticketsSold: quantity,
 grossRevenue: totalAmount,
 commissionRatePercent: 10.0,
 commissionEarned: commission,
 lastForwardedTime: 'Just now',
 );
 _referrals.insert(0, newItem);
 referralDocId = newItem.id;
 promoterId = newItem.promoterId;
 }

 final auditId = 'AUD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
 _auditLogs.insert(
 0,
 PromoterAuditLog(
 id: auditId,
 promoterName: promName,
 referralCode: clean,
 eventTitle: eventTitle,
 buyerName: buyerName,
 tierName: tierName,
 quantity: quantity,
 totalAmount: totalAmount,
 commissionEarned: commission,
 timestamp: 'Just now',
 ),
 );

 notifyListeners();
 _persistSale(
 referralDocId: referralDocId,
 referralCode: clean,
 promoterId: promoterId,
 promoterName: promName,
 promoterHandle: promHandle,
 eventId: eventId,
 eventTitle: eventTitle,
 tierName: tierName,
 quantity: quantity,
 totalAmount: totalAmount,
 commission: commission,
 buyerName: buyerName,
 auditId: auditId,
 );
 }

 /// Create a new event promotion referral link for an influencer
 PromoterReferralItem createReferralLink({
 required String eventId,
 required String eventTitle,
 required String promoterName,
 required String promoterHandle,
 required String customCode,
 double commissionRatePercent = 10.0,
 String promoterId = '',
 }) {
 final cleanCode = customCode.trim().toUpperCase();
 final existingIndex = _referrals.indexWhere(
 (r) => r.referralCode == cleanCode && r.eventId == eventId);

 if (existingIndex != -1) {
 return _referrals[existingIndex];
 }

 final item = PromoterReferralItem(
 id: 'REF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
 promoterId: promoterId.isNotEmpty
 ? promoterId
 : 'prom-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
 promoterName: promoterName,
 promoterHandle: promoterHandle,
 referralCode: cleanCode,
 eventId: eventId,
 eventTitle: eventTitle,
 shareLink: MiloConfig.eventLink(eventId, ref: cleanCode),
 totalClicks: 1,
 ticketsSold: 0,
 grossRevenue: 0.0,
 commissionRatePercent: commissionRatePercent,
 commissionEarned: 0.0,
 lastForwardedTime: 'Just now',
 );

 _referrals.insert(0, item);
 notifyListeners();
 _persistReferral(item);
 return item;
 }

 // Firestore helpers 

 void _persistReferral(PromoterReferralItem item) {
 final db = _db;
 if (db == null) return;
 db
 .collection('referrals')
 .doc(item.id)
 .set(_referralToDoc(item), SetOptions(merge: true))
 .catchError((e) => debugPrint('PromoterTracking referral write error: $e'));
 }

 Future<void> _persistSale({
 required String referralDocId,
 required String referralCode,
 required String promoterId,
 required String promoterName,
 required String promoterHandle,
 required String eventId,
 required String eventTitle,
 required String tierName,
 required int quantity,
 required double totalAmount,
 required double commission,
 required String buyerName,
 required String auditId,
 }) async {
 final db = _db;
 if (db == null) return;
 try {
 final referralRef = db.collection('referrals').doc(referralDocId);
 final snap = await referralRef.get();
 if (snap.exists) {
 await referralRef.set({
 'sales_count': FieldValue.increment(quantity),
 'total_sales_amount': FieldValue.increment(totalAmount),
 'commission_amount': FieldValue.increment(commission),
 'payout_status': 'PENDING_ESCROW',
 }, SetOptions(merge: true));
 } else {
 await referralRef.set({
 'event_id': eventId,
 'event_title': eventTitle,
 'promoter_id': promoterId,
 'promoter_name': promoterName,
 'promoter_handle': promoterHandle,
 'custom_code': referralCode,
 'commission_rate_percent': 10.0,
 'clicks': 12,
 'sales_count': quantity,
 'total_sales_amount': totalAmount,
 'commission_amount': commission,
 'payout_status': 'PENDING_ESCROW',
 'status': 'active',
 'created_at': FieldValue.serverTimestamp(),
 });
 }

 await db.collection('promoter_audit_logs').doc(auditId).set({
 'referral_id': referralDocId,
 'referral_code': referralCode,
 'event_id': eventId,
 'event_title': eventTitle,
 'tier_name': tierName,
 'quantity': quantity,
 'amount': totalAmount,
 'commission_amount': commission,
 'buyer_name': buyerName,
 'promoter_id': promoterId,
 'created_at': FieldValue.serverTimestamp(),
 });
 } catch (e) {
 debugPrint('PromoterTracking sale write error: $e');
 }
 }

 Map<String, dynamic> _referralToDoc(PromoterReferralItem r, {String? promoterIdOverride}) {
 return {
 'event_id': r.eventId,
 'event_title': r.eventTitle,
 'promoter_id': (promoterIdOverride != null && promoterIdOverride.isNotEmpty)
 ? promoterIdOverride
 : r.promoterId,
 'promoter_name': r.promoterName,
 'promoter_handle': r.promoterHandle,
 'custom_code': r.referralCode,
 'commission_rate_percent': r.commissionRatePercent,
 'clicks': r.totalClicks,
 'sales_count': r.ticketsSold,
 'total_sales_amount': r.grossRevenue,
 'commission_amount': r.commissionEarned,
 'payout_status': r.payoutStatus,
 'status': 'active',
 'created_at': FieldValue.serverTimestamp(),
 };
 }

 Map<String, dynamic> _auditToDoc(
 PromoterAuditLog l, {
 required String referralId,
 required String eventId,
 required String promoterId,
 }) {
 return {
 'referral_id': referralId,
 'referral_code': l.referralCode,
 'event_id': eventId,
 'event_title': l.eventTitle,
 'tier_name': l.tierName,
 'quantity': l.quantity,
 'amount': l.totalAmount,
 'commission_amount': l.commissionEarned,
 'buyer_name': l.buyerName,
 'promoter_id': promoterId,
 'created_at': FieldValue.serverTimestamp(),
 };
 }

 PromoterReferralItem _mapReferralDoc(String id, Map<String, dynamic> data) {
 final eventId = data['event_id']?.toString() ?? '';
 final code = data['custom_code']?.toString() ?? '';
 return PromoterReferralItem(
 id: id,
 promoterId: data['promoter_id']?.toString() ?? '',
 promoterName: data['promoter_name']?.toString() ?? 'Influencer',
 promoterHandle: data['promoter_handle']?.toString() ?? '@promoter',
 referralCode: code,
 eventId: eventId,
 eventTitle: data['event_title']?.toString() ?? 'Jhoomo Event',
 shareLink: MiloConfig.eventLink(eventId, ref: code),
 totalClicks: ((data['clicks'] as num?)?.toInt()) ?? 0,
 ticketsSold: ((data['sales_count'] as num?)?.toInt()) ?? 0,
 grossRevenue: (data['total_sales_amount'] as num?)?.toDouble() ?? 0,
 commissionRatePercent: (data['commission_rate_percent'] as num?)?.toDouble() ?? 10.0,
 commissionEarned: (data['commission_amount'] as num?)?.toDouble() ?? 0,
 payoutStatus: data['payout_status']?.toString() ?? 'PENDING_ESCROW',
 lastForwardedTime: _relativeTime(data['created_at']),
 );
 }

 PromoterAuditLog _mapAuditDoc(String id, Map<String, dynamic> data) {
 final code = data['referral_code']?.toString() ?? '';
 final refId = data['referral_id']?.toString() ?? '';
 final promoterId = data['promoter_id']?.toString() ?? '';

 PromoterReferralItem? ref;
 if (refId.isNotEmpty) {
 final i = _referrals.indexWhere((r) => r.id == refId);
 if (i != -1) ref = _referrals[i];
 }
 if (ref == null && code.isNotEmpty) {
 final i = _referrals.indexWhere(
 (r) => r.referralCode.toUpperCase() == code.toUpperCase());
 if (i != -1) ref = _referrals[i];
 }

 final amount = (data['amount'] as num?)?.toDouble() ?? 0;
 final rate = ref?.commissionRatePercent ?? 10.0;
 return PromoterAuditLog(
 id: id,
 promoterName: ref?.promoterName ?? promoterId,
 referralCode: code,
 eventTitle: data['event_title']?.toString() ?? 'Jhoomo Event',
 buyerName: data['buyer_name']?.toString() ?? 'Jhoomo User',
 tierName: data['tier_name']?.toString() ?? 'Pass',
 quantity: ((data['quantity'] as num?)?.toInt()) ?? 1,
 totalAmount: amount,
 commissionEarned:
 (data['commission_amount'] as num?)?.toDouble() ?? amount * (rate / 100.0),
 timestamp: _relativeTime(data['created_at']),
 );
 }

 String _relativeTime(dynamic createdAt) {
 DateTime? dt;
 if (createdAt is Timestamp) dt = createdAt.toDate();
 if (dt == null) return 'Recently';
 final diff = DateTime.now().difference(dt);
 if (diff.inMinutes < 1) return 'Just now';
 if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
 if (diff.inHours < 24) return '${diff.inHours} hours ago';
 return '${diff.inDays} days ago';
 }

 @override
 void dispose() {
 _referralsSub?.cancel();
 _auditLogsSub?.cancel();
 super.dispose();
 }
}
