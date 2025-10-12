/// Cart feature: Riverpod state + controller around a repository-backed cart.
/// - Exposes derived totals (subtotal, tax, total)
/// - Uses AsyncValue to represent loading/error/data for the items list
/// - StateNotifier + StateNotifierProvider to orchestrate mutations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../domain/cart_item.dart';
import '../domain/cart_repository.dart';
import '../data/cart_repository_impl.dart';

/// Immutable state for the cart screen / logic.
class CartState {
  /// Current items wrapped in AsyncValue (loading/error/data).
  final AsyncValue<List<CartItem>> items;

  /// Tax rate applied to the subtotal (default 22%).
  final double taxRate;

  const CartState({required this.items, this.taxRate = 0.22});

  /// Copy-with for partial updates while preserving immutability.
  CartState copyWith({AsyncValue<List<CartItem>>? items, double? taxRate}) =>
      CartState(items: items ?? this.items, taxRate: taxRate ?? this.taxRate);

  /// Sum of line totals when data is available; 0 during loading/error.
  double get subtotal => items.maybeWhen(
    data: (list) => list.fold(0.0, (s, e) => s + e.lineTotal),
    orElse: () => 0.0,
  );

  /// Computed tax based on the current subtotal and taxRate.
  double get tax => subtotal * taxRate;

  /// Final total (subtotal + tax).
  double get total => subtotal + tax;

  /// Initial state: items are loading.
  static CartState initial() => const CartState(items: AsyncLoading());
}

/// Repository provider: supplies the concrete CartRepository implementation.
/// Swap here for testing/mocking (e.g., a FakeCartRepository).
final cartRepositoryProvider = Provider<CartRepository>(
  (_) => CartRepositoryImpl(),
);

/// Controller provider (StateNotifierProvider) exposing CartState.
/// Instantiates the controller and triggers the initial load().
final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) {
    return CartController(ref.read(cartRepositoryProvider))..load();
  },
);

/// Cart controller handling side-effects (repository calls) and state updates.
/// Patterns:
/// - Read-modify-write via copyWith
/// - After each mutation, re-fetch the full cart (simple & consistent)
class CartController extends StateNotifier<CartState> {
  CartController(this._repo) : super(CartState.initial());
  final CartRepository _repo;

  /// Loads items from the repository and sets AsyncData/AsyncError accordingly.
  Future<void> load() async {
    try {
      final items = await _repo.loadCart();
      state = state.copyWith(items: AsyncData(items));
    } catch (e, st) {
      state = state.copyWith(items: AsyncError(e, st));
    }
  }

  /// Adds (or increases) a product in the cart, then refreshes the state.
  /// [qty] defaults to 1; repository handles merge/increment logic.
  Future<void> add(Product p, {int qty = 1}) async {
    await _repo.addOrIncrease(
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

  /// Sets an absolute quantity for a given productId, then refreshes.
  Future<void> setQty(String productId, int qty) async {
    await _repo.setQty(productId, qty);
    await load();
  }

  /// Removes an item by productId, then refreshes.
  Future<void> remove(String productId) async {
    await _repo.remove(productId);
    await load();
  }

  /// Clears the whole cart, then refreshes.
  Future<void> clear() async {
    await _repo.clear();
    await load();
  }
}
