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

  const CartState({
    required this.items,
    this.taxRate = 0.0,
  });

  /// Creates a new state instance overriding any provided fields.
  CartState copyWith({AsyncValue<List<CartItem>>? items, double? taxRate}) =>
      CartState(items: items ?? this.items, taxRate: taxRate ?? this.taxRate);

  /// Sum of all line totals (price * qty) when data is available; 0.0 otherwise.
  double get subtotal => items.maybeWhen(
    data: (list) => list.fold(0.0, (s, e) => s + e.lineTotal),
    orElse: () => 0.0,
  );

  double get tax => 0.0;
  double get total => subtotal;

  /// Initial state with loading items.
  static CartState initial() =>
      const CartState(items: AsyncLoading(), taxRate: 0.0);
}

/// Provides a concrete Firebase-backed repository for the cart.
/// Reads the shared Firestore instance from `firestoreProvider`.
final cartRepositoryProvider = Provider<CartRepositoryFirebase>(
  (ref) => CartRepositoryFirebase(ref.watch(firestoreProvider)),
);

/// Exposes the CartController as a StateNotifierProvider.
/// It eagerly calls `load()` to populate the initial items.
final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(ref, ref.read(cartRepositoryProvider))..load(),
);

/// Handles all cart business logic (load/add/update/remove/clear).
/// Persists data via `CartRepositoryFirebase` and reads the current user
/// from `authControllerProvider`.
class CartController extends StateNotifier<CartState> {
  CartController(this.ref, this._repo) : super(CartState.initial());
  final Ref ref;
  final CartRepositoryFirebase _repo;

  /// Loads cart items for the current user. If no user is signed in,
  /// sets an empty list.
  Future<void> load() async {
    try {
      final uid = ref.read(authControllerProvider).value?.uid;
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

  /// Adds a product to the cart or increases its quantity by `qty`.
  /// Reloads the state after the repository call.
  Future<void> add(Product p, {int qty = 1}) async {
    final uid = ref.read(authControllerProvider).value?.uid;
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

  /// Sets an absolute quantity for a specific product in the cart.
  /// If qty <= 0, the item will be removed by the repo. Reloads afterwards.
  Future<void> setQty(String productId, int qty) async {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) return;
    await _repo.setQty(uid, productId, qty);
    await load();
  }

  /// Removes a product line from the cart, then reloads.
  Future<void> remove(String productId) async {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) return;
    await _repo.remove(uid, productId);
    await load();
  }

  /// Clears the entire cart for the current user, then reloads.
  Future<void> clear() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) return;
    await _repo.clear(uid);
    await load();
  }
}
