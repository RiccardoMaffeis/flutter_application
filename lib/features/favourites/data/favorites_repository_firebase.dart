import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesRepositoryFirebase {
  final FirebaseFirestore _db;
  FavoritesRepositoryFirebase(this._db);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  Stream<Set<String>> watchFavorites(String uid) {
    return _col(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<void> toggle(String uid, String productId) async {
    final doc = _col(uid).doc(productId);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
    } else {
      await doc.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}
