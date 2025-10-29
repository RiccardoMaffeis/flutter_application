import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application/core/bottom_nav/global_ui_providers.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/domain/product.dart';
import 'package:flutter_application/features/shop/presentation/search/product_search_delegate.dart';
import 'package:flutter_application/features/shop/presentation/widgets/cart_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_application/core/tour/coach_tour.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/shop_controller.dart';
import 'widgets/product_card.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});
  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  // --- Tap throttling to avoid spamming actions ---
  DateTime? _cooldownUntil;
  final Set<String> _favBusy = <String>{};
  bool get _cooldownActive =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
  void _startCooldown([int ms = 700]) {
    _cooldownUntil = DateTime.now().add(Duration(milliseconds: ms));
  }

  // --- Showcase (guided tour) targets ---
  final _kSearch = GlobalKey();
  final _kFilters = GlobalKey();
  final _kCart = GlobalKey();
  final _kCard = GlobalKey();

  bool _tourScheduled = false;

  /// Schedules the guided tour once products are loaded and the UI is laid out.
  void _scheduleTourAfterData() {
    if (_tourScheduled) return;
    _tourScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(coachTourServiceProvider).startOrQueue(
        context,
        TourSection.shop,
        [_kSearch, _kFilters, _kCart, _kCard],
      );
    });
  }

  /// Safely toggles a favourite with per-item "busy" protection.
  Future<void> _onFavToggle(String productId) async {
    if (_favBusy.contains(productId)) return;
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

  /// Computes a family label (e.g., XT3) from product info; falls back to Other.
  String _familyLabel(Product p) {
    final id = p.categoryId.toUpperCase();
    if (id.startsWith('XT')) return id.toUpperCase();
    final m = RegExp(
      r'\bXT(\d+)\b',
      caseSensitive: false,
    ).firstMatch(p.displayName.toUpperCase());
    return m != null ? 'XT${m.group(1)!}' : 'Other';
  }

  /// Groups products by family (XT1..XT7/Other) and returns a map sorted by family rank.
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

  /// For a specific XT family, groups by variant (e.g., XT1N/XT1B/…) and poles (3p/4p).
  /// Keys are sorted by variant order, then by poles (3p before 4p).
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
      final poles = norm.contains('4P') ? '4p' : '3p';
      final key = '$variant $poles';
      (map[key] ??= <Product>[]).add(p);
    }

    // Preferred ordering for known variants
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
    // Observe shop state (products, categories, favourites, etc.)
    final state = ref.watch(shopControllerProvider);
    final isProductsLoading = state.products.isLoading;
    final ctrl = ref.read(shopControllerProvider.notifier);

    // Static display labels for chips; rely on indices aligned with categories.
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

    // Compute selected section label from current category id.
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
            // ---- Responsive metrics ----
            final w = cons.maxWidth;
            final h = cons.maxHeight;
            final shortest = math.min(w, h);
            final s = (shortest / 375.0).clamp(0.85, 1.30);
            double sp(double v) => (v * s).toDouble();

            final double searchIconSize = (w * 0.085)
                .clamp(sp(26.0), sp(35.0))
                .toDouble();
            final double titleFont = (w * 0.09)
                .clamp(sp(24.0), sp(40.0))
                .toDouble();
            final double errorFont = (w * 0.045)
                .clamp(sp(14.0), sp(18.0))
                .toDouble();
            final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0)).toDouble();
            final double chipRowH = (h * 0.09)
                .clamp(sp(48.0), sp(64.0))
                .toDouble();
            final double chipFont = (w * 0.04)
                .clamp(sp(12.0), sp(16.0))
                .toDouble();
            final double familyTitleFont = (w * 0.07)
                .clamp(sp(22.0), sp(30.0))
                .toDouble();
            final double variantTitleFont = (w * 0.055)
                .clamp(sp(18.0), sp(22.0))
                .toDouble();
            final double carouselCardW = (w * 0.5)
                .clamp(sp(180.0), sp(240.0))
                .toDouble();
            final double carouselH = (h * 0.36)
                .clamp(sp(280.0), sp(340.0))
                .toDouble();
            final double listHPad = (w * 0.03)
                .clamp(sp(10.0), sp(16.0))
                .toDouble();
            final double listSep = (w * 0.03)
                .clamp(sp(10.0), sp(16.0))
                .toDouble();
            final double gridMainSpace = (w * 0.035)
                .clamp(sp(10.0), sp(16.0))
                .toDouble();
            final double gridCrossSpace = (w * 0.035)
                .clamp(sp(10.0), sp(16.0))
                .toDouble();
            final double gridAspect = 0.52;
            final double targetCardMinW = (w * 0.42)
                .clamp(sp(160.0), sp(220.0))
                .toDouble();
            int gridCols = (w / (targetCardMinW + gridCrossSpace))
                .floor()
                .clamp(2, 6);

            final double bottomSpacer = sp(24);

            return Column(
              children: [
                // --- Header with centered title, search on the left and help+cart on the right ---
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sp(12),
                    vertical: sp(6),
                  ),
                  child: SizedBox(
                    height: math.max(searchIconSize, sp(40)) + sp(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Centered title with symmetric padding so it won't overlap icons
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: searchIconSize * 2.6,
                          ),
                          child: Text(
                            'Shop',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: titleFont,
                                ),
                          ),
                        ),

                        // Left: Search (Showcase target)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Showcase(
                            key: _kSearch,
                            description: 'Search products and manuals.',
                            overlayOpacity: 0.2,
                            targetPadding: const EdgeInsets.all(2),
                            child: IconButton(
                              onPressed: () async {
                                if (_cooldownActive) return;
                                _startCooldown(500);
                                // Hide global chrome while the search UI is shown.
                                ref.read(hideChromeProvider.notifier).state =
                                    true;
                                try {
                                  await showSearch(
                                    context: context,
                                    delegate: ProductSearchDelegate(ref),
                                  );
                                } finally {
                                  ref.read(hideChromeProvider.notifier).state =
                                      false;
                                }
                              },
                              icon: Icon(Icons.search, size: searchIconSize),
                            ),
                          ),
                        ),

                        // Right: Help to trigger tour + Cart button (Showcase target)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.help_outline,
                                  size: searchIconSize,
                                ),
                                tooltip: 'Show page tour',
                                onPressed: () =>
                                    ref.read(coachTourServiceProvider).startNow(
                                      context,
                                      [_kSearch, _kFilters, _kCart, _kCard],
                                    ),
                              ),
                              Showcase(
                                key: _kCart,
                                description:
                                    'Open the cart and proceed to checkout.',
                                overlayOpacity: 0.2,
                                targetPadding: const EdgeInsets.all(2),
                                child: CartIconButton(
                                  onPressed: () {
                                    if (_cooldownActive) return;
                                    _startCooldown(500);
                                    showCartPopup(context, ref);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ABB accent bar
                Container(
                  height: barH,
                  margin: EdgeInsets.symmetric(horizontal: sp(12)),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(sp(3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: sp(3),
                        spreadRadius: sp(0.4),
                        offset: Offset(0, sp(3)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sp(12)),

                // --- Category chips row (All, XT1..XT7) with Showcase target ---
                Showcase(
                  key: _kFilters,
                  description: 'Filter by family (XT1–XT7) or show all.',
                  overlayOpacity: 0.2,
                  targetPadding: const EdgeInsets.all(2),
                  child: SizedBox(
                    height: chipRowH,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: sp(12),
                        vertical: sp(12),
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: state.categories.length.clamp(
                        0,
                        categoryLabels.length,
                      ),
                      separatorBuilder: (_, __) => SizedBox(width: sp(6)),
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
                                  width: sp(18),
                                  height: sp(18),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.check,
                                    size: sp(14),
                                    color: AppTheme.accent,
                                  ),
                                )
                              : null,
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.accent,
                          selected: selected,
                          onSelected: (_) {
                            // Ignore redundant clicks or while loading or within cooldown.
                            if (selected ||
                                isProductsLoading ||
                                _cooldownActive)
                              return;
                            _startCooldown(600);
                            ctrl.loadProducts(categoryId: c.id);
                          },
                          shape: const StadiumBorder(side: BorderSide.none),
                          elevation: sp(3),
                          showCheckmark: false,
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
                ),

                // --- Main content: three layouts (All -> carousels by family, XTn -> carousels by variant/poles, else -> grid) ---
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
                      // Start the tour once we actually have content to highlight.
                      if (items.isNotEmpty) {
                        _scheduleTourAfterData();
                      }

                      final titleUp = sectionTitle.toUpperCase();
                      final isAll = titleUp == 'ALL';
                      final isXtFamily = RegExp(r'^XT[1-7]$').hasMatch(titleUp);

                      // We only bind the card Showcase once (first visible card).
                      bool cardTipBound = false;
                      Widget wrapCardTipIfFirst(Widget child) {
                        if (cardTipBound) return child;
                        cardTipBound = true;
                        return Showcase(
                          key: _kCard,
                          description:
                              'Tap the heart to add/remove favorites.\n'
                              'Tap the AR icon to open Augmented Reality.\n'
                              'Tap the card to view device details.',
                          overlayOpacity: 0.2,
                          targetPadding: const EdgeInsets.all(2),
                          child: child,
                        );
                      }

                      // ---- 1) ALL: show families as horizontal carousels ----
                      if (isAll) {
                        final families = _groupByFamily(items);
                        return CustomScrollView(
                          key: const PageStorageKey('shop-all'),
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            for (final entry in families.entries) ...[
                              // Family title
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    sp(12),
                                    sp(6),
                                    sp(12),
                                    sp(6),
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
                              // Family carousel of ProductCard
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
                                      Widget card = SizedBox(
                                        width: carouselCardW,
                                        child: ProductCard(
                                          product: p,
                                          isFavourite: fav,
                                          onFavToggle: () => _onFavToggle(p.id),
                                          onTap: () =>
                                              context.go('/product/${p.id}'),
                                        ),
                                      );
                                      // Attach the guided tip to the very first card only.
                                      if (!cardTipBound && i == 0) {
                                        card = wrapCardTipIfFirst(card);
                                      }
                                      return card;
                                    },
                                    separatorBuilder: (_, __) =>
                                        SizedBox(width: listSep),
                                    itemCount: entry.value.length,
                                  ),
                                ),
                              ),
                            ],
                            // Bottom padding for safe scroll end
                            SliverToBoxAdapter(
                              child: SizedBox(height: bottomSpacer),
                            ),
                          ],
                        );
                      }

                      // ---- 2) XTn: show groups by variant+poles as horizontal carousels ----
                      if (isXtFamily) {
                        final groups = _groupXtByVariantAndPoles(
                          items,
                          titleUp,
                        );
                        return CustomScrollView(
                          key: PageStorageKey('shop-$titleUp'),
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            for (final entry in groups.entries) ...[
                              // Variant+poles title (e.g., XT1N 3p)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    sp(12),
                                    sp(12),
                                    sp(12),
                                    sp(6),
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
                              // Carousel of ProductCard for this group
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
                                      Widget card = SizedBox(
                                        width: carouselCardW,
                                        child: ProductCard(
                                          product: p,
                                          isFavourite: fav,
                                          onFavToggle: () =>
                                              ctrl.toggleFavourite(p.id),
                                          onTap: () =>
                                              context.go('/product/${p.id}'),
                                        ),
                                      );
                                      if (!cardTipBound && i == 0) {
                                        // Bind the card tip to the first card of the first group only.
                                        card = wrapCardTipIfFirst(card);
                                      }
                                      return card;
                                    },
                                    separatorBuilder: (_, __) =>
                                        SizedBox(width: listSep),
                                    itemCount: entry.value.length,
                                  ),
                                ),
                              ),
                            ],
                            SliverToBoxAdapter(
                              child: SizedBox(height: bottomSpacer),
                            ),
                          ],
                        );
                      }

                      // ---- 3) Other categories: fallback grid layout ----
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          sp(12),
                          sp(8),
                          sp(12),
                          bottomSpacer,
                        ),
                        child: GridView.builder(
                          key: const PageStorageKey('shop-grid'),
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
                            Widget card = ProductCard(
                              product: p,
                              isFavourite: fav,
                              onFavToggle: () => ctrl.toggleFavourite(p.id),
                              onTap: () => context.go('/product/${p.id}'),
                            );
                            if (!cardTipBound && i == 0) {
                              card = wrapCardTipIfFirst(card);
                            }
                            return card;
                          },
                        ),
                      );
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
