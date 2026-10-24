import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'milo_api.dart';

import 'milo_db_service.dart';
import 'milo_session_service.dart';

/// Payment approval + booking store for Jhoomo.
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

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];
  final Map<String, BookedTicket> _buyerTickets = {};
  final Map<String, BookedTicket> _organizerTickets = {};
  final Map<String, PaymentApprovalRequest> _buyerRequests = {};
  final Map<String, PaymentApprovalRequest> _organizerRequests = {};
  bool _initialized = false;
  bool firestoreOnline = false;

  List<PaymentApprovalRequest> get approvalRequests =>
      List.unmodifiable(_approvalRequests);
  List<PaymentApprovalRequest> get pendingRequests =>
      _approvalRequests.where((r) => r.status == 'PENDING').toList();
  List<BookedTicket> get userTickets {
    final uid = MiloSessionService.currentUid;
    final phone = normalizePhone(MiloSessionService.currentUserPhone);
    return _allTickets.where((t) {
      if (t.uid.isNotEmpty) return uid.isNotEmpty && t.uid == uid;
      if (kDebugMode) return true;
      return phone.isNotEmpty && normalizePhone(t.attendeePhone) == phone;
    }).toList();
  }

  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_systemNotifications);

  int get pendingCount =>
      _approvalRequests.where((r) => r.status == 'PENDING').length;

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
      if (kDebugMode) {
        _initLocalDemoData();
      }
      _rebuildNotifications();
      notifyListeners();
      return;
    }

    final uid = MiloSessionService.currentUid;
    if (uid.isEmpty) {
      if (kDebugMode) {
        _initLocalDemoData();
      }
      _rebuildNotifications();
      notifyListeners();
      return;
    }

    try {
      if (kDebugMode) {
        await MiloDbService.instance.ensureSeeded();
        await _seedDemoDataIfEmpty(db);
      }

      _watchBookings(db, 'userId', uid, _buyerTickets);
      _watchBookings(db, 'organizerId', uid, _organizerTickets);
      _watchRequests(db, 'user_id', uid, _buyerRequests);
      _watchRequests(db, 'organizer_id', uid, _organizerRequests);

      firestoreOnline = true;
      debugPrint('PaymentApprovalService: Firestore sync active');
    } catch (e) {
      debugPrint('PaymentApprovalService init fallback: $e');
      if (kDebugMode) _initLocalDemoData();
      _rebuildNotifications();
      notifyListeners();
    }
  }

  void _watchBookings(
    FirebaseFirestore db,
    String field,
    String uid,
    Map<String, BookedTicket> target,
  ) {
    _subs.add(
      db
          .collection('bookings')
          .where(field, isEqualTo: uid)
          .limit(300)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        target
          ..clear()
          ..addEntries(snap.docs.map((d) {
            final data = <String, dynamic>{...d.data(), 'document_id': d.id};
            return MapEntry(d.id, MiloDbService.mapBookingDoc(data));
          }));
        _rebuildTickets();
        firestoreOnline = !snap.metadata.isFromCache;
        notifyListeners();
      },
              onError: (e) =>
                  debugPrint('PaymentApproval bookings stream error: $e')),
    );
  }

  void _watchRequests(
    FirebaseFirestore db,
    String field,
    String uid,
    Map<String, PaymentApprovalRequest> target,
  ) {
    _subs.add(
      db
          .collection('payment_requests')
          .where(field, isEqualTo: uid)
          .limit(300)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        target
          ..clear()
          ..addEntries(snap.docs.map((d) {
            final data = <String, dynamic>{...d.data(), 'id': d.id};
            return MapEntry(d.id, _mapDocToRequest(data));
          }));
        _rebuildRequests();
        notifyListeners();
      },
              onError: (e) =>
                  debugPrint('PaymentApproval requests stream error: $e')),
    );
  }

  void _rebuildTickets() {
    final merged = <String, BookedTicket>{
      ..._organizerTickets,
      ..._buyerTickets
    };
    _allTickets
      ..clear()
      ..addAll(merged.values);
    _rebuildNotifications();
  }

  void _rebuildRequests() {
    final merged = <String, PaymentApprovalRequest>{
      ..._organizerRequests,
      ..._buyerRequests
    };
    _approvalRequests
      ..clear()
      ..addAll(merged.values);
    _rebuildNotifications();
  }

  // Local demo fallback (Firestore unavailable)

  void _initLocalDemoData() {
    if (!kDebugMode) return;
    if (_allTickets.isNotEmpty || _approvalRequests.isNotEmpty) return;
    // Skip demo data in release builds
  }

  BookedTicket _demoPendingTicket() {
    const demoTier = TicketTier(
      id: 'tier_ga',
      name: 'General Admission',
      price: 928,
      currency: 'INR',
      availableApprox: 100,
      totalCapacity: 200,
      soldOut: false,
    );
    const demoEvent = EventModel(
      id: 'ev_lucknow',
      title: 'Sunidhi Chauhan Live in Concert - Lucknow',
      category: 'Concert',
      date: 'Sat, 14 Nov',
      time: '07:00 PM',
      venue: 'Ekana International Stadium',
      city: 'Lucknow',
      startingPrice: 999,
      imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
      organizerName: 'JHOOMO Live',
      tags: ['Music', 'Concert'],
      ticketsLeft: 120,
      description: 'Sunidhi Chauhan live at Ekana Stadium',
      ticketTiers: [demoTier],
    );
    return BookedTicket(
      bookingId: 'JHOOMO-SELF-PAY-9842',
      event: demoEvent,
      tier: demoTier,
      quantity: 1,
      totalAmount: 928,
      bookingTime: 'Today, 03:45 PM',
      qrData: 'MILO_PENDING_APPROVAL_9842',
      status: 'PENDING_APPROVAL',
      paymentMethod: 'RAZORPAY',
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
        bookingId: 'JHOOMO-SELF-PAY-9842',
        eventId: '',
        eventTitle: '',
        tierName: '',
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
        bookingId: 'JHOOMO-SELF-PAY-7719',
        eventId: '',
        eventTitle: '',
        tierName: '',
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
  /// have real records on a fresh project. Debug builds only.
  Future<void> _seedDemoDataIfEmpty(FirebaseFirestore db) async {
    if (!kDebugMode) return;
    return; // disabled for customer app live cleanup
    try {
      final demoBooking = _demoPendingTicket();
      final bookingRef = db.collection('bookings').doc(demoBooking.bookingId);
      final bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        await bookingRef.set(_bookingToDoc(demoBooking));
      }
      // Demo seed removed for production.

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

  // Writes — server-authoritative, client never writes money records.

  String? _lastActionError;
  String? get lastActionError => _lastActionError;

  /// Submit a legacy manual test-gateway payment for verification.
  /// for organizer verification. Inventory is reserved only by the backend.
  Future<bool> submitPaymentApprovalRequest({
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
    String paymentMethod = 'RAZORPAY',
  }) async {
    _lastActionError = null;
    final backendMethod = switch (paymentMethod) {
      'RAZORPAY' => 'RAZORPAY',
      'MILO_TEST_GATEWAY' => 'RAZORPAY',
      _ => 'RAZORPAY',
    };

    try {
      final response = await MiloApi.instance.submitManualPayment(
        eventId: event.id,
        tierId: tier.id,
        quantity: quantity,
        method: backendMethod,
        utr: utrNumber,
        attendeeName: attendeeName,
        attendeePhone: attendeePhone,
        organizerUpiId: organizerUpiId,
        proofUrl: proofImageUrl,
        note: note,
      );
      final bookingId = response['bookingId']?.toString() ?? '';
      final requestId = response['requestId']?.toString() ?? '';
      final pricing = response['pricing'];
      final amountPaise =
          pricing is Map ? (pricing['totalPaise'] as num?)?.toDouble() : null;
      final amount = amountPaise != null ? amountPaise / 100 : totalAmount;

      if (bookingId.isEmpty || requestId.isEmpty) {
        _lastActionError = 'Payment request could not be created.';
        notifyListeners();
        return false;
      }

      final req = PaymentApprovalRequest(
        id: requestId,
        bookingId: bookingId,
        eventId: event.id,
        eventTitle: event.title,
        tierName: tier.name,
        quantity: quantity,
        totalAmount: amount,
        attendeeName: attendeeName,
        attendeePhone: attendeePhone,
        utrNumber: utrNumber,
        organizerUpiId: organizerUpiId ?? '',
        timestamp: 'Just now',
        status: 'PENDING',
        proofImageUrl: proofImageUrl ?? '',
        note: note ?? '',
      );
      _buyerRequests[requestId] = req;
      _rebuildRequests();

      _buyerTickets[bookingId] = BookedTicket(
        bookingId: bookingId,
        event: event,
        tier: tier,
        quantity: quantity,
        totalAmount: amount,
        bookingTime: 'Just now',
        qrData: 'MILO_PENDING_$bookingId',
        status: 'PENDING_APPROVAL',
        paymentMethod: backendMethod,
        utrNumber: utrNumber,
        organizerUpiId: organizerUpiId ?? '',
        attendeeName: attendeeName,
        attendeePhone: attendeePhone,
        paymentProofUrl: proofImageUrl ?? '',
        uid: MiloSessionService.currentUid,
      );
      _rebuildTickets();
      notifyListeners();
      return true;
    } on MiloApiException catch (e) {
      _lastActionError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _lastActionError = 'Could not submit payment. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Organizer approves the payment → backend issues the tickets.
  Future<bool> approveRequest(String requestId) async {
    _lastActionError = null;
    try {
      await MiloApi.instance
          .reviewManualPayment(requestId: requestId, decision: 'approve');
      final index = _approvalRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        final req = _approvalRequests[index];
        _approvalRequests[index] = req.copyWith(status: 'APPROVED');
        final ticketIndex =
            _allTickets.indexWhere((t) => t.bookingId == req.bookingId);
        if (ticketIndex != -1) {
          _allTickets[ticketIndex] =
              _allTickets[ticketIndex].copyWith(status: 'CONFIRMED');
        }
        _rebuildNotifications();
      }
      notifyListeners();
      return true;
    } on MiloApiException catch (e) {
      _lastActionError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _lastActionError = 'Could not approve this payment.';
      notifyListeners();
      return false;
    }
  }

  /// Organizer rejects the payment with a reason.
  Future<bool> rejectRequest(String requestId, String reason) async {
    _lastActionError = null;
    try {
      await MiloApi.instance.reviewManualPayment(
        requestId: requestId,
        decision: 'reject',
        reason: reason.isEmpty ? 'Payment could not be verified.' : reason,
      );
      final index = _approvalRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        final req = _approvalRequests[index];
        _approvalRequests[index] =
            req.copyWith(status: 'REJECTED', rejectionReason: reason);
        final ticketIndex =
            _allTickets.indexWhere((t) => t.bookingId == req.bookingId);
        if (ticketIndex != -1) {
          _allTickets[ticketIndex] = _allTickets[ticketIndex]
              .copyWith(status: 'REJECTED', rejectionReason: reason);
        }
        _rebuildNotifications();
      }
      notifyListeners();
      return true;
    } on MiloApiException catch (e) {
      _lastActionError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _lastActionError = 'Could not reject this payment.';
      notifyListeners();
      return false;
    }
  }

  /// Mark all notifications as read (notifications screen action).
  void markNotificationsRead() {
    for (final n in _systemNotifications) {
      n['isUnread'] = false;
    }
    notifyListeners();
  }

  // Firestore helpers (debug seed only)

  Map<String, dynamic> _bookingToDoc(BookedTicket b,
      {String organizerUid = ''}) {
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
      'payment_status': b.status == 'CONFIRMED'
          ? 'paid'
          : (b.status == 'REJECTED' ? 'failed' : 'pending'),
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
      eventTitle: json['event_title']?.toString() ?? 'Jhoomo Event',
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
          'title': ' New Payment Approval Request!',
          'body':
              '${r.attendeeName} submitted ₹${r.totalAmount.toStringAsFixed(0)} via UPI (UTR: ${r.utrNumber}) for ${r.tierName}. Tap to review & approve.',
          'time': r.timestamp,
          'type': 'approval_request',
          'isUnread': true,
        });
      } else if (r.status == 'APPROVED') {
        _systemNotifications.add({
          'id': 'notif-req-${r.id}',
          'title': ' Pass Approved!',
          'body':
              'Payment of ₹${r.totalAmount.toStringAsFixed(0)} for "${r.eventTitle}" was verified.',
          'time': r.timestamp,
          'type': 'ticket',
          'isUnread': false,
        });
      } else if (r.status == 'REJECTED') {
        _systemNotifications.add({
          'id': 'notif-req-${r.id}',
          'title': ' Payment Flagged',
          'body':
              'Payment for "${r.eventTitle}" needs attention: ${r.rejectionReason}',
          'time': r.timestamp,
          'type': 'ticket',
          'isUnread': true,
        });
      } else if (r.status == 'EXPIRED') {
        _systemNotifications.add({
          'id': 'notif-req-${r.id}',
          'title': 'Payment request expired',
          'body':
              'The organizer did not verify your payment for "${r.eventTitle}" in time. Your seats were released.',
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
          'title': ' Welcome to Jhoomo!',
          'body':
              'Discover events, book passes and manage everything from one place.',
          'time': 'now',
          'type': 'ticket',
          'isUnread': false,
        },
        {
          'id': 'notif-privacy',
          'title': ' Privacy First',
          'body':
              'You control who can discover you. Review settings in Safety tab.',
          'time': 'now',
          'type': 'community',
          'isUnread': false,
        },
      ]);
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }

  void injectDirectNotification(Map<String, dynamic> notif) {
    _systemNotifications.insert(0, notif);
    notifyListeners();
  }
}
