import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/cart_item.dart';

class CartRepositoryFirebase {
  final FirebaseFirestore _db;
  CartRepositoryFirebase(this._db);

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc('itemsRoot')
          .collection('items');

  Future<List<CartItem>> loadCart(String uid) async {
    final snap = await _items(uid).get();
    return snap.docs.map((d) {
      final m = d.data();
      return CartItem(
        productId: d.id,
        code: (m['code'] as String?) ?? '',
        displayName: (m['displayName'] as String?) ?? '',
        imageUrl: (m['imageUrl'] as String?) ?? '',
        unitPrice: (m['price'] as num?)?.toDouble() ?? 0.0,
        qty: (m['qty'] ?? 0) as int,
      );
    }).toList();
  }

  Future<void> addOrIncrease(String uid, CartItem item, {int by = 1}) async {
    final doc = _items(uid).doc(item.productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final cur = (snap.data()?['qty'] ?? 0) as int;
      tx.set(
        doc,
        {
          'qty': cur + by,
          'price': item.unitPrice,
          'code': item.code,
          'displayName': item.displayName,
          'imageUrl': item.imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> setQty(String uid, String productId, int qty) async {
    final doc = _items(uid).doc(productId);
    if (qty <= 0) {
      await doc.delete();
    } else {
      await doc.set(
        {'qty': qty, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  Future<void> remove(String uid, String productId) =>
      _items(uid).doc(productId).delete();

  Future<void> clear(String uid) async {
    final batch = _db.batch();
    final snap = await _items(uid).get();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // Conteggio live per badge
  Stream<int> watchCount(String uid) {
    return _items(uid).snapshots().map((s) => s.docs.fold<int>(
        0, (acc, d) => acc + (((d.data()['qty'] ?? 0) as int))));
  }
}
