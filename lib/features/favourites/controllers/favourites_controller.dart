import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../shop/domain/product.dart';
import '../../shop/domain/products_repository.dart';
import '../../shop/controllers/shop_controller.dart';

/// Espone i preferiti come AsyncValue<List<Product>>, ricalcolando
/// quando cambiano (1) l'insieme degli ID preferiti o (2) la lista prodotti.
final favouritesControllerProvider = StateNotifierProvider.autoDispose<
    FavouritesController,
    AsyncValue<List<Product>>>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  return FavouritesController(ref, repo);
});

class FavouritesController extends StateNotifier<AsyncValue<List<Product>>> {
  FavouritesController(this._ref, this._repo) : super(const AsyncLoading()) {
    // Prima computazione
    _recompute();

    // Riascolta quando cambia l'insieme di preferiti
    _favSub = _ref.listen<Set<String>>(
      shopControllerProvider.select((s) => s.favourites),
      (_, __) => _recompute(),
    );

    // Riascolta quando cambia la lista prodotti (loading/data/error)
    _prodSub = _ref.listen<AsyncValue<List<Product>>>(
      shopControllerProvider.select((s) => s.products),
      (_, __) => _recompute(),
    );
  }

  final Ref _ref;
  final ProductsRepository _repo;
  late final ProviderSubscription<Set<String>> _favSub;
  late final ProviderSubscription<AsyncValue<List<Product>>> _prodSub;

  /// Ricalcola la lista preferiti:
  /// - prova a usare i prodotti già presenti nello ShopController;
  /// - se non disponibili, fa fallback su fetchProducts() del repository.
  Future<void> _recompute() async {
    try {
      // 1) ID preferiti aggiornati (già per-utente via Firestore)
      final favIds = _ref.read(shopControllerProvider).favourites;

      // 2) Prova a usare quelli già caricati nello ShopController
      final productsAV = _ref.read(shopControllerProvider).products;
      final cached = productsAV.maybeWhen<List<Product>?>(
        data: (list) => list,
        orElse: () => null,
      );

      final all = cached ?? await _repo.fetchProducts();

      // 3) Filtra
      final favs = all.where((p) => favIds.contains(p.id)).toList();
      state = AsyncData(favs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Forza un ricalcolo (utile su pull-to-refresh). Non interroga più
  /// il repository dei preferiti: la fonte è lo stream del ShopController.
  Future<void> refresh() => _recompute();

  /// Toggle preferito: delega allo ShopController (che persiste su Firestore).
  /// Lo stream aggiornerà i preferiti e scatenerà _recompute().
  Future<void> toggle(Product p) async {
    await _ref.read(shopControllerProvider.notifier).toggleFavourite(p.id);
    // opzionale: feedback immediato
    await _recompute();
  }

  @override
  void dispose() {
    _favSub.close();
    _prodSub.close();
    super.dispose();
  }
}
