import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../../shop/domain/products_repository.dart';
import '../../shop/controllers/shop_controller.dart';

/// Provider exposing the favourites list as an AsyncValue<List<Product>>.
/// Uses `autoDispose` so the controller and its resources are cleaned up
/// when no longer listened to (e.g., when the page is popped).
final favouritesControllerProvider =
    StateNotifierProvider.autoDispose<
      FavouritesController,
      AsyncValue<List<Product>>
    >((ref) {
      // Resolve the products repository from DI
      final repo = ref.watch(productsRepositoryProvider);
      return FavouritesController(ref, repo);
    });

/// StateNotifier that computes and keeps the list of favourite products.
/// It:
/// - recomputes when the underlying favourites set in ShopController changes
/// - can force a refresh from the repository (e.g., after toggling)
class FavouritesController extends StateNotifier<AsyncValue<List<Product>>> {
  FavouritesController(this._ref, this._repo) : super(const AsyncLoading()) {
    // Initial computation (reads current favourites and filters products)
    _recompute();

    // Subscribe to changes of the favourites Set<String> from ShopController.
    // Whenever favourites change, recompute the derived list of Product.
    _favSub = _ref.listen<Set<String>>(
      shopControllerProvider.select((s) => s.favourites),
      // ignore old/new sets, we just trigger a recompute
      (_, __) => _recompute(),
    );
  }

  final Ref _ref; // Riverpod ref for reading other providers
  final ProductsRepository _repo; // Source of truth for products/favourites
  late final ProviderSubscription<Set<String>> _favSub; // Subscription handle

  /// Computes the current favourites list by:
  /// 1) fetching all products,
  /// 2) reading the favourite IDs from ShopController,
  /// 3) filtering products by those IDs,
  /// 4) publishing AsyncData or AsyncError.
  Future<void> _recompute() async {
    try {
      final all = await _repo.fetchProducts();
      final favIds = _ref.read(shopControllerProvider).favourites;
      final favs = all.where((p) => favIds.contains(p.id)).toList();
      state = AsyncData(favs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Forces a refresh against the repository (useful after toggles or pull-to-refresh):
  /// - fetches favourite IDs from the repo
  /// - fetches all products
  /// - filters to favourites and publishes the result
  Future<void> refresh() async {
    try {
      final favIds = await _repo.fetchFavourites();
      final all = await _repo.fetchProducts();
      final favs = all.where((p) => favIds.contains(p.id)).toList();
      state = AsyncData(favs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggles a product's favourite status via ShopController, then refreshes.
  /// Note: we rely on ShopController to persist/propagate the actual toggle.
  Future<void> toggle(Product p) async {
    await _ref.read(shopControllerProvider.notifier).toggleFavourite(p.id);
    await refresh();
  }

  /// Clean up the subscription to avoid leaks.
  @override
  void dispose() {
    _favSub.close();
    super.dispose();
  }
}
