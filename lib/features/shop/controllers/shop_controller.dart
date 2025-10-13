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

final productDetailsProvider = FutureProvider.family<ProductDetails, String>((
  ref,
  productId,
) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.fetchProductDetails(productId);
});

final shopControllerProvider = StateNotifierProvider<ShopController, ShopState>(
  (ref) =>
      ShopController(ref, ref.read(productsRepositoryProvider))..bootstrap(),
);

final cartCountProvider = Provider<int>((ref) {
    return ref.watch(shopControllerProvider).cartCount;
  });

class ShopController extends StateNotifier<ShopState> {
  final Ref ref;
  final ProductsRepository _repo;

  ProviderSubscription<AsyncValue<Set<String>>>? _favSub;
  ProviderSubscription<AsyncValue<int>>? _cartSub;

  ShopController(this.ref, this._repo) : super(ShopState.initial());

  Future<void> bootstrap() async {
    final cats = await _repo.fetchCategories();
    state = state.copyWith(categories: cats);

    // Reagisci ai cambi di login e collega gli stream per-utente
    ref.listen<AsyncValue<AppUser?>>(authControllerProvider, (prev, next) {
      final uid = next.value?.uid; // <-- se il campo è 'uid', cambia qui
      // chiudi eventuali listener precedenti
      _favSub?.close();
      _cartSub?.close();

      if (uid == null) {
        state = state.copyWith(favourites: {}, cartCount: 0);
        return;
      }

      _favSub = ref.listen<AsyncValue<Set<String>>>(
        favouritesStreamProvider(uid),
        (_, favs) =>
            state = state.copyWith(favourites: favs.value ?? <String>{}),
        fireImmediately: true,
      );

      _cartSub = ref.listen<AsyncValue<int>>(
        cartCountStreamProvider(uid),
        (_, c) => state = state.copyWith(cartCount: c.value ?? 0),
        fireImmediately: true,
      );
    }, fireImmediately: true);

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

  Future<void> toggleFavourite(String productId) async {
    final uid = ref.read(authControllerProvider).value?.uid; // <- o .uid
    if (uid == null) return; // eventualmente mostra login
    await ref.read(favoritesRepoProvider).toggle(uid, productId);
    // lo stream aggiorna state.favourites
  }

  @override
  void dispose() {
    _favSub?.close();
    _cartSub?.close();
    super.dispose();
  }
}
