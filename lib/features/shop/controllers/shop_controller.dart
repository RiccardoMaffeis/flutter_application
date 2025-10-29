import 'package:flutter_application/features/auth/controllers/auth_controller.dart';
import 'package:flutter_application/features/auth/domain/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../domain/product_details.dart';
import '../domain/product.dart';
import '../domain/category.dart';
import '../domain/products_repository.dart';
import '../data/products_repository_impl.dart';

import '../../cart/data/cart_providers.dart';
import '../../favourites/data/favorites_providers.dart';

class ShopState {
  // All available categories (including a synthetic "all").
  final List<Category> categories;
  // Currently selected category id (e.g., 'all' or a real category id).
  final String selectedCategoryId;
  // Current products list for the selected category (loading/error/data).
  final AsyncValue<List<Product>> products;
  // Set of favourite product IDs for the signed-in user.
  final Set<String> favourites;
  // Current cart item count for the signed-in user.
  final int cartCount;

  const ShopState({
    required this.categories,
    required this.selectedCategoryId,
    required this.products,
    required this.favourites,
    required this.cartCount,
  });

  // Immutable update helper for partial state changes.
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

  // Initial UI-friendly state: no categories, 'all' selected, empty products,
  // no favourites, empty cart.
  static ShopState initial() => const ShopState(
    categories: [],
    selectedCategoryId: 'all',
    products: AsyncValue.data(const []),
    favourites: {},
    cartCount: 0,
  );
}

// DI: concrete repository provider for products.
final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepositoryImpl();
});

// Fetches full product details for a given product id on demand.
final productDetailsProvider = FutureProvider.family<ProductDetails, String>((
  ref,
  productId,
) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.fetchProductDetails(productId);
});

// Main controller provider managing ShopState.
// bootstrap() runs once on creation to load categories and products and set up listeners.
final shopControllerProvider = StateNotifierProvider<ShopController, ShopState>(
  (ref) =>
      ShopController(ref, ref.read(productsRepositoryProvider))..bootstrap(),
);

// Convenience provider exposing only the current cart count integer.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(shopControllerProvider).cartCount;
});

class ShopController extends StateNotifier<ShopState> {
  final Ref ref;
  final ProductsRepository _repo;

  // Subscriptions to reactive sources we want to mirror inside ShopState.
  ProviderSubscription<AsyncValue<Set<String>>>? _favSub;
  ProviderSubscription<AsyncValue<int>>? _cartSub;

  ShopController(this.ref, this._repo) : super(ShopState.initial());

  // Initializes categories, wires listeners to auth/favourites/cart, and loads products.
  Future<void> bootstrap() async {
    // 1) Load categories upfront.
    final cats = await _repo.fetchCategories();
    state = state.copyWith(categories: cats);

    // 2) React to auth state to attach/detach favourites/cart streams per user.
    ref.listen<AsyncValue<AppUser?>>(authControllerProvider, (prev, next) {
      final uid = next.value?.uid;

      // Clean up previous subscriptions when user changes.
      _favSub?.close();
      _cartSub?.close();

      if (uid == null) {
        // No user: clear user-specific slices.
        state = state.copyWith(favourites: {}, cartCount: 0);
        return;
      }

      // Subscribe to favourites stream for this user and mirror into state.
      _favSub = ref.listen<AsyncValue<Set<String>>>(
        favouritesStreamProvider(uid),
        (_, favs) =>
            state = state.copyWith(favourites: favs.value ?? <String>{}),
        fireImmediately: true, // Push current value immediately if available.
      );

      // Subscribe to cart count for this user and mirror into state.
      _cartSub = ref.listen<AsyncValue<int>>(
        cartCountStreamProvider(uid),
        (_, c) => state = state.copyWith(cartCount: c.value ?? 0),
        fireImmediately: true,
      );
    }, fireImmediately: true);

    // 3) Load initial products for the default category.
    await loadProducts();
  }

  // Loads products for a given (or current) category with loading/error handling.
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

  // Toggles favourite for the current user (no-op if signed out).
  Future<void> toggleFavourite(String productId) async {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) return;
    await ref.read(favoritesRepoProvider).toggle(uid, productId);
  }

  @override
  void dispose() {
    // Ensure provider subscriptions are closed to avoid leaks.
    _favSub?.close();
    _cartSub?.close();
    super.dispose();
  }
}
