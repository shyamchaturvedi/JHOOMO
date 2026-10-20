import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'mock_data.dart';
import 'milo_db_service.dart';
import 'milo_session_service.dart';

/// Payment approval + booking store for Milo.
///
/// Backed by Firebase Firestore (`bookings` + `payment_requests`) so
/// approvals are shared across devices: the attendee's request appears on
/// the organizer dashboard instantly and survives restarts.
///
/// The synchronous API used by existing screens is preserved — writes are
/// optimistic in-memory updates plus an async Firestore write, reconciled
/// by snapshot listeners.
class PaymentApprovalService extends ChangeNotifier {
  static final PaymentApprovalService instance = PaymentApprovalService._();

  PaymentApprovalService._();

  final List<PaymentApprovalRequest> _approvalRequests = [];
  final List<BookedTicket> _allTickets = [];
  final List<Map<String, dynamic>> _systemNotifications = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSub;
  bool _initialized = false;
  bool firestoreOnline = false;

  List<PaymentApprovalRequest> get approvalRequests => List.unmodifiable(_approvalRequests);
  List<PaymentApprovalRequest> get pendingRequests =>
      _approvalRequests.where((r) => r.status == 'PENDING').toList();
  List<BookedTicket> get userTickets {
    final uid = MiloSessionService.currentUid;
    final phone = normalizePhone(MiloSessionService.currentUserPhone);
    return _allTickets
        .where((t) =>
            t.uid.isEmpty ||
            (uid.isNotEmpty && t.uid == uid) ||
            (phone.isNotEmpty && normalizePhone(t.attendeePhone) == phone))
        .toList();
  }

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_systemNotifications);

  int get pendingCount => _approvalRequests.where((r) => r.status == 'PENDING').length;

  static String normalizePhone(String p) {
    var v = p.trim().replaceAll(RegExp(r'[\s\-+]'), '');
    if (v.length == 12 && v.startsWith('91')) v = v.substring(2);
    if (v.startsWith('0')) v = v.substring(1);
    return v;
  }

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Idempotent init — call once at app start (safe to call repeatedly).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final db = _db;
    if (db == null) {
      _initLocalDemoData();
      _rebuildNotifications();
      notifyListeners();
      return;
    }

    try {
      await MiloDbService.instance.ensureSeeded();
      await _seedDemoDataIfEmpty(db);

      _bookingsSub = db
          .collection('bookings')
          .orderBy('created_at', descending: true)
          .limit(300)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        final rows = snap.docs.map((d) => MiloDbService.mapBookingDoc(d.data())).toList();
        _allTickets
          ..clear()
          ..addAll(rows);
        firestoreOnline = !snap.metadata.isFromCache;
        _rebuildNotifications();
        notifyListeners();
      }, onError: (e) => debugPrint('PaymentApproval bookings stream error: $e'));

      _requestsSub = db
          .collection('payment_requests')
          .orderBy('created_at', descending: true)
          .limit(300)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        _approvalRequests
          ..clear()
          ..addAll(snap.docs.map((d) => _mapDocToRequest({...d.data(), 'id': d.id})));
        _rebuildNotifications();
        notifyListeners();
      }, onError: (e) => debugPrint('PaymentApproval requests stream error: $e'));

      firestoreOnline = true;
      debugPrint('PaymentApprovalService: Firestore sync active');
    } catch (e) {
      debugPrint('PaymentApprovalService init fallback: $e');
      _initLocalDemoData();
      _rebuildNotifications();
      notifyListeners();
    }
  }

  // ─── Local demo fallback (Firestore unavailable) ──────────────────

  void _initLocalDemoData() {
    if (_allTickets.isNotEmpty || _approvalRequests.isNotEmpty) return;
    _allTickets.addAll(MockData.initialBookings);
    _allTickets.insert(0, _demoPendingTicket());
    _approvalRequests.addAll(_demoRequests());
  }

  BookedTicket _demoPendingTicket() {
    return BookedTicket(
      bookingId: 'MILO-SELF-PAY-9842',
      event: MockData.events[0],
      tier: MockData.events[0].ticketTiers[1],
      quantity: 1,
      totalAmount: 928,
      bookingTime: 'Today, 03:45 PM',
      qrData: 'MILO_PENDING_APPROVAL_9842',
      status: 'PENDING_APPROVAL',
      paymentMethod: 'SELF_UPI_GATEWAY',
      utrNumber: '329184729104',
      organizerUpiId: 'utsav.garba@okhdfcbank',
      attendeeName: 'Sahil (Verified)',
      attendeePhone: '+91 98765 43210',
      paymentProofUrl:
          'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400&q=80',
    );
  }

  List<PaymentApprovalRequest> _demoRequests() {
    return [
      PaymentApprovalRequest(
        id: 'REQ-101',
        bookingId: 'MILO-SELF-PAY-9842',
        eventId: MockData.events[0].id,
        eventTitle: MockData.events[0].title,
        tierName: MockData.events[0].ticketTiers[1].name,
        quantity: 1,
        totalAmount: 928,
        attendeeName: 'Sahil (Verified)',
        attendeePhone: '+91 98765 43210',
        utrNumber: '329184729104',
        organizerUpiId: 'utsav.garba@okhdfcbank',
        timestamp: '15 mins ago',
        status: 'PENDING',
        proofImageUrl:
            'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400&q=80',
        note: 'Paid via GPay UPI. Kindly approve couple pass quickly.',
      ),
      PaymentApprovalRequest(
        id: 'REQ-102',
        bookingId: 'MILO-SELF-PAY-7719',
        eventId: MockData.events[1].id,
        eventTitle: MockData.events[1].title,
        tierName: MockData.events[1].ticketTiers[0].name,
        quantity: 2,
        totalAmount: 1227,
        attendeeName: 'Priya Sharma',
        attendeePhone: '+91 98234 11029',
        utrNumber: '489201948502',
        organizerUpiId: 'neonwave.events@icici',
        timestamp: '32 mins ago',
        status: 'PENDING',
        proofImageUrl:
            'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=400&q=80',
        note: 'Sent from PhonePe. Attached UTR receipt.',
      ),
    ];
  }

  /// Make sure demo approvals exist in Firestore so organizer/admin panels
  /// have real records on a fresh project.
  Future<void> _seedDemoDataIfEmpty(FirebaseFirestore db) async {
    try {
      final demoBooking = _demoPendingTicket();
      final bookingRef = db.collection('bookings').doc(demoBooking.bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        await bookingRef.set(_bookingToDoc(demoBooking));
      }
      final extraRef = db.collection('bookings').doc('MILO-SELF-PAY-7719');
      final extraSnap = await extraRef.get();
      if (!extraSnap.exists) {
        await extraRef.set({
          'booking_ref': 'MILO-SELF-PAY-7719',
          'event_id': MockData.events[1].id,
          'event_title': MockData.events[1].title,
          'event_date': MockData.events[1].date,
          'event_time': MockData.events[1].time,
          'event_venue': MockData.events[1].venue,
          'event_city': MockData.events[1].city,
          'event_banner': MockData.events[1].imageUrl,
          'event_organizer': MockData.events[1].organizerName,
          'tier_id': MockData.events[1].ticketTiers[0].id,
          'tier_name': MockData.events[1].ticketTiers[0].name,
          'tier_price': MockData.events[1].ticketTiers[0].price,
          'quantity': 2,
          'total_amount': 1227,
          'attendee_name': 'Priya Sharma',
          'attendee_phone': '+91 98234 11029',
          'user_name': 'Priya Sharma',
          'user_phone': '+91 98234 11029',
          'qr_hash_token': 'MILO_PENDING_APPROVAL_7719',
          'payment_status': 'pending',
          'status': 'PENDING_APPROVAL',
          'payment_method': 'SELF_UPI_GATEWAY',
          'utr_number': '489201948502',
          'organizer_upi_id': 'neonwave.events@icici',
          'uid': '',
          'checked_in': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      for (final req in _demoRequests()) {
        final ref = db.collection('payment_requests').doc(req.id);
        if (!(await ref.get()).exists) {
          await ref.set(_requestToDoc(req));
        }
      }
    } catch (e) {
      debugPrint('PaymentApproval demo seed note: $e');
    }
  }

  // ─── Writes ───────────────────────────────────────────────────────

  /// Submit a payment (manual UPI, cash-at-gate or test-gateway) for
  /// organizer verification. Pass [autoConfirm] for payments already
  /// verified by the Milo Test Gateway.
  void submitPaymentApprovalRequest({
    required EventModel event,
    required TicketTier tier,
    required int quantity,
    required double totalAmount,
    required String utrNumber,
    required String attendeeName,
    required String attendeePhone,
    String? organizerUpiId,
    String? proofImageUrl,
    String? note,
    String paymentMethod = 'SELF_UPI_GATEWAY',
    bool autoConfirm = false,
  }) {
    final bookingId =
        'MILO-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final orgUpi = organizerUpiId ?? 'utsav.events@okhdfcbank';
    final status = autoConfirm ? 'CONFIRMED' : 'PENDING_APPROVAL';

    final newTicket = BookedTicket(
      bookingId: bookingId,
      event: event,
      tier: tier,
      quantity: quantity,
      totalAmount: totalAmount,
      bookingTime: 'Just now',
      qrData: 'MILO_PASS_${event.id}_${DateTime.now().millisecondsSinceEpoch}',
      status: status,
      paymentMethod: paymentMethod,
      utrNumber: utrNumber,
      organizerUpiId: orgUpi,
      attendeeName: attendeeName,
      attendeePhone: attendeePhone,
      paymentProofUrl: proofImageUrl ?? '',
      uid: MiloSessionService.currentUid,
    );

    _allTickets.insert(0, newTicket);

    if (autoConfirm) {
      _systemNotifications.insert(0, {
        'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
        'title': '🎟️ Pass Confirmed!',
        'body': 'Payment of ₹${totalAmount.toStringAsFixed(0)} verified via $paymentMethod. Your QR ticket for "${event.title}" is ready.',
        'time': 'Just now',
        'type': 'ticket',
        'isUnread': true,
      });
      _persistBooking(newTicket, organizerUid: '');
      notifyListeners();
      return;
    }

    final req = PaymentApprovalRequest(
      id: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      bookingId: bookingId,
      eventId: event.id,
      eventTitle: event.title,
      tierName: tier.name,
      quantity: quantity,
      totalAmount: totalAmount,
      attendeeName: attendeeName,
      attendeePhone: attendeePhone,
      utrNumber: utrNumber,
      organizerUpiId: orgUpi,
      timestamp: 'Just now',
      status: 'PENDING',
      proofImageUrl: proofImageUrl ?? '',
      note: note ?? '',
    );
    _approvalRequests.insert(0, req);

    _systemNotifications.insert(0, {
      'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
      'title': '⚡ New Payment Approval Request!',
      'body': '$attendeeName paid ₹${totalAmount.toStringAsFixed(0)} via $paymentMethod (UTR: $utrNumber) for ${tier.name}. Tap to verify.',
      'time': 'Just now',
      'type': 'approval_request',
      'isUnread': true,
    });

    notifyListeners();
    _persistBooking(newTicket, organizerUid: '');
    _persistRequest(req);
  }

  /// Organizer approves the payment → ticket becomes CONFIRMED.
  void approveRequest(String requestId) {
    final index = _approvalRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    final req = _approvalRequests[index];
    _approvalRequests[index] = req.copyWith(status: 'APPROVED');

    final ticketIndex = _allTickets.indexWhere((t) => t.bookingId == req.bookingId);
    if (ticketIndex != -1) {
      _allTickets[ticketIndex] = _allTickets[ticketIndex].copyWith(status: 'CONFIRMED');
    }

    _systemNotifications.insert(0, {
      'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
      'title': '🎉 Pass Approved by Organizer!',
      'body': 'Your payment of ₹${req.totalAmount.toStringAsFixed(0)} for "${req.eventTitle}" was verified. Digital QR ticket is unlocked!',
      'time': 'Just now',
      'type': 'ticket',
      'isUnread': true,
    });

    notifyListeners();
    _updateRequestStatus(requestId, 'APPROVED');
    _updateBookingStatus(req.bookingId, status: 'CONFIRMED', paymentStatus: 'paid');
  }

  /// Organizer rejects the payment with a reason.
  void rejectRequest(String requestId, String reason) {
    final index = _approvalRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    final req = _approvalRequests[index];
    _approvalRequests[index] = req.copyWith(status: 'REJECTED', rejectionReason: reason);

    final ticketIndex = _allTickets.indexWhere((t) => t.bookingId == req.bookingId);
    if (ticketIndex != -1) {
      _allTickets[ticketIndex] =
          _allTickets[ticketIndex].copyWith(status: 'REJECTED', rejectionReason: reason);
    }

    _systemNotifications.insert(0, {
      'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
      'title': '⚠️ Payment Verification Update',
      'body': 'Organizer flagged payment for "${req.eventTitle}": $reason. Please re-check UTR or contact organizer.',
      'time': 'Just now',
      'type': 'ticket',
      'isUnread': true,
    });

    notifyListeners();
    _updateRequestStatus(requestId, 'REJECTED', rejectionReason: reason);
    _updateBookingStatus(req.bookingId,
        status: 'REJECTED', paymentStatus: 'failed', rejectionReason: reason);
  }

  /// Mark all notifications as read (notifications screen action).
  void markNotificationsRead() {
    for (final n in _systemNotifications) {
      n['isUnread'] = false;
    }
    notifyListeners();
  }

  // ─── Firestore helpers ────────────────────────────────────────────

  void _persistBooking(BookedTicket booking, {String organizerUid = ''}) {
    final db = _db;
    if (db == null) return;
    db.collection('bookings').doc(booking.bookingId).set(
          _bookingToDoc(booking, organizerUid: organizerUid),
          SetOptions(merge: true),
        ).catchError((e) => debugPrint('PaymentApproval booking write error: $e'));
  }

  void _persistRequest(PaymentApprovalRequest req) {
    final db = _db;
    if (db == null) return;
    db
        .collection('payment_requests')
        .doc(req.id)
        .set(_requestToDoc(req), SetOptions(merge: true))
        .catchError((e) => debugPrint('PaymentApproval request write error: $e'));
  }

  void _updateRequestStatus(String requestId, String status, {String rejectionReason = ''}) {
    final db = _db;
    if (db == null) return;
    db.collection('payment_requests').doc(requestId).set({
      'status': status,
      'rejection_reason': rejectionReason,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((e) => debugPrint('request update error: $e'));
  }

  void _updateBookingStatus(
    String bookingId, {
    required String status,
    required String paymentStatus,
    String rejectionReason = '',
  }) {
    final db = _db;
    if (db == null) return;
    db.collection('bookings').doc(bookingId).set({
      'status': status,
      'payment_status': paymentStatus,
      'rejection_reason': rejectionReason,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((e) => debugPrint('booking update error: $e'));
  }

  Map<String, dynamic> _bookingToDoc(BookedTicket b, {String organizerUid = ''}) {
    return {
      'booking_ref': b.bookingId,
      'event_id': b.event.id,
      'event_title': b.event.title,
      'event_category': b.event.category,
      'event_date': b.event.date,
      'event_time': b.event.time,
      'event_venue': b.event.venue,
      'event_city': b.event.city,
      'event_banner': b.event.imageUrl,
      'event_organizer': b.event.organizerName,
      'tier_id': b.tier.id,
      'tier_name': b.tier.name,
      'tier_price': b.tier.price,
      'quantity': b.quantity,
      'total_amount': b.totalAmount,
      'attendee_name': b.attendeeName,
      'attendee_phone': b.attendeePhone,
      'user_name': b.attendeeName,
      'user_phone': b.attendeePhone,
      'qr_hash_token': b.qrData,
      'payment_status': b.status == 'CONFIRMED' ? 'paid' : (b.status == 'REJECTED' ? 'failed' : 'pending'),
      'status': b.status,
      'payment_method': b.paymentMethod,
      'utr_number': b.utrNumber,
      'organizer_upi_id': b.organizerUpiId,
      'payment_proof_url': b.paymentProofUrl,
      'rejection_reason': b.rejectionReason,
      'organizer_uid': organizerUid,
      'uid': b.uid.isNotEmpty ? b.uid : MiloSessionService.currentUid,
      'checked_in': b.checkedIn,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _requestToDoc(PaymentApprovalRequest r) {
    return {
      'booking_id': r.bookingId,
      'event_id': r.eventId,
      'event_title': r.eventTitle,
      'tier_name': r.tierName,
      'quantity': r.quantity,
      'total_amount': r.totalAmount,
      'attendee_name': r.attendeeName,
      'attendee_phone': r.attendeePhone,
      'utr_number': r.utrNumber,
      'organizer_upi_id': r.organizerUpiId,
      'status': r.status,
      'proof_image_url': r.proofImageUrl,
      'note': r.note,
      'rejection_reason': r.rejectionReason,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  PaymentApprovalRequest _mapDocToRequest(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    String timestamp = json['timestamp']?.toString() ?? 'Recently';
    if (createdAt is Timestamp) {
      final diff = DateTime.now().difference(createdAt.toDate());
      if (diff.inMinutes < 1) {
        timestamp = 'Just now';
      } else if (diff.inMinutes < 60) {
        timestamp = '${diff.inMinutes} mins ago';
      } else if (diff.inHours < 24) {
        timestamp = '${diff.inHours}h ago';
      } else {
        timestamp = '${diff.inDays}d ago';
      }
    }
    return PaymentApprovalRequest(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      eventTitle: json['event_title']?.toString() ?? 'Milo Event',
      tierName: json['tier_name']?.toString() ?? 'Pass',
      quantity: ((json['quantity'] as num?)?.toInt()) ?? 1,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      attendeeName: json['attendee_name']?.toString() ?? '',
      attendeePhone: json['attendee_phone']?.toString() ?? '',
      utrNumber: json['utr_number']?.toString() ?? '',
      organizerUpiId: json['organizer_upi_id']?.toString() ?? '',
      timestamp: timestamp,
      status: json['status']?.toString() ?? 'PENDING',
      proofImageUrl: json['proof_image_url']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
    );
  }

  /// Derive the notification feed from approval requests + confirmed tickets.
  void _rebuildNotifications() {
    _systemNotifications.clear();
    for (final r in _approvalRequests) {
      if (r.status == 'PENDING') {
        _systemNotifications.add({
          'id': 'notif-req-${r.id}',
          'title': '⚡ New Payment Approval Request!',
          'body': '${r.attendeeName} submitted ₹${r.totalAmount.toStringAsFixed(0)} via UPI (UTR: ${r.utrNumber}) for ${r.tierName}. Tap to review & approve.',
          'time': r.timestamp,
          'type': 'approval_request',
          'isUnread': true,
        });
      } else if (r.status == 'APPROVED') {
        _systemNotifications.add({
          'id': 'notif-req-${r.id}',
          'title': '🎉 Pass Approved!',
          'body': 'Payment of ₹${r.totalAmount.toStringAsFixed(0)} for "${r.eventTitle}" was verified.',
          'time': r.timestamp,
          'type': 'ticket',
          'isUnread': false,
        });
      } else if (r.status == 'REJECTED') {
        _systemNotifications.add({
          'id': 'notif-req-${r.id}',
          'title': '⚠️ Payment Flagged',
          'body': 'Payment for "${r.eventTitle}" needs attention: ${r.rejectionReason}',
          'time': r.timestamp,
          'type': 'ticket',
          'isUnread': true,
        });
      }
    }
    if (_systemNotifications.isEmpty) {
      _systemNotifications.addAll([
        {
          'id': 'notif-welcome',
          'title': '🎟️ Welcome to Milo!',
          'body': 'Discover events, book passes and manage everything from one place.',
          'time': 'now',
          'type': 'ticket',
          'isUnread': false,
        },
        {
          'id': 'notif-privacy',
          'title': '🔒 Privacy First',
          'body': 'You control who can discover you. Review settings in Safety tab.',
          'time': 'now',
          'type': 'community',
          'isUnread': false,
        },
      ]);
    }
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
