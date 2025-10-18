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
  // --- Anti double-tap / throttle ---
  bool _navBusy = false; // blocca navigazioni ripetute
  DateTime? _cooldownUntil; // breve cooldown UI generico
  final Set<String> _favBusy = <String>{}; // toggle preferiti in corso

  bool get _cooldownActive =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  void _startCooldown([int ms = 700]) {
    _cooldownUntil = DateTime.now().add(Duration(milliseconds: ms));
  }

  Future<void> _onFavToggle(String productId) async {
    if (_favBusy.contains(productId)) return; // già in corso
    _favBusy.add(productId);
    setState(() {});
    try {
      await Future<void>.value(
        ref.read(shopControllerProvider.notifier).toggleFavourite(productId),
      );
    } finally {
      _favBusy.remove(productId);
      if (mounted) setState(() {});
    }
  }

  void _safeGo(BuildContext context, String route, {int cooldownMs = 500}) {
    if (_navBusy) return;
    _navBusy = true;
    _startCooldown(cooldownMs);
    setState(() {});
    context.go(route);
    Future.delayed(Duration(milliseconds: cooldownMs), () {
      if (!mounted) return;
      _navBusy = false;
      setState(() {});
    });
  }

  void _safePush(BuildContext context, String route, {int cooldownMs = 500}) {
    if (_navBusy) return;
    _navBusy = true;
    _startCooldown(cooldownMs);
    setState(() {});
    context.push(route);
    Future.delayed(Duration(milliseconds: cooldownMs), () {
      if (!mounted) return;
      _navBusy = false;
      setState(() {});
    });
  }

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
    String family,
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
    final isProductsLoading = state.products.isLoading;
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
        child: LayoutBuilder(
          builder: (context, cons) {
            final w = cons.maxWidth;
            final h = cons.maxHeight;

            // ---- Responsive metrics ----
            final double searchIconSize = (w * 0.085).clamp(26.0, 35.0);
            final double titleFont = (w * 0.09).clamp(24.0, 40.0);
            final double errorFont = (w * 0.045).clamp(14.0, 18.0);
            final double barH = (w * 0.01).clamp(3.0, 4.0);
            final double chipRowH = (h * 0.075).clamp(48.0, 64.0);
            final double chipFont = (w * 0.04).clamp(12.0, 16.0);

            final double familyTitleFont = (w * 0.07).clamp(22.0, 30.0);
            final double variantTitleFont = (w * 0.055).clamp(18.0, 22.0);

            final double carouselCardW = (w * 0.5).clamp(180.0, 240.0);
            final double carouselH = (h * 0.36).clamp(280.0, 340.0);

            final double listHPad = (w * 0.03).clamp(10.0, 16.0);
            final double listSep = (w * 0.03).clamp(10.0, 16.0);

            // Grid columns by width breakpoints
            int gridCols;
            if (w >= 920) {
              gridCols = 4;
            } else if (w >= 700) {
              gridCols = 3;
            } else {
              gridCols = 2;
            }
            final double gridMainSpace = (w * 0.035).clamp(10.0, 16.0);
            final double gridCrossSpace = (w * 0.035).clamp(10.0, 16.0);
            final double gridAspect = 0.52; // keep card aspect

            final double fabSize = (w * 0.12).clamp(40.0, 52.0);
            final double bottomPad = (h * 0.11).clamp(68.0, 92.0);

            return Stack(
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
                              if (_cooldownActive) return;
                              _startCooldown(500);
                              showSearch(
                                context: context,
                                delegate: ProductSearchDelegate(ref),
                              );
                            },
                            icon: Icon(Icons.search, size: searchIconSize),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Shop',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: titleFont,
                                    ),
                              ),
                            ),
                          ),
                          CartIconButton(
                            onPressed: () {
                              if (_cooldownActive) return;
                              _startCooldown(500);
                              showCartPopup(context, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: barH,
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
                      height: chipRowH,
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
                            label: Text(
                              label,
                              style: TextStyle(fontSize: chipFont),
                            ),
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
                            onSelected: (_) {
                              if (selected) return;
                              if (isProductsLoading) return;
                              if (_cooldownActive) return;
                              _startCooldown(600);
                              ctrl.loadProducts(categoryId: c.id);
                            },
                            shape: const StadiumBorder(side: BorderSide.none),
                            elevation: 3,
                            showCheckmark: false,
                            // Ensure the chip doesn't override our Text font size
                            labelStyle: TextStyle(
                              fontSize: chipFont,
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
                        error: (e, _) => Center(
                          child: Text(
                            'Failed to load: $e',
                            style: TextStyle(fontSize: errorFont),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        data: (items) {
                          final titleUp = sectionTitle.toUpperCase();
                          final isAll = titleUp == 'ALL';
                          final isXtFamily = RegExp(
                            r'^XT[1-7]$',
                          ).hasMatch(titleUp);

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
                                        style: TextStyle(
                                          fontSize: familyTitleFont,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: carouselH,
                                      child: ListView.separated(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: listHPad,
                                        ),
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemBuilder: (_, i) {
                                          final p = entry.value[i];
                                          final fav = state.favourites.contains(
                                            p.id,
                                          );
                                          return SizedBox(
                                            width: carouselCardW,
                                            child: ProductCard(
                                              product: p,
                                              isFavourite: fav,
                                              onFavToggle: () =>
                                                  _onFavToggle(p.id),
                                              onTap: () => _safeGo(
                                                context,
                                                '/product/${p.id}',
                                              ),
                                            ),
                                          );
                                        },
                                        separatorBuilder: (_, __) =>
                                            SizedBox(width: listSep),
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
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: variantTitleFont,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: carouselH,
                                      child: ListView.separated(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: listHPad,
                                        ),
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemBuilder: (_, i) {
                                          final p = entry.value[i];
                                          final fav = state.favourites.contains(
                                            p.id,
                                          );
                                          return SizedBox(
                                            width: carouselCardW,
                                            child: ProductCard(
                                              product: p,
                                              isFavourite: fav,
                                              onFavToggle: () =>
                                                  ctrl.toggleFavourite(p.id),
                                              onTap: () => context.go(
                                                '/product/${p.id}',
                                              ),
                                            ),
                                          );
                                        },
                                        separatorBuilder: (_, __) =>
                                            SizedBox(width: listSep),
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
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCols,
                                    mainAxisSpacing: gridMainSpace,
                                    crossAxisSpacing: gridCrossSpace,
                                    childAspectRatio: gridAspect,
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

                    SizedBox(height: bottomPad),
                  ],
                ),

                Positioned(
                  right: 16,
                  bottom: bottomPad + 16,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _safePush(context, '/assistant'),
                      child: SizedBox(
                        width: fabSize,
                        height: fabSize,
                        child: Icon(
                          Icons.psychology_alt_outlined,
                          size: (fabSize * 0.8).clamp(28.0, 35.0),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _BottomPillNav(
                    index: 0,
                    onChanged: (i) {
                      if (_navBusy || _cooldownActive) return;
                      _startCooldown(500);
                      if (i == 0) return;
                      if (i == 1) _safeGo(context, '/favourites');
                      if (i == 3) _safeGo(context, '/profile');
                      if (i == 2) _safeGo(context, '/ar');
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Reusable bottom navigation with a sliding "pill" highlight.
/// - Accepts a `index` to indicate the selected tab
/// - Calls `onChanged` with the tapped index
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
        border: Border.fromBorderSide(
          const BorderSide(color: Color(0x11000000)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          const pad = 6.0;
          final slotW = (cons.maxWidth - pad * 2) / 4;
          return Stack(
            children: [
              // Animated pill indicating the selected tab.
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
              // Four icons (Home/Favourites/AR/Profile).
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
                      icon: Icons.view_in_ar,
                      selected: index == 2,
                      onTap: () => onChanged(2),
                    ),
                    _NavIcon(
                      icon: Icons.person_outline,
                      selected: index == 3,
                      onTap: () => onChanged(3),
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

/// Single icon button used by the pill navigation.
/// - Changes color to white when selected (due to colored pill background)
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
