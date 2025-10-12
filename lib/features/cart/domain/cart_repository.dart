import 'cart_item.dart';

/// Abstraction for a shopping cart data source.
/// Implementations can persist to Firestore/REST/local storage, etc.
/// All operations are asynchronous and should be resilient to offline states.
abstract class CartRepository {
  /// Loads the current cart items.
  /// Should return an empty list if the cart is empty or unavailable.
  Future<List<CartItem>> loadCart();

  /// Sets the absolute quantity for the item identified by [productId].
  /// Implementations may treat `qty <= 0` as a request to remove the item.
  Future<void> setQty(String productId, int qty);

  /// Adds a new item or increases the quantity of an existing one.
  /// The [by] parameter indicates how much to increment by (must be > 0).
  Future<void> addOrIncrease(CartItem item, {int by});

  /// Removes the item identified by [productId] from the cart.
  Future<void> remove(String productId);

  /// Clears all items from the cart.
  Future<void> clear();
}
