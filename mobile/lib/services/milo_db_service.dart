import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';


/// Database Service for Jhoomo App — backed by Firebase Firestore.
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
      // 1. Admin config
      final adminDoc = await db.collection('milo_config').doc('admins').get();
      if (!adminDoc.exists) {
        await db.collection('milo_config').doc('admins').set({
          'phones': [],
          'note': 'Super Admin allowed phone numbers',
        });
      }

      // 2. Clean dummy collections data if any lingering
      final dummyCollections = ['beacons', 'cabs', 'meets', 'rooms', 'participants'];
      for (final coll in dummyCollections) {
        try {
          final snap = await db.collection(coll).limit(20).get();
          for (final doc in snap.docs) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      // 3. Clean old events (except the 5 target ones)
      final curatedIds = {
        'ev_lucknow',
        'ev_kanpur',
        'ev_agra',
        'ev_delhi',
        'ev_mumbai',
      };
      try {
        final evSnap = await db.collection('events').get();
        for (final doc in evSnap.docs) {
          if (!curatedIds.contains(doc.id)) {
            await doc.reference.delete();
          }
        }
      } catch (_) {}

      // 4. Seed the 5 Curated Events: Lucknow, Kanpur, Agra, Delhi, Mumbai
      final curatedEvents = [
        {
          'id': 'ev_lucknow',
          'title': 'Sunidhi Chauhan Live in Concert - Lucknow',
          'category': 'Concert',
          'city': 'Lucknow',
          'venue': 'Ekana International Stadium, Sector 7, Gomti Nagar Ext',
          'date': '2026-11-14T19:00:00Z',
          'banner': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
          'rating': 4.9,
          'ratingCount': 2840,
          'price': 999.0,
          'soldOut': false,
          'featured': true,
          'description': 'Experience an electrifying musical night with Bollywood superstar Sunidhi Chauhan performing her greatest chartbusters live at Ekana Stadium, Lucknow.',
          'ticketTiers': [
            {'id': 't1', 'name': 'Silver Phase 1', 'price': 999.0, 'available': 450},
            {'id': 't2', 'name': 'Gold Fanpit', 'price': 2499.0, 'available': 150},
            {'id': 't3', 'name': 'VIP Lounge Table', 'price': 4999.0, 'available': 40},
          ],
        },
        {
          'id': 'ev_kanpur',
          'title': 'Kanpur EDM Rave & Neon Beats Fest',
          'category': 'Music Festival',
          'city': 'Kanpur',
          'venue': 'Green Park Stadium Ground, Civil Lines',
          'date': '2026-11-20T18:00:00Z',
          'banner': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
          'rating': 4.8,
          'ratingCount': 1420,
          'price': 699.0,
          'soldOut': false,
          'featured': true,
          'description': 'Kanpurs biggest electronic dance music festival featuring international DJs, visual laser mapping, food trucks, and unforgettable festival vibes.',
          'ticketTiers': [
            {'id': 't1', 'name': 'Early Bird GA', 'price': 699.0, 'available': 300},
            {'id': 't2', 'name': 'VIP Stage Access', 'price': 1799.0, 'available': 90},
          ],
        },
        {
          'id': 'ev_agra',
          'title': 'Taj Heritage Sufi & Ghazal Night',
          'category': 'Sufi & Cultural',
          'city': 'Agra',
          'venue': 'Taj Heritage Courtyard, Fatehabad Road',
          'date': '2026-11-27T19:30:00Z',
          'banner': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?auto=format&fit=crop&w=1200&q=80',
          'rating': 4.95,
          'ratingCount': 960,
          'price': 799.0,
          'soldOut': false,
          'featured': true,
          'description': 'An enchanting, soulful evening of classical Sufi melodies, live qawwali, and ghazals under the starry Agra skies with curated Awadhi & Mughlai delicacies.',
          'ticketTiers': [
            {'id': 't1', 'name': 'Courtyard Seating', 'price': 799.0, 'available': 200},
            {'id': 't2', 'name': 'Royal Diwan Front', 'price': 1999.0, 'available': 60},
          ],
        },
        {
          'id': 'ev_delhi',
          'title': 'Delhi Comic Con & Pop Culture Expo',
          'category': 'Expo & Pop Culture',
          'city': 'Delhi',
          'venue': 'Pragati Maidan, Hall 4, Mathura Road, New Delhi',
          'date': '2026-12-05T11:00:00Z',
          'banner': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
          'rating': 4.88,
          'ratingCount': 5320,
          'price': 899.0,
          'soldOut': false,
          'featured': true,
          'description': 'The ultimate pop culture celebration in NCR! Cosplay contests, celebrity meet-and-greets, exclusive merch stalls, gaming zones, and anime screenings.',
          'ticketTiers': [
            {'id': 't1', 'name': 'Single Day Pass', 'price': 899.0, 'available': 500},
            {'id': 't2', 'name': 'Super Fan 3-Day Pass', 'price': 2299.0, 'available': 120},
          ],
        },
        {
          'id': 'ev_mumbai',
          'title': 'Mumbai Sunset Yacht & Sundowner Party',
          'category': 'Nightlife & Experience',
          'city': 'Mumbai',
          'venue': 'Jetty 5, Gateway of India, Colaba',
          'date': '2026-12-12T16:30:00Z',
          'banner': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
          'rating': 4.92,
          'ratingCount': 3110,
          'price': 1499.0,
          'soldOut': false,
          'featured': true,
          'description': 'Sail into the Arabian Sea with Mumbais most exclusive yacht sundowner. Live deep house DJs, premium cocktails, and panoramic sunset views across the skyline.',
          'ticketTiers': [
            {'id': 't1', 'name': 'Sundowner Cruise Pass', 'price': 1499.0, 'available': 80},
            {'id': 't2', 'name': 'VIP Deck + Drinks', 'price': 3499.0, 'available': 25},
          ],
        },
      ];

      for (final ev in curatedEvents) {
        await db.collection('events').doc(ev['id'] as String).set(ev, SetOptions(merge: true));
      }

      _seeded = true;
      debugPrint('MiloDb: 5 Curated Events Seeded for Lucknow, Kanpur, Agra, Delhi, Mumbai.');
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
 return [];
 }

 List<EventModel> _sortedByCreatedDesc(List<EventModel> events, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
 final order = <String, int>{};
 for (var i = 0; i < docs.length; i++) {
 order[docs[i].id] = i;
 }
 events.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
 return events;
 }

 /// All events owned by an organizer (live + pending_review + rejected),
 /// newest first. Used by staff assignment so newly listed shows are
 /// staffable before they go live.
 Future<List<EventModel>> getOrganizerEvents(String organizerUid) async {
 final db = _db;
 if (db == null || organizerUid.isEmpty) return const [];
 try {
 final snap = await db
 .collection('events')
 .where('organizer_uid', isEqualTo: organizerUid)
 .get();
 final rows = snap.docs.map((d) {
 final data = d.data();
 data['document_id'] = d.id;
 return mapEventDoc(data);
 }).toList();
 rows.sort((a, b) => a.date.compareTo(b.date));
 return rows;
 } catch (e) {
 debugPrint('MiloDb organizer events note: $e');
 return const [];
 }
 }

 /// Realtime stream of live events (used by home/explore refresh).
 Stream<List<EventModel>> watchEvents() {
 final db = _db;
 if (db == null) return Stream.value([]);
 try {
 return db
 .collection('events')
 .where('status', isEqualTo: 'live')
 .snapshots()
 .map((snap) => snap.docs.map((d) => mapEventDoc({...d.data(), 'id': d.id})).toList())
 .handleError((e) {
 debugPrint('MiloDb watchEvents note: $e');
 return <EventModel>[];
 });
 } catch (e) {
 return Stream.value([]);
 }
 }

 /// Fetch User Bookings / Tickets from Firestore
 Future<List<BookedTicket>> getUserBookings(String userId) async {
 final db = _db;
 if (db != null) {
 try {
 final snapshot = await db
 .collection('bookings')
 .where('userId', isEqualTo: userId)
 .orderBy('created_at', descending: true)
 .limit(200)
 .get();
 final rows = snapshot.docs.map((d) => d.data()).toList();
 return rows.map(_mapDocToBookedTicket).toList();
 } catch (e) {
   debugPrint('MiloDb getUserBookings note: $e');
 }
 }
 return [];
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
    return [];
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

 // Event publishing (Organizer → Admin review → live) 

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

 // QR Check-in (Server-side validation, atomic) 

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
 if (code.toUpperCase().startsWith('JHOOMO-')) {
 query = query.where('booking_ref', isEqualTo: code);
 } else {
 query = query.where('qr_hash_token', isEqualTo: code);
 }
 final snap = await query.limit(1).get();
 if (snap.docs.isEmpty) {
 return {'status': 'INVALID', 'message': 'Ticket not found in Jhoomo bookings'};
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
 .fold<int>(0, (total, d) => total + ((d.data()['quantity'] as num?) ?? 1).toInt());
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
 title: json['title']?.toString() ?? 'Jhoomo Event',
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
 description: json['description']?.toString() ?? 'Live event on Jhoomo app',
      ticketTiers: tiers,
 customTermsAndConditions: json['refund_policy']?.toString() ?? '',
 );
 }

 BookedTicket _mapDocToBookedTicket(Map<String, dynamic> json) => mapBookingDoc(json);

  /// Public mapper so other services (payments, scanner) share one format.
  /// Supports both the legacy snake_case demo docs and the server booking schema.
  static BookedTicket mapBookingDoc(Map<String, dynamic> json) {
  final items = (json['items'] as List?)?.whereType<Map>().toList() ?? const [];
  final firstItem = items.isNotEmpty ? items.first : const <String, dynamic>{};
  final pricing = (json['pricing'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final payment = (json['payment'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final snapshot = (json['eventSnapshot'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

  final tierPrice = (json['tier_price'] as num?)?.toDouble() ??
  ((firstItem['unitPaise'] as num?)?.toDouble() != null
  ? (firstItem['unitPaise'] as num).toDouble() / 100
  : null);
  final total = (json['total_amount'] as num?)?.toDouble() ??
  ((pricing['totalPaise'] as num?)?.toDouble() != null
  ? (pricing['totalPaise'] as num).toDouble() / 100
  : 0);
  final quantity = ((json['quantity'] as num?)?.toInt()) ??
  ((firstItem['qty'] as num?)?.toInt()) ?? 1;
  final startAt = snapshot['startAt'] ?? json['event_start_at'];
  String eventDate = json['event_date']?.toString() ?? 'Upcoming';
  String eventTime = json['event_time']?.toString() ?? '';
  if (startAt is Timestamp) {
  final dt = startAt.toDate();
  eventDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  eventTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  final rawStatus = json['status']?.toString().toLowerCase() ?? 'confirmed';
  final status = switch (rawStatus) {
  'pending_approval' => 'PENDING_APPROVAL',
  'pending_payment' => 'PENDING_APPROVAL',
  'rejected' => 'REJECTED',
  'expired' => 'EXPIRED',
  'cancelled' || 'cancelled_by_user' || 'refunded' => 'CANCELLED',
  _ => 'CONFIRMED',
  };
  final ticketIds = (json['ticketIds'] as List?)?.whereType<String>().toList() ?? const <String>[];

  return BookedTicket(
  bookingId: json['document_id']?.toString() ??
  json['booking_ref']?.toString() ??
  json['refCode']?.toString() ??
  'JHOOMO-PASS',
  event: EventModel(
  id: json['event_id']?.toString() ?? json['eventId']?.toString() ?? 'e1',
  title: json['event_title']?.toString() ??
  snapshot['title']?.toString() ??
  json['event']?['title']?.toString() ??
  'Jhoomo Event',
  category: json['event_category']?.toString() ?? 'Dandiya/Garba',
  date: eventDate,
  time: eventTime.isEmpty ? 'See ticket' : eventTime,
  venue: json['event_venue']?.toString() ??
  snapshot['venueName']?.toString() ??
  json['venue_name']?.toString() ??
  'Venue',
  city: json['event_city']?.toString() ?? 'Lucknow',
  startingPrice: tierPrice ?? total,
  imageUrl: ((json['event_banner'] ?? snapshot['posterUrl'] ?? json['banner_url'])
  ?.toString()
  .isNotEmpty ==
  true)
  ? (json['event_banner'] ?? snapshot['posterUrl'] ?? json['banner_url']).toString()
  : 'https://images.unsplash.com/photo-1600093463592-8e36ae95ef56?auto=format&fit=crop&w=800&q=80',
  organizerName: json['event_organizer']?.toString() ?? 'Utsav Events & Club',
  tags: const ['Verified'],
  ticketsLeft: 42,
  description: 'Jhoomo Official Event Pass',
      ticketTiers: const [],
  ),
  tier: TicketTier(
  id: json['tier_id']?.toString() ?? firstItem['tierId']?.toString() ?? 'tier_1',
  name: json['tier_name']?.toString() ?? firstItem['tierName']?.toString() ?? 'Pass',
  price: tierPrice ?? total,
  description: 'Verified Pass',
  perks: const ['Entry Pass'],
  available: 20,
  ),
  quantity: quantity,
  totalAmount: total,
  bookingTime: json['booking_time']?.toString() ?? 'Recently',
  qrData: json['qr_hash_token']?.toString() ??
  (ticketIds.isNotEmpty ? ticketIds.first : 'MILO_SECURE_PASS_VERIFIED'),
  status: status,
  paymentMethod: json['payment_method']?.toString() ??
  payment['method']?.toString() ??
  payment['provider']?.toString() ??
  'MILO_TEST_GATEWAY',
  utrNumber: json['utr_number']?.toString() ?? payment['utr']?.toString() ?? '',
  organizerUpiId: json['organizer_upi_id']?.toString() ?? payment['organizerUpiId']?.toString() ?? '',
  attendeeName: json['attendee_name']?.toString() ??
  json['user_name']?.toString() ??
  (firstItem['holderNames'] is List && (firstItem['holderNames'] as List).isNotEmpty
  ? (firstItem['holderNames'] as List).first.toString()
  : 'Jhoomo Guest'),
  attendeePhone: json['attendee_phone']?.toString() ?? json['user_phone']?.toString() ?? '',
  paymentProofUrl: json['payment_proof_url']?.toString() ?? payment['proofUrl']?.toString() ?? '',
  rejectionReason: json['rejection_reason']?.toString() ?? json['rejectionReason']?.toString() ?? '',
  uid: json['uid']?.toString() ?? json['userId']?.toString() ?? '',
  checkedIn: json['checked_in'] == true,
  );
  }

 BeaconModel _mapDocToBeacon(Map<String, dynamic> json) {
 final max = ((json['squad_size_max'] as num?)?.toInt()) ?? 4;
 final current = ((json['squad_size_current'] as num?)?.toInt()) ?? 1;
 return BeaconModel(
 id: json['id']?.toString() ?? json['document_id']?.toString() ?? 'b1',
 userName: json['creator_name']?.toString() ?? 'Jhoomo Host',
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
