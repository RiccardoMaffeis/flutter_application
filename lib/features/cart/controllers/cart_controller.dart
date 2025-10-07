import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../domain/cart_item.dart';
import '../domain/cart_repository.dart';
import '../data/cart_repository_impl.dart';

class CartState {
  final AsyncValue<List<CartItem>> items;
  final double taxRate;

  const CartState({
    required this.items,
    this.taxRate = 0.22, // 22% IVA (modifica se vuoi)
  });

  CartState copyWith({
    AsyncValue<List<CartItem>>? items,
    double? taxRate,
  }) => CartState(items: items ?? this.items, taxRate: taxRate ?? this.taxRate);

  double get subtotal => items.maybeWhen(
        data: (list) => list.fold(0.0, (s, e) => s + e.lineTotal),
        orElse: () => 0.0,
      );
  double get tax => subtotal * taxRate;
  double get total => subtotal + tax;

  static CartState initial() => const CartState(items: AsyncLoading());
}

final cartRepositoryProvider = Provider<CartRepository>((_) => CartRepositoryImpl());

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
  return CartController(ref.read(cartRepositoryProvider))..load();
});

class CartController extends StateNotifier<CartState> {
  CartController(this._repo) : super(CartState.initial());
  final CartRepository _repo;

  Future<void> load() async {
    try {
      final items = await _repo.loadCart();
      state = state.copyWith(items: AsyncData(items));
    } catch (e, st) {
      state = state.copyWith(items: AsyncError(e, st));
    }
  }

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

  Future<void> setQty(String productId, int qty) async {
    await _repo.setQty(productId, qty);
    await load();
  }

  Future<void> remove(String productId) async {
    await _repo.remove(productId);
    await load();
  }

  Future<void> clear() async {
    await _repo.clear();
    await load();
  }
}
