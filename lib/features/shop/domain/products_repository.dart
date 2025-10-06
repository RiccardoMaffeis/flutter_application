import 'product.dart';
import 'category.dart';
import 'product_details.dart';

abstract class ProductsRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Product>> fetchProducts({String? categoryId});
  Future<Set<String>> fetchFavourites();
  Future<void> toggleFavourite(String productId);
  Future<int> getCartCount();
  Future<ProductDetails> fetchProductDetails(String productId);
}
