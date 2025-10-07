import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cart_repository.dart';
import '../domain/cart_item.dart';

class CartRepositoryImpl implements CartRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  // --------- PUBLIC API ---------

  @override
  Future<List<CartItem>> loadCart() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _loadLocal();

    final snaps = await _users.doc(uid).collection('cartItems').get();
    final items = snaps.docs.map((d) => CartItem.fromMap(d.data())).toList();

    // mirror in locale per offline/guest
    await _saveLocal(items);
    return items;
  }

  @override
  Future<void> setQty(String productId, int qty) async {
    if (qty <= 0) return remove(productId);
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      final current = await _loadLocal();
      final idx = current.indexWhere((e) => e.productId == productId);
      if (idx != -1) current[idx] = current[idx].copyWith(qty: qty);
      await _saveLocal(current);
      return;
    }
    await _users.doc(uid).collection('cartItems').doc(productId).set(
      {'qty': qty},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> addOrIncrease(CartItem item, {int by = 1}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
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

    final doc = _users.doc(uid).collection('cartItems').doc(item.productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      if (!snap.exists) {
        tx.set(doc, item.copyWith(qty: by).toMap());
      } else {
        final cur = CartItem.fromMap(snap.data()!);
        tx.update(doc, {'qty': cur.qty + by});
      }
    });
  }

  @override
  Future<void> remove(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      final current = await _loadLocal()
        ..removeWhere((e) => e.productId == productId);
      await _saveLocal(current);
      return;
    }
    await _users.doc(uid).collection('cartItems').doc(productId).delete();
  }

  @override
  Future<void> clear() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      await _saveLocal(const []);
      return;
    }
    final col = _users.doc(uid).collection('cartItems');
    final snaps = await col.get();
    for (final d in snaps.docs) {
      await d.reference.delete();
    }
  }

  // --------- LOCAL CACHE (guest/offline) ---------
  static const _k = 'cart_local_v1';

  Future<List<CartItem>> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(CartItem.fromMap).toList();
    // ignore: dead_code
  }

  Future<void> _saveLocal(List<CartItem> items) async {
    final p = await SharedPreferences.getInstance();
    final raw = json.encode(items.map((e) => e.toMap()).toList());
    await p.setString(_k, raw);
  }
}
