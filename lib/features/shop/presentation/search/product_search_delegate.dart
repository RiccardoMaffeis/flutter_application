import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/product.dart';
import '../../controllers/shop_controller.dart';
import 'package:go_router/go_router.dart';

class ProductSearchDelegate extends SearchDelegate<Product?> {
  final WidgetRef ref;
  ProductSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search for code or name...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16);

  void _openProduct(BuildContext ctx, Product p) {
    close(ctx, p);
    Future.microtask(() => ctx.push('/product/${p.id}'));
  }

  @override
  Widget buildResults(BuildContext context) {
    return _ResultsList(
      ref: ref,
      query: query,
      onSelect: (ctx, product) => _openProduct(ctx, product),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _ResultsList(
      ref: ref,
      query: query,
      onSelect: (ctx, product) => _openProduct(ctx, product),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.black),
    onPressed: () => close(context, null),
  );
}

class _ResultsList extends ConsumerWidget {
  final WidgetRef ref;
  final String query;
  final void Function(BuildContext, Product) onSelect;

  const _ResultsList({
    required this.ref,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(productsRepositoryProvider);
    final selectedCat = ref.read(shopControllerProvider).selectedCategoryId;

    return FutureBuilder<List<Product>>(
      future: () async {
        final items = await repo.fetchProducts(
          categoryId: selectedCat == 'all' ? null : selectedCat,
        );
        final q = query.trim().toLowerCase();
        if (q.isEmpty) {
          // tutti i prodotti (della categoria selezionata, se filtrata sopra)
          return List<Product>.from(
            items,
          ); // oppure semplicemente: return items;
        }

        return items.where((p) {
          final name = p.displayName.toLowerCase();
          final code = p.code.toLowerCase();
          return name.contains(q) || code.contains(q);
        }).toList();
      }(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final results = snap.data!;
        if (results.isEmpty)
          return const Center(child: Text('Nessun risultato'));

        final favs = ref.watch(shopControllerProvider).favourites;
        final shopCtrl = ref.read(shopControllerProvider.notifier);

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = results[i];
            final isFav = favs.contains(p.id);
            return ListTile(
              leading: SizedBox(
                width: 56,
                child: Image.asset(
                  p.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
              title: Text(
                p.code,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                p.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav
                      ? AppTheme.accent
                      : Colors.black,
                ),
                onPressed: () => shopCtrl.toggleFavourite(p.id),
              ),

              onTap: () => onSelect(context, p),
            );
          },
        );
      },
    );
  }
}
