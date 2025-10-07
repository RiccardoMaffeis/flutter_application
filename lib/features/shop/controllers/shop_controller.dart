import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../domain/product.dart';
import '../domain/category.dart';
import '../domain/products_repository.dart';
import '../data/products_repository_impl.dart';

class ShopState {
  final List<Category> categories;
  final String selectedCategoryId;
  final AsyncValue<List<Product>> products;
  final Set<String> favourites;
  final int cartCount;

  const ShopState({
    required this.categories,
    required this.selectedCategoryId,
    required this.products,
    required this.favourites,
    required this.cartCount,
  });

  ShopState copyWith({
    List<Category>? categories,
    String? selectedCategoryId,
    AsyncValue<List<Product>>? products,
    Set<String>? favourites,
    int? cartCount,
  }) {
    return ShopState(
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      products: products ?? this.products,
      favourites: favourites ?? this.favourites,
      cartCount: cartCount ?? this.cartCount,
    );
  }

  static ShopState initial() => const ShopState(
    categories: [],
    selectedCategoryId: 'all',
    products: AsyncValue.data(const []),
    favourites: {},
    cartCount: 0,
  );
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepositoryImpl();
});

final shopControllerProvider =
    StateNotifierProvider<ShopController, ShopState>((ref) {
  return ShopController(ref.read(productsRepositoryProvider))..bootstrap();
});

class ShopController extends StateNotifier<ShopState> {
  final ProductsRepository _repo;
  ShopController(this._repo) : super(ShopState.initial());

  Future<void> bootstrap() async {
    final cats = await _repo.fetchCategories();
    final favs = await _repo.fetchFavourites();
    final count = await _repo.getCartCount();

    state = state.copyWith(
      categories: cats,
      favourites: favs,
      cartCount: count,
    );
    await loadProducts();
  }

  Future<void> loadProducts({String? categoryId}) async {
    final cat = categoryId ?? state.selectedCategoryId;
    state = state.copyWith(
      selectedCategoryId: cat,
      products: const AsyncValue.loading(),
    );
    try {
      final items = await _repo.fetchProducts(categoryId: cat);
      state = state.copyWith(products: AsyncValue.data(items));
    } catch (e, st) {
      state = state.copyWith(products: AsyncValue.error(e, st));
    }
  }

  Future<void> toggleFavourite(String id) async {
    await _repo.toggleFavourite(id);
    final favs = await _repo.fetchFavourites();
    state = state.copyWith(favourites: favs);
  }
}
