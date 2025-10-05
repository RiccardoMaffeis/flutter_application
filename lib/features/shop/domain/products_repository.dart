import 'product.dart';
import 'category.dart';

abstract class ProductsRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Product>> fetchProducts({String? categoryId});
  Future<Set<String>> fetchFavourites();           // ids
  Future<void> toggleFavourite(String productId);  // optimistic ok
  Future<int> getCartCount();                      // per badge
}
