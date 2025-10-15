import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../../shop/domain/products_repository.dart';
import '../../shop/controllers/shop_controller.dart';

/// Exposes the favourites list as an AsyncValue<List<Product>>.
/// IMPORTANT: This controller ignores any product filters applied in other pages
/// (e.g., Home) by always recomputing against the full catalog from the repository.
final favouritesControllerProvider = StateNotifierProvider.autoDispose<
    FavouritesController,
    AsyncValue<List<Product>>>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  return FavouritesController(ref, repo);
});

class FavouritesController extends StateNotifier<AsyncValue<List<Product>>> {
  FavouritesController(this._ref, this._repo) : super(const AsyncLoading()) {
    // Recompute whenever the favourites Set changes in ShopController.
    _favSub = _ref.listen<Set<String>>(
      shopControllerProvider.select((s) => s.favourites),
      (_, __) => _recompute(),
    );

    // Initial computation.
    _recompute();
  }

  final Ref _ref;
  final ProductsRepository _repo;
  late final ProviderSubscription<Set<String>> _favSub;

  /// Rebuilds the favourites list from the full, unfiltered product catalog.
  /// This ensures the Favourites page is independent from any filters applied elsewhere.
  Future<void> _recompute() async {
    try {
      final favIds = _ref.read(shopControllerProvider).favourites;

      // Fast path: nothing to show.
      if (favIds.isEmpty) {
        state = const AsyncData(<Product>[]);
        return;
      }

      // Always load the full catalog, or (preferably) fetch only the required IDs if supported.
      final allProducts = await _repo.fetchProducts();

      // Build the favourites list by intersecting the full catalog with the favourite IDs.
      final favs = allProducts.where((p) => favIds.contains(p.id)).toList();

      state = AsyncData(favs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Manual refresh trigger (useful after external mutations).
  Future<void> refresh() => _recompute();

  /// Convenience toggle that also recomputes the favourites list.
  Future<void> toggle(Product p) async {
    await _ref.read(shopControllerProvider.notifier).toggleFavourite(p.id);
    await _recompute();
  }

  @override
  void dispose() {
    _favSub.close();
    super.dispose();
  }
}
