import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'mock_data.dart';

/// Database Service for Milo App — backed by Firebase Firestore.
/// Falls back to bundled mock data when Firestore is unreachable so the
/// UI never breaks (offline / not-configured environments).
class MiloDbService {
  static final MiloDbService instance = MiloDbService._();
  MiloDbService._();

  static bool _seeded = false;
  static bool _seeding = false;

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('MiloDb Firestore unavailable: $e');
      return null;
    }
  }

  /// Ensure demo data exists in Firestore so every panel has real records.
  Future<void> ensureSeeded() async {
    if (_seeded || _seeding) return;
    final db = _db;
    if (db == null) return;
    _seeding = true;
    try {
      final eventsSnap = await db.collection('events').limit(1).get();
      if (eventsSnap.docs.isEmpty) {
        debugPrint('MiloDb: seeding events into Firestore...');
        final batch = db.batch();
        for (final event in MockData.events) {
          final ref = db.collection('events').doc(event.id);
          batch.set(ref, _eventToDoc(event));
        }
        await batch.commit();
      }

      final beaconsSnap = await db.collection('beacons').limit(1).get();
      if (beaconsSnap.docs.isEmpty) {
        final batch = db.batch();
        int i = 0;
        for (final beacon in MockData.liveBeacons) {
          i++;
          final ref = db.collection('beacons').doc('seed_$i');
          batch.set(ref, {
            'id': 'seed_$i',
            'creator_name': beacon.userName,
            'activity_type': beacon.title,
            'category': beacon.tag,
            'location_name': beacon.location,
            'squad_size_max': beacon.spotsLeft + 1,
            'squad_size_current': 1,
            'status': 'active',
            'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2))),
            'created_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // Admin allowlist (phone numbers that may grant Super Admin access).
      final adminDoc = await db.collection('milo_config').doc('admins').get();
      if (!adminDoc.exists) {
        await db.collection('milo_config').doc('admins').set({
          'phones': ['9876543210', '7000000000'],
          'note': 'Add phone numbers (10 digit, no +91) allowed to select Super Admin role.',
        });
      }

      _seeded = true;
      debugPrint('MiloDb: Firestore seed complete.');
    } catch (e) {
      debugPrint('MiloDb seed note: $e');
    } finally {
      _seeding = false;
    }
  }

  /// Fetch Live Events from Firestore
  Future<List<EventModel>> getEvents({String? city, String? category}) async {
    final db = _db;
    if (db != null) {
      try {
        await ensureSeeded();
        Query<Map<String, dynamic>> query = db
            .collection('events')
            .where('status', isEqualTo: 'live');

        if (city != null && city != 'All Cities' && city != 'All') {
          query = query.where('city', isEqualTo: city);
        }
        if (category != null && category != 'All' && category != 'All Categories') {
          query = query.where('category', isEqualTo: category);
        }

        // Equality-only filters (no orderBy) avoid the need for composite
        // indexes; sorting happens client-side below.
        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          return _sortedByCreatedDesc(snapshot.docs.map((doc) {
            final data = doc.data();
            data['document_id'] = doc.id;
            return mapEventDoc(data);
          }).toList(), snapshot.docs);
        }
        // Server-side filters can return empty on partial indexes — retry plain query.
        final plain = await db.collection('events').get();
        final liveDocs = plain.docs.where((d) => d.data()['status'] == 'live').toList();
        if (liveDocs.isNotEmpty) {
          final filtered = liveDocs.where((d) {
            final data = d.data();
            if (city != null && city != 'All Cities' && city != 'All' && data['city'] != city) {
              return false;
            }
            if (category != null && category != 'All' && category != 'All Categories' && data['category'] != category) {
              return false;
            }
            return true;
          }).toList();
          final rows = filtered.map((d) {
            final data = d.data();
            data['document_id'] = d.id;
            return mapEventDoc(data);
          }).toList();
          if (rows.isNotEmpty) return rows;
        }
      } catch (e) {
        debugPrint('MiloDb Live Events Note: $e');
        // Last resort: plain read + client-side filter (needs no indexes).
        try {
          final plain = await db.collection('events').get();
          final rows = plain.docs.where((d) => d.data()['status'] == 'live').map((d) {
            final data = d.data();
            data['document_id'] = d.id;
            return mapEventDoc(data);
          }).toList();
          if (rows.isNotEmpty) return rows;
        } catch (e2) {
          debugPrint('MiloDb plain events fallback note: $e2');
        }
      }
    }
    return MockData.events;
  }

  List<EventModel> _sortedByCreatedDesc(List<EventModel> events, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final order = <String, int>{};
    for (var i = 0; i < docs.length; i++) {
      order[docs[i].id] = i;
    }
    events.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
    return events;
  }

  /// Realtime stream of live events (used by home/explore refresh).
  Stream<List<EventModel>> watchEvents() {
    final db = _db;
    if (db == null) return Stream.value(MockData.events);
    try {
      return db
          .collection('events')
          .where('status', isEqualTo: 'live')
          .snapshots()
          .map((snap) => snap.docs.map((d) => mapEventDoc({...d.data(), 'id': d.id})).toList())
          .handleError((e) => debugPrint('MiloDb watchEvents note: $e'));
    } catch (e) {
      return Stream.value(MockData.events);
    }
  }

  /// Fetch User Bookings / Tickets from Firestore
  Future<List<BookedTicket>> getUserBookings(String userId) async {
    final db = _db;
    if (db != null) {
      try {
        final snapshot = await db
            .collection('bookings')
            .orderBy('created_at', descending: true)
            .limit(200)
            .get();
        final rows = snapshot.docs.map((d) => d.data()).toList();
        if (rows.isNotEmpty) {
          return rows.map(_mapDocToBookedTicket).toList();
        }
      } catch (e) {
        debugPrint('MiloDb Bookings Note: $e');
      }
    }
    return MockData.initialBookings;
  }

  /// Create New Booking in Firestore
  Future<bool> createBooking(BookedTicket booking) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.collection('bookings').doc(booking.bookingId).set({
        'booking_ref': booking.bookingId,
        'event_id': booking.event.id,
        'event_title': booking.event.title,
        'event_date': booking.event.date,
        'event_time': booking.event.time,
        'event_venue': booking.event.venue,
        'event_city': booking.event.city,
        'event_banner': booking.event.imageUrl,
        'event_organizer': booking.event.organizerName,
        'tier_id': booking.tier.id,
        'tier_name': booking.tier.name,
        'tier_price': booking.tier.price,
        'quantity': booking.quantity,
        'total_amount': booking.totalAmount,
        'user_name': booking.attendeeName,
        'user_phone': booking.attendeePhone,
        'attendee_name': booking.attendeeName,
        'attendee_phone': booking.attendeePhone,
        'qr_hash_token': booking.qrData,
        'payment_status': booking.status == 'CONFIRMED' ? 'paid' : 'pending',
        'status': booking.status,
        'uid': booking.uid,
        'checked_in': booking.checkedIn,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('MiloDb Booking Save Note: $e');
      return false;
    }
  }

  /// Fetch 2-Hour Spontaneous Beacons from Firestore
  Future<List<BeaconModel>> getActiveBeacons() async {
    final db = _db;
    if (db != null) {
      try {
        await ensureSeeded();
        final snapshot = await db
            .collection('beacons')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();
        final rows = snapshot.docs
            .map((d) => d.data())
            .where((row) =>
                row['status'] == 'active' ||
                ((row['expires_at'] as Timestamp?)?.toDate().isAfter(DateTime.now()) ?? false))
            .toList();
        if (rows.isNotEmpty) return rows.map(_mapDocToBeacon).toList();
      } catch (e) {
        debugPrint('MiloDb Beacons Note: $e');
      }
    }
    return MockData.liveBeacons;
  }

  /// Create Spontaneous Beacon in Firestore
  Future<bool> createBeacon({
    required String creatorName,
    required String activityType,
    required String category,
    required String locationName,
    int squadSizeMax = 4,
  }) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.collection('beacons').add({
        'creator_name': creatorName,
        'activity_type': activityType,
        'category': category,
        'location_name': locationName,
        'squad_size_max': squadSizeMax,
        'squad_size_current': 1,
        'status': 'active',
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2))),
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('MiloDb Beacon Save Note: $e');
      return false;
    }
  }

  // ─── Event publishing (Organizer → Admin review → live) ───────────

  /// Create a new event. Starts as `pending_review` for admin approval
  /// unless the organizer is verified, in which case it goes live directly.
  Future<String?> createEvent({
    required String title,
    required String description,
    required String category,
    required String bannerUrl,
    required String eventDate,
    required String eventTime,
    required String venueName,
    required String city,
    required double startingPrice,
    required String organizerName,
    String organizerUid = '',
    List<String> tags = const [],
    List<Map<String, dynamic>> ticketTiers = const [],
    bool organizerVerified = false,
    int capacity = 200,
    int minAge = 18,
    String refundPolicy = 'Refundable up to 24 hours before the event.',
    String contactPhone = '',
  }) async {
    final db = _db;
    if (db == null) return 'Firestore unavailable.';
    try {
      final ref = db.collection('events').doc();
      await ref.set({
        'id': ref.id,
        'title': title,
        'description': description,
        'category': category,
        'banner_url': bannerUrl,
        'event_date': eventDate,
        'event_time': eventTime,
        'venue_name': venueName,
        'city': city,
        'starting_price': startingPrice,
        'organizer_name': organizerName,
        'organizer_uid': organizerUid,
        'organizer_contact': contactPhone,
        'tags': tags,
        'capacity': capacity,
        'min_age': minAge,
        'refund_policy': refundPolicy,
        'tickets_left': capacity,
        'is_verified_organizer': organizerVerified,
        'is_trending': false,
        'rating': 4.8,
        'ticket_tiers': ticketTiers,
        'status': organizerVerified ? 'live' : 'pending_review',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('MiloDb createEvent error: $e');
      return 'Could not create event: $e';
    }
  }

  // ─── QR Check-in (Server-side validation, atomic) ─────────────────

  /// Validate a scanned QR payload / booking ref against Firestore and
  /// atomically mark the ticket checked-in. Prevents duplicate check-ins
  /// across devices.
  Future<Map<String, dynamic>> verifyAndCheckIn({
    required String payload,
    required String eventId,
    String gate = 'Gate 1',
    String staffName = '',
  }) async {
    final db = _db;
    final code = payload.trim();
    if (code.isEmpty) {
      return {'status': 'INVALID', 'message': 'Empty scan payload'};
    }
    if (db == null) {
      return {'status': 'OFFLINE', 'message': 'Firestore offline — cannot verify ticket'};
    }

    try {
      Query<Map<String, dynamic>> query = db.collection('bookings');
      if (code.toUpperCase().startsWith('MILO-')) {
        query = query.where('booking_ref', isEqualTo: code);
      } else {
        query = query.where('qr_hash_token', isEqualTo: code);
      }
      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) {
        return {'status': 'INVALID', 'message': 'Ticket not found in Milo bookings'};
      }

      final docRef = snap.docs.first.reference;
      final data = snap.docs.first.data();

      final result = await db.runTransaction<Map<String, dynamic>>((tx) async {
        final fresh = await tx.get(docRef);
        final row = fresh.data();
        if (row == null) {
          return {'status': 'INVALID', 'message': 'Ticket no longer exists'};
        }
        final status = (row['status'] ?? '').toString();
        if (status == 'REJECTED') {
          return {
            'status': 'REJECTED',
            'message': 'Booking was rejected / payment not verified'
          };
        }
        if (status == 'PENDING_APPROVAL') {
          return {
            'status': 'PENDING',
            'message': 'Payment still pending organizer approval'
          };
        }
        final bookingEventId = (row['event_id'] ?? '').toString();
        if (eventId.isNotEmpty && bookingEventId.isNotEmpty && bookingEventId != eventId) {
          return {
            'status': 'WRONG_EVENT',
            'message': 'Valid ticket, but for a different event'
          };
        }
        if (row['checked_in'] == true) {
          final at = row['checkin_at'];
          return {
            'status': 'ALREADY_USED',
            'message':
                'Already checked in${at != null ? ' at ${(at as Timestamp).toDate()}' : ''}',
            'booking': row,
          };
        }
        tx.update(docRef, {
          'checked_in': true,
          'checkin_at': FieldValue.serverTimestamp(),
          'checkin_gate': gate,
          'checked_in_by': staffName,
        });
        return {
          'status': 'VALID',
          'message': 'Valid — entry approved',
          'booking': {
            ...row,
            'checked_in': true,
          },
        };
      });
      result['booking'] ??= data;
      return result;
    } catch (e) {
      debugPrint('MiloDb verifyAndCheckIn error: $e');
      return {'status': 'ERROR', 'message': 'Verification failed: $e'};
    }
  }

  /// Checked-in count for an event.
  Future<int> checkedInCount(String eventId) async {
    final db = _db;
    if (db == null) return 0;
    try {
      // Equality-only query (no composite index needed); filter in memory.
      final snap = await db
          .collection('bookings')
          .where('event_id', isEqualTo: eventId)
          .get();
      return snap.docs.where((d) => d.data()['checked_in'] == true).length;
    } catch (e) {
      return 0;
    }
  }

  /// Total paid tickets sold for an event.
  Future<int> soldCount(String eventId) async {
    final db = _db;
    if (db == null) return 0;
    try {
      final snap = await db
          .collection('bookings')
          .where('event_id', isEqualTo: eventId)
          .get();
      return snap.docs
          .where((d) => d.data()['status'] == 'CONFIRMED')
          .fold<int>(0, (sum, d) => sum + ((d.data()['quantity'] as num?) ?? 1).toInt());
    } catch (e) {
      return 0;
    }
  }

  // --- JSON / Firestore Mappers ---

  Map<String, dynamic> _eventToDoc(EventModel event) {
    return {
      'title': event.title,
      'description': event.description,
      'category': event.category,
      'banner_url': event.imageUrl,
      'event_date': event.date,
      'event_time': event.time,
      'venue_name': event.venue,
      'city': event.city,
      'starting_price': event.startingPrice,
      'organizer_name': event.organizerName,
      'is_verified_organizer': event.isVerifiedOrganizer,
      'rating': event.rating,
      'tags': event.tags,
      'tickets_left': event.ticketsLeft,
      'is_trending': event.isTrending,
      'google_maps_url': event.googleMapsUrl,
      'status': 'live',
      'created_at': FieldValue.serverTimestamp(),
      'ticket_tiers': event.ticketTiers
          .map((t) => {
                'id': t.id,
                'tier_name': t.name,
                'name': t.name,
                'price': t.price,
                'description': t.description,
                'perks': t.perks,
                'available_seats': t.available,
                'available': t.available,
              })
          .toList(),
    };
  }

  static EventModel mapEventDoc(Map<String, dynamic> json) {
    final rawTiers =
        (json['ticket_tiers'] ?? json['ticketTiers']) as List<dynamic>? ?? [];
    final tiers = rawTiers.map((t) {
      final map = t is Map<String, dynamic> ? t : Map<String, dynamic>.from(t as Map);
      return TicketTier(
        id: map['id']?.toString() ?? 't1',
        name: map['tier_name']?.toString() ?? map['name']?.toString() ?? 'Pass',
        price: (map['price'] as num?)?.toDouble() ?? 499.0,
        description: map['description']?.toString() ?? 'Entry Pass',
        perks: List<String>.from(map['perks'] ?? ['Event Access']),
        available: ((map['available_seats'] ?? map['available']) as num?)?.toInt() ?? 50,
      );
    }).toList();

    return EventModel(
      id: json['id']?.toString() ?? json['event_id']?.toString() ?? json['document_id']?.toString() ?? 'e1',
      title: json['title']?.toString() ?? 'Milo Event',
      category: json['category']?.toString() ?? 'Events',
      date: json['event_date']?.toString() ?? 'This Weekend',
      time: json['event_time']?.toString() ?? '07:00 PM',
      venue: json['venue_name']?.toString() ?? 'Venue',
      city: json['city']?.toString() ?? 'Lucknow',
      startingPrice: (json['starting_price'] as num?)?.toDouble() ?? 499.0,
      imageUrl: (json['banner_url'] != null && json['banner_url'].toString().isNotEmpty)
          ? json['banner_url'].toString()
          : 'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&w=800&q=80',
      organizerName: json['organizer_name']?.toString() ?? 'Official Organizer',
      isVerifiedOrganizer: json['is_verified_organizer'] ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      tags: List<String>.from(json['tags'] ?? ['Verified']),
      ticketsLeft: ((json['tickets_left'] as num?)?.toInt()) ?? 50,
      isTrending: json['is_trending'] ?? false,
      googleMapsUrl: json['google_maps_url']?.toString() ?? 'https://maps.google.com/?q=Event+Venue',
      description: json['description']?.toString() ?? 'Live event on Milo app',
      ticketTiers: tiers.isNotEmpty ? tiers : MockData.events.first.ticketTiers,
      customTermsAndConditions: json['refund_policy']?.toString() ?? '',
    );
  }

  BookedTicket _mapDocToBookedTicket(Map<String, dynamic> json) => mapBookingDoc(json);

  /// Public mapper so other services (payments, scanner) share one format.
  static BookedTicket mapBookingDoc(Map<String, dynamic> json) {
    final tierPrice = (json['tier_price'] as num?)?.toDouble();
    final total = (json['total_amount'] as num?)?.toDouble() ?? 499.0;
    return BookedTicket(
      bookingId: json['booking_ref']?.toString() ?? 'MILO-PASS',
      event: EventModel(
        id: json['event_id']?.toString() ?? 'e1',
        title: json['event_title']?.toString() ?? json['event']?['title']?.toString() ?? 'Milo Event',
        category: json['event_category']?.toString() ?? 'Dandiya/Garba',
        date: json['event_date']?.toString() ?? 'This Weekend',
        time: json['event_time']?.toString() ?? '07:00 PM onwards',
        venue: json['event_venue']?.toString() ?? json['venue_name']?.toString() ?? 'Venue',
        city: json['event_city']?.toString() ?? 'Lucknow',
        startingPrice: tierPrice ?? total,
        imageUrl: (json['event_banner'] ?? json['banner_url'])?.toString().isNotEmpty == true
            ? (json['event_banner'] ?? json['banner_url']).toString()
            : 'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&w=800&q=80',
        organizerName: json['event_organizer']?.toString() ?? 'Utsav Events & Club',
        tags: const ['Verified'],
        ticketsLeft: 42,
        description: 'Milo Official Event Pass',
        ticketTiers: MockData.events.first.ticketTiers,
      ),
      tier: TicketTier(
        id: json['tier_id']?.toString() ?? 'tier_1',
        name: json['tier_name']?.toString() ?? 'Pass',
        price: tierPrice ?? total,
        description: 'Verified Pass',
        perks: const ['Entry Pass'],
        available: 20,
      ),
      quantity: ((json['quantity'] as num?)?.toInt()) ?? 1,
      totalAmount: total,
      bookingTime: json['booking_time']?.toString() ?? 'Recently',
      qrData: json['qr_hash_token']?.toString() ?? 'MILO_SECURE_PASS_VERIFIED',
      status: json['status']?.toString() ?? 'CONFIRMED',
      paymentMethod: json['payment_method']?.toString() ?? 'MILO_TEST_GATEWAY',
      utrNumber: json['utr_number']?.toString() ?? '',
      organizerUpiId: json['organizer_upi_id']?.toString() ?? '',
      attendeeName: json['attendee_name']?.toString() ?? json['user_name']?.toString() ?? 'Milo Guest',
      attendeePhone: json['attendee_phone']?.toString() ?? json['user_phone']?.toString() ?? '',
      paymentProofUrl: json['payment_proof_url']?.toString() ?? '',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      checkedIn: json['checked_in'] == true,
    );
  }

  BeaconModel _mapDocToBeacon(Map<String, dynamic> json) {
    final max = ((json['squad_size_max'] as num?)?.toInt()) ?? 4;
    final current = ((json['squad_size_current'] as num?)?.toInt()) ?? 1;
    return BeaconModel(
      id: json['id']?.toString() ?? json['document_id']?.toString() ?? 'b1',
      userName: json['creator_name']?.toString() ?? 'Milo Host',
      userAvatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      title: json['activity_type']?.toString() ?? 'Chai & Hangout',
      activity: json['activity_type']?.toString() ?? 'Hangout',
      location: json['location_name']?.toString() ?? 'Nearby Spot',
      timeAgo: 'Live Now',
      spotsLeft: (max - current).clamp(0, max),
      tag: json['category']?.toString() ?? 'Chill',
    );
  }
}
