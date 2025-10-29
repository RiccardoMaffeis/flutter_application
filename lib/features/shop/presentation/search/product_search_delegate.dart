import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/product.dart';
import '../../controllers/shop_controller.dart';
import 'package:go_router/go_router.dart';

// SearchDelegate implementation for Product lookup.
// - Leverages Riverpod to fetch products and read favourites.
// - Filters locally by tokens matched against product code + name.
// - Opens product details using GoRouter when a result is tapped.
class ProductSearchDelegate extends SearchDelegate<Product?> {
  final WidgetRef ref;
  ProductSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search for code or name...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16);

  @override
  ThemeData appBarTheme(BuildContext context) {
    // Make search AppBar match the app's visual language and scale fonts/icons responsively.
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final textScale = media.textScaleFactor.clamp(1.0, 1.3);

    final double fieldFont = (w * 0.045).clamp(14.0, 18.0) * textScale;
    final double actionIconSize = (w * 0.08).clamp(22.0, 28.0);

    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(fontSize: fieldFont, color: Colors.black54),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          fontSize: fieldFont,
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(size: actionIconSize, color: Colors.black87),
        actionsIconTheme: IconThemeData(
          size: actionIconSize,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Closes the delegate and navigates to the product detail route.
  void _openProduct(BuildContext ctx, Product p) {
    close(ctx, p);
    Future.microtask(() => ctx.push('/product/${p.id}'));
  }

  @override
  Widget buildResults(BuildContext context) {
    // Reuses the same widget for both suggestions and results.
    return _ResultsList(
      ref: ref,
      query: query,
      onSelect: (ctx, product) => _openProduct(ctx, product),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // As-you-type suggestions share the same filtering logic as results.
    return _ResultsList(
      ref: ref,
      query: query,
      onSelect: (ctx, product) => _openProduct(ctx, product),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
        tooltip: 'Clear',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.black),
    onPressed: () => close(context, null),
    tooltip: 'Back',
  );
}

// Results list that fetches products once, filters client-side, and renders tiles.
// Uses ConsumerWidget to read favourites and the controller for toggling.
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
    // Direct repository read to fetch the full catalog (categoryId: null ⇒ all).
    final repo = ref.read(productsRepositoryProvider);

    return FutureBuilder<List<Product>>(
      future: () async {
        final items = await repo.fetchProducts(categoryId: null);

        // Normalize query and short-circuit empty searches.
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return List<Product>.from(items);

        // Tokenize query on alphanumerics; keep only meaningful tokens.
        final tokens = RegExp(
          r'[a-z0-9]+',
        ).allMatches(q).map((m) => m.group(0)!).toList();
        if (tokens.isEmpty) return List<Product>.from(items);

        // Predicate: a product matches if all tokens appear either in the raw haystack
        // (name + code) or in a sanitized version (removed non-alphanumerics).
        bool matches(Product p) {
          final hay = ('${p.displayName} ${p.code}').toLowerCase();
          final hayClean = hay.replaceAll(RegExp(r'[^a-z0-9]'), '');
          return tokens.every((t) {
            final tClean = t.replaceAll(RegExp(r'[^a-z0-9]'), '');
            return hay.contains(t) || hayClean.contains(tClean);
          });
        }

        return items.where(matches).toList();
      }(),
      builder: (context, snap) {
        // Responsive metrics for list items.
        final media = MediaQuery.of(context);
        final w = media.size.width;
        final textScale = media.textScaleFactor.clamp(1.0, 1.3);

        final double imgW = (w * 0.14).clamp(48.0, 64.0);
        final double titleFont = (w * 0.045).clamp(14.0, 18.0) * textScale;
        final double subtitleFont = (w * 0.038).clamp(12.0, 14.0) * textScale;
        final double emptyFont = (w * 0.045).clamp(14.0, 18.0) * textScale;
        final double favIcon = (w * 0.075).clamp(22.0, 28.0);
        final double tileHPad = (w * 0.04).clamp(10.0, 16.0);
        final double tileVPad = (w * 0.02).clamp(6.0, 10.0);
        final double dividerIndent = (w * 0.18).clamp(64.0, 96.0);

        if (!snap.hasData) {
          // Initial/awaiting state: show a spinner.
          return const Center(child: CircularProgressIndicator());
        }

        final results = snap.data!;
        if (results.isEmpty) {
          // Empty state for no matches.
          return Center(
            child: Text(
              'No results',
              style: TextStyle(
                fontSize: emptyFont,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        // Read favourites from the ShopState (kept in sync elsewhere).
        final favs = ref.watch(shopControllerProvider).favourites;
        final shopCtrl = ref.read(shopControllerProvider.notifier);

        // Render results with favourite toggle and product navigation.
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, indent: dividerIndent),
          itemBuilder: (_, i) {
            final p = results[i];
            final isFav = favs.contains(p.id);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tileHPad,
                vertical: tileVPad,
              ),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: imgW,
                  child: Image.asset(
                    p.imageUrl,
                    fit: BoxFit.contain,
                    // Gracefully handle missing assets.
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
                title: Text(
                  p.code,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: titleFont,
                  ),
                ),
                subtitle: Text(
                  p.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: subtitleFont, height: 1.25),
                ),
                trailing: IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? AppTheme.accent : Colors.black,
                    size: favIcon,
                  ),
                  onPressed: () => shopCtrl.toggleFavourite(p.id),
                  tooltip: isFav
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                ),
                onTap: () => onSelect(context, p),
              ),
            );
          },
        );
      },
    );
  }
}
