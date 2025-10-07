import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../../shop/domain/products_repository.dart';
import '../../shop/controllers/shop_controller.dart';

final favouritesControllerProvider =
    StateNotifierProvider.autoDispose<
      FavouritesController,
      AsyncValue<List<Product>>
    >((ref) {
      final repo = ref.watch(productsRepositoryProvider);
      return FavouritesController(ref, repo);
    });

class FavouritesController extends StateNotifier<AsyncValue<List<Product>>> {
  FavouritesController(this._ref, this._repo) : super(const AsyncLoading()) {
    _recompute();

    _favSub = _ref.listen<Set<String>>(
      shopControllerProvider.select((s) => s.favourites),
      (_, __) => _recompute(),
    );
  }

  final Ref _ref;
  final ProductsRepository _repo;
  late final ProviderSubscription<Set<String>> _favSub;

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

  Future<void> refresh() async {
    try {
      final favIds = await _repo.fetchFavourites(); // Set<String>
      final all = await _repo.fetchProducts(); // tutti i prodotti
      final favs = all.where((p) => favIds.contains(p.id)).toList();
      state = AsyncData(favs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> toggle(Product p) async {
    await _ref.read(shopControllerProvider.notifier).toggleFavourite(p.id);
    await refresh();
  }

  @override
  void dispose() {
    _favSub.close();
    super.dispose();
  }
}
