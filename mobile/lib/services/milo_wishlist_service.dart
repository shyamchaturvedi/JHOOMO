import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'milo_db_service.dart';

/// Wishlist / saved-events store backed by Firestore (`wishlists/{uid}`).
/// Falls back to an in-memory set when Firestore is unreachable so the
/// heart button still responds offline.
class MiloWishlistService extends ChangeNotifier {
 static final MiloWishlistService instance = MiloWishlistService._();
 MiloWishlistService._();

 final Set<String> _ids = {};
 bool _loaded = false;

 bool get isLoaded => _loaded;

 FirebaseFirestore? get _db {
 try {
 return FirebaseFirestore.instance;
 } catch (_) {
 return null;
 }
 }

 bool contains(String eventId) => _ids.contains(eventId);
 bool isWishlisted(String eventId) => _ids.contains(eventId);
 List<String> get ids => _ids.toList();

 Future<void> load(String uid) async {
 final db = _db;
 if (uid.isEmpty) {
 _loaded = true;
 notifyListeners();
 return;
 }
 if (db == null) {
 _loaded = true;
 notifyListeners();
 return;
 }
 try {
 final doc = await db.collection('wishlists').doc(uid).get();
 final data = doc.data();
 final list = List<String>.from(data?['event_ids'] ?? const []);
 _ids
 ..clear()
 ..addAll(list);
 } catch (e) {
 debugPrint('MiloWishlist load note: $e');
 }
 _loaded = true;
 notifyListeners();
 }

 Future<bool> toggle(String uid, String eventId) async {
 final adding = !_ids.contains(eventId);
 if (adding) {
 _ids.add(eventId);
 } else {
 _ids.remove(eventId);
 }
 notifyListeners();

 final db = _db;
 if (db != null && uid.isNotEmpty) {
 try {
 await db.collection('wishlists').doc(uid).set({
 'event_ids': _ids.toList(),
 'updated_at': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (e) {
 debugPrint('MiloWishlist save note: $e');
 }
 }
 return adding;
 }

 Future<List<EventModel>> resolveEvents() async {
 final all = await MiloDbService.instance.getEvents();
 return all.where((e) => _ids.contains(e.id)).toList();
 }
}
