import 'package:flutter_application/features/auth/controllers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../domain/cart_item.dart';
import '../data/cart_repository_firebase.dart';
import '../../../core/firebase/firebase_providers.dart';

class CartState {
  final AsyncValue<List<CartItem>> items;
  final double taxRate;

  const CartState({required this.items, this.taxRate = 0.22});

  CartState copyWith({AsyncValue<List<CartItem>>? items, double? taxRate}) =>
      CartState(items: items ?? this.items, taxRate: taxRate ?? this.taxRate);

  double get subtotal => items.maybeWhen(
        data: (list) => list.fold(0.0, (s, e) => s + e.lineTotal),
        orElse: () => 0.0,
      );

  double get tax => subtotal * taxRate;
  double get total => subtotal + tax;

  static CartState initial() => const CartState(items: AsyncLoading());
}

final cartRepositoryProvider = Provider<CartRepositoryFirebase>(
  (ref) => CartRepositoryFirebase(ref.watch(firestoreProvider)),
);

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(ref, ref.read(cartRepositoryProvider))..load(),
);

class CartController extends StateNotifier<CartState> {
  CartController(this.ref, this._repo) : super(CartState.initial());
  final Ref ref;
  final CartRepositoryFirebase _repo;

  Future<void> load() async {
    try {
      final uid = ref.read(authControllerProvider).value?.uid; // <- o .uid
      if (uid == null) {
        state = state.copyWith(items: const AsyncData([]));
        return;
      }
      final items = await _repo.loadCart(uid);
      state = state.copyWith(items: AsyncData(items));
    } catch (e, st) {
      state = state.copyWith(items: AsyncError(e, st));
    }
  }

  Future<void> add(Product p, {int qty = 1}) async {
    final uid = ref.read(authControllerProvider).value?.uid; // <- o .uid
    if (uid == null) return;
    await _repo.addOrIncrease(
      uid,
      CartItem(
        productId: p.id,
        code: p.code,
        displayName: p.displayName,
        imageUrl: p.imageUrl,
        unitPrice: p.price,
        qty: qty,
      ),
      by: qty,
    );
    await load();
  }

  Future<void> setQty(String productId, int qty) async {
    final uid = ref.read(authControllerProvider).value?.uid; // <- o .uid
    if (uid == null) return;
    await _repo.setQty(uid, productId, qty);
    await load();
  }

  Future<void> remove(String productId) async {
    final uid = ref.read(authControllerProvider).value?.uid; // <- o .uid
    if (uid == null) return;
    await _repo.remove(uid, productId);
    await load();
  }

  Future<void> clear() async {
    final uid = ref.read(authControllerProvider).value?.uid; // <- o .uid
    if (uid == null) return;
    await _repo.clear(uid);
    await load();
  }
}
