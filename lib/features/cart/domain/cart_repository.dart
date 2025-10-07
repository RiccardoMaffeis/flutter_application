import 'cart_item.dart';

abstract class CartRepository {
  Future<List<CartItem>> loadCart();
  Future<void> setQty(String productId, int qty);
  Future<void> addOrIncrease(CartItem item, {int by});
  Future<void> remove(String productId);
  Future<void> clear();
}
