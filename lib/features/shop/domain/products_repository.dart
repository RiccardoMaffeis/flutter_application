// Abstraction for the products data source used by the Shop feature.
// Implementations can load from local assets, REST APIs, Firestore, etc.
// Responsibilities include:
// - Listing categories and products (optionally filtered by category)
// - Managing user favourites (read + toggle)
// - Providing current cart count (e.g., to decorate UI badges)
// - Fetching detailed specs for a specific product

import 'product.dart';
import 'category.dart';
import 'product_details.dart';

abstract class ProductsRepository {
  /// Returns the list of available product categories.
  /// Order may be used directly by the UI (e.g., include 'all' first).
  Future<List<Category>> fetchCategories();

  /// Returns the list of products.
  /// When [categoryId] is provided, the results should be filtered by it;
  /// otherwise, all products are returned.
  Future<List<Product>> fetchProducts({String? categoryId});

  /// Returns the set of favourite product IDs for the current user/session.
  /// Implementations may be in-memory, local, or remote-backed.
  Future<Set<String>> fetchFavourites();

  /// Toggles the favourite status for the given [productId].
  /// If already favourited → remove; otherwise → add.
  Future<void> toggleFavourite(String productId);

  /// Returns the current cart item count for the user/session.
  /// Useful for showing a badge in the UI.
  Future<int> getCartCount();

  /// Returns detailed information for a single product, including specs.
  /// Throws if the product cannot be found.
  Future<ProductDetails> fetchProductDetails(String productId);
}
