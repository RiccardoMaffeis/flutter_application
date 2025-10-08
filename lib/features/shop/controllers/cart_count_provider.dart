import 'package:flutter_application/features/cart/controllers/cart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartControllerProvider);
  return cart.items.when(
    data: (items) => items.fold<int>(0, (s, e) => s + e.qty),
    loading: () => 0,
    error: (_, __) => 0,
  );
});
