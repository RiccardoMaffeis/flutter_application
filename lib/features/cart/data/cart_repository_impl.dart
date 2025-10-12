import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cart_repository.dart';
import '../domain/cart_item.dart';

/// Concrete CartRepository backed by:
/// - FirebaseAuth to identify the current user
/// - Firestore ('users/{uid}/cartItems') as the remote source of truth
/// - SharedPreferences as a local fallback/cache when the user is signed-out
class CartRepositoryImpl implements CartRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Convenience accessor for the 'users' collection
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<List<CartItem>> loadCart() async {
    // If not authenticated, load from local storage
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _loadLocal();

    // Load from Firestore: users/{uid}/cartItems
    final snaps = await _users.doc(uid).collection('cartItems').get();
    final items = snaps.docs.map((d) => CartItem.fromMap(d.data())).toList();

    // Cache a local copy for offline/unauthenticated usage
    await _saveLocal(items);
    return items;
  }

  @override
  Future<void> setQty(String productId, int qty) async {
    // Guard: 0 or negative qty means remove the item
    if (qty <= 0) return remove(productId);

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Anonymous/offline path: mutate local cache
      final current = await _loadLocal();
      final idx = current.indexWhere((e) => e.productId == productId);
      if (idx != -1) current[idx] = current[idx].copyWith(qty: qty);
      await _saveLocal(current);
      return;
    }

    // Authenticated path: partial update (merge) on Firestore doc
    await _users.doc(uid).collection('cartItems').doc(productId).set({
      'qty': qty,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addOrIncrease(CartItem item, {int by = 1}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Anonymous/offline path: upsert into local cache
      final current = await _loadLocal();
      final idx = current.indexWhere((e) => e.productId == item.productId);
      if (idx == -1) {
        current.add(item.copyWith(qty: by));
      } else {
        current[idx] = current[idx].copyWith(qty: current[idx].qty + by);
      }
      await _saveLocal(current);
      return;
    }

    // Authenticated path: transactional upsert/increment in Firestore
    final doc = _users.doc(uid).collection('cartItems').doc(item.productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      if (!snap.exists) {
        // Create with initial qty
        tx.set(doc, item.copyWith(qty: by).toMap());
      } else {
        // Increment existing qty atomically
        final cur = CartItem.fromMap(snap.data()!);
        tx.update(doc, {'qty': cur.qty + by});
      }
    });
  }

  @override
  Future<void> remove(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Anonymous/offline: remove from local cache and save
      final current = await _loadLocal()
        ..removeWhere((e) => e.productId == productId);
      await _saveLocal(current);
      return;
    }
    // Authenticated: delete the Firestore doc
    await _users.doc(uid).collection('cartItems').doc(productId).delete();
  }

  @override
  Future<void> clear() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Anonymous/offline: clear local cache
      await _saveLocal(const []);
      return;
    }
    // Authenticated: delete all docs in users/{uid}/cartItems
    final col = _users.doc(uid).collection('cartItems');
    final snaps = await col.get();
    for (final d in snaps.docs) {
      await d.reference.delete();
    }
  }

  // ===== Local persistence (SharedPreferences) =====

  static const _k = 'cart_local_v1';

  /// Reads the cart from local SharedPreferences (JSON-encoded list).
  /// Returns an empty list if nothing is stored.
  Future<List<CartItem>> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(CartItem.fromMap).toList();
  }

  /// Saves the given items list to SharedPreferences as JSON.
  Future<void> _saveLocal(List<CartItem> items) async {
    final p = await SharedPreferences.getInstance();
    final raw = json.encode(items.map((e) => e.toMap()).toList());
    await p.setString(_k, raw);
  }
}
