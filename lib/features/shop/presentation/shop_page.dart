import 'package:flutter/material.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/domain/product.dart';
import 'package:flutter_application/features/shop/presentation/search/product_search_delegate.dart';
import 'package:flutter_application/features/shop/presentation/widgets/cart_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/shop_controller.dart';
import 'widgets/product_card.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String _familyLabel(Product p) {
    final id = p.categoryId.toUpperCase();
    if (id.startsWith('XT')) return id.toUpperCase();

    final m = RegExp(
      r'\bXT(\d+)\b',
      caseSensitive: false,
    ).firstMatch(p.displayName.toUpperCase());
    return m != null ? 'XT${m.group(1)!}' : 'Other';
  }

  Map<String, List<Product>> _groupByFamily(List<Product> items) {
    final map = <String, List<Product>>{};
    for (final p in items) {
      final key = _familyLabel(p);
      map.putIfAbsent(key, () => []).add(p);
    }

    int familyRank(String k) {
      final m = RegExp(r'^XT(\d+)$').firstMatch(k);
      return m != null ? int.parse(m.group(1)!) : 999;
    }

    final keys = map.keys.toList()
      ..sort((a, b) => familyRank(a).compareTo(familyRank(b)));
    return {for (final k in keys) k: map[k]!};
  }

  Map<String, List<Product>> _groupXtByVariantAndPoles(
    List<Product> items,
    String family, // "XT1"..."XT7"
  ) {
    final fam = family.toUpperCase();
    final map = <String, List<Product>>{};

    final variantRe = RegExp('${RegExp.escape(fam)}\\s*([A-Z])');

    for (final p in items) {
      final src = ('${p.displayName} ${p.code}').toUpperCase();

      final norm = src.replaceAll(RegExp(r'[^A-Z0-9]'), '');

      final vm = variantRe.firstMatch(src);
      final variant = vm != null ? '$fam${vm.group(1)!}' : fam;

      final poles = norm.contains('4P')
          ? '4p'
          : (norm.contains('3P') ? '3p' : '3p');

      final key = '$variant $poles';
      (map[key] ??= <Product>[]).add(p);
    }

    const order = ['N', 'B', 'H', 'S', 'F', 'D'];

    int variantRank(String key) {
      final m = RegExp('^${RegExp.escape(fam)}([A-Z])').firstMatch(key);
      final v = m?.group(1) ?? 'Z';
      final idx = order.indexOf(v);
      return idx == -1 ? 999 : idx;
    }

    int polesRank(String key) => key.endsWith(' 3p') ? 0 : 1;

    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final byV = variantRank(a).compareTo(variantRank(b));
        if (byV != 0) return byV;
        final byP = polesRank(a).compareTo(polesRank(b));
        if (byP != 0) return byP;
        return a.compareTo(b);
      });

    return {for (final k in sortedKeys) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopControllerProvider);
    final ctrl = ref.read(shopControllerProvider.notifier);

    const categoryLabels = [
      'All',
      'XT1',
      'XT2',
      'XT3',
      'XT4',
      'XT5',
      'XT6',
      'XT7',
    ];

    final selectedIdx = state.categories.indexWhere(
      (c) => c.id == state.selectedCategoryId,
    );

    final sectionTitle =
        (selectedIdx >= 0 && selectedIdx < categoryLabels.length)
        ? categoryLabels[selectedIdx]
        : categoryLabels.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),

      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: ProductSearchDelegate(ref),
                          );
                        },
                        icon: const Icon(Icons.search, size: 35),
                      ),

                      Expanded(
                        child: Center(
                          child: Text(
                            'Shop',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 40,
                                ),
                          ),
                        ),
                      ),
                      CartIconButton(
                        onPressed: () => showCartPopup(context, ref),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: 3,
                        spreadRadius: 0.4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: state.categories.length.clamp(
                      0,
                      categoryLabels.length,
                    ),
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final c = state.categories[i];
                      final selected = c.id == state.selectedCategoryId;
                      final label = categoryLabels[i];

                      return ChoiceChip(
                        label: Text(label),
                        avatar: selected
                            ? Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: AppTheme.accent,
                                ),
                              )
                            : null,
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.accent,
                        selected: selected,
                        onSelected: (_) => ctrl.loadProducts(categoryId: c.id),
                        shape: const StadiumBorder(side: BorderSide.none),
                        elevation: 3,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? const Color(0xFFFFFFFF)
                              : Colors.black87,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 4),

                Expanded(
                  child: state.products.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load: $e')),
                    data: (items) {
                      final titleUp = sectionTitle.toUpperCase();
                      final isAll = titleUp == 'ALL';
                      final isXtFamily = RegExp(r'^XT[1-7]$').hasMatch(titleUp);

                      if (isAll) {
                        final families = _groupByFamily(items);

                        return CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            for (final entry in families.entries) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    6,
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 320,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (_, i) {
                                      final p = entry.value[i];
                                      final fav = state.favourites.contains(
                                        p.id,
                                      );
                                      return SizedBox(
                                        width: 220,
                                        child: ProductCard(
                                          product: p,
                                          isFavourite: fav,
                                          onFavToggle: () =>
                                              ctrl.toggleFavourite(p.id),
                                          onTap: () =>
                                              context.go('/product/${p.id}'),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemCount: entry.value.length,
                                  ),
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 76),
                            ),
                          ],
                        );
                      }

                      if (isXtFamily) {
                        final groups = _groupXtByVariantAndPoles(
                          items,
                          titleUp,
                        );

                        return CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            for (final entry in groups.entries) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    6,
                                  ),
                                  child: Text(
                                    entry.key, // es: "XT2A 3p", "XT1 4p"
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 320,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (_, i) {
                                      final p = entry.value[i];
                                      final fav = state.favourites.contains(
                                        p.id,
                                      );
                                      return SizedBox(
                                        width: 220,
                                        child: ProductCard(
                                          product: p,
                                          isFavourite: fav,
                                          onFavToggle: () =>
                                              ctrl.toggleFavourite(p.id),
                                          onTap: () =>
                                              context.go('/product/${p.id}'),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemCount: entry.value.length,
                                  ),
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 76),
                            ),
                          ],
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.52,
                              ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i];
                            final fav = state.favourites.contains(p.id);
                            return ProductCard(
                              product: p,
                              isFavourite: fav,
                              onFavToggle: () => ctrl.toggleFavourite(p.id),
                              onTap: () => context.go('/product/${p.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 76),
              ],
            ),

            // bubble AI in basso a destra
            Positioned(
              right: 16,
              bottom: 90,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {}, // TODO: AI assistant
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.psychology_alt_outlined, size: 35),
                  ),
                ),
              ),
            ),

            // bottom nav stile “pillola”
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _BottomPillNav(
                index: 0,
                onChanged: (i) {
                  if (i == 0) return;
                  if (i == 1) context.go('/favourites');
                  if (i == 2) context.go('/profile');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPillNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomPillNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            spreadRadius: 2,
            offset: Offset(0, 10),
          ),

          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.fromBorderSide(BorderSide(color: Color(0x11000000))),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          const pad = 6.0;
          final slotW = (cons.maxWidth - pad * 2) / 3;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: pad + index * slotW,
                top: pad,
                bottom: pad,
                width: slotW,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(pad),
                child: Row(
                  children: [
                    _NavIcon(
                      icon: Icons.shopping_bag_outlined,
                      selected: index == 0,
                      onTap: () => onChanged(0),
                    ),
                    _NavIcon(
                      icon: Icons.favorite_border,
                      selected: index == 1,
                      onTap: () => onChanged(1),
                    ),
                    _NavIcon(
                      icon: Icons.person_outline,
                      selected: index == 2,
                      onTap: () => onChanged(2),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Icon(
            icon,
            size: 34,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
