import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
 static final FirestoreService instance = FirestoreService._();
 FirestoreService._();

 final FirebaseFirestore _db = FirebaseFirestore.instance;

 Stream<List<Map<String, dynamic>>> getMeetsStream() {
 return _db
 .collection('meets')
 .orderBy('created_at', descending: true)
 .snapshots()
 .map((snapshot) => snapshot.docs.map((doc) {
 final data = doc.data();
 data['id'] = doc.id;
 return data;
 }).toList());
 }

 Future<void> createMeet(Map<String, dynamic> meetData) async {
 await _db.collection('meets').add({
 ...meetData,
 'created_at': FieldValue.serverTimestamp(),
 });
 }

 Future<Map<String, dynamic>?> getUserProfile(String uid) async {
 final doc = await _db.collection('users').doc(uid).get();
 return doc.data();
 }
}
