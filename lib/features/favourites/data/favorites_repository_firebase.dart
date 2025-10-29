import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesRepositoryFirebase {
  final FirebaseFirestore _db;
  FavoritesRepositoryFirebase(this._db);

  // Returns the collection reference where a user's favorites are stored.
  // Path shape: users/{uid}/favorites
  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  // Observes the set of favorite product IDs for the given user.
  // Emits a Set<String> of document IDs (product IDs) whenever snapshots change.
  Stream<Set<String>> watchFavorites(String uid) {
    return _col(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  // Toggles a product in the user's favorites.
  // - If the doc exists → delete it (remove from favorites).
  // - If it doesn't → create it with a server timestamp (add to favorites).
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
