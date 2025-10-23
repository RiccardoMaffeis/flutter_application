import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/presentation/widgets/cart_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/presentation/widgets/product_card.dart';
import '../controllers/favourites_controller.dart';
import '../../shop/controllers/shop_controller.dart';

/// Page that displays the user's favourite products (100% responsive).
class FavouritesPage extends ConsumerStatefulWidget {
  const FavouritesPage({super.key});

  @override
  ConsumerState<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends ConsumerState<FavouritesPage> {

  final Set<String> _favBusy = <String>{};

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;

    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double titleFont = (w * 0.09).clamp(sp(24.0), sp(40.0)) * ts;

    final double searchIconSize = (w * 0.085)
        .clamp(sp(26.0), sp(35.0))
        .toDouble();

    final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0)).toDouble();

    final double stateFont = (w * 0.045).clamp(sp(14.0), sp(18.0)) * ts;

    // Bottom nav reserved height (matches nav container height) + bottom safe inset + padding
    final double navHeight = sp(58);
    final double bottomSpacer = navHeight + mq.padding.bottom + sp(24);

    // Grid breakpoints by width
    int columns;
    if (w >= 1000) {
      columns = 4;
    } else if (w >= 700) {
      columns = 3;
    } else {
      columns = 2;
    }
    final double aspect = columns >= 4 ? 0.70 : (columns == 3 ? 0.60 : 0.52);

    final favs = ref.watch(favouritesControllerProvider);
    final favsCtrl = ref.read(favouritesControllerProvider.notifier);

    final shopState = ref.watch(shopControllerProvider);
    final shopCtrl = ref.read(shopControllerProvider.notifier);

    // Refresh favourites list whenever favourite IDs change.
    ref.listen<Set<String>>(
      shopControllerProvider.select((s) => s.favourites),
      (_, __) => favsCtrl.refresh(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ----- Header (title centered regardless of trailing width) -----
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sp(12),
                    vertical: sp(6),
                  ),
                  child: Row(
                    children: [
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0,
                          child: IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.search, size: searchIconSize),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Favourite',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: titleFont,
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

                // Accent bar
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

                // ----- Content -----
                Expanded(
                  child: favs.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'Failed to load: $e',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: stateFont,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'No favourites yet',
                            style: TextStyle(
                              fontSize: stateFont,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sp(12),
                          vertical: sp(8),
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: bottomSpacer),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: sp(14),
                                crossAxisSpacing: sp(14),
                                childAspectRatio: aspect,
                              ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i];
                            final isFav = shopState.favourites.contains(p.id);
                            final busy = _favBusy.contains(p.id);
                            return ProductCard(
                              product: p,
                              isFavourite: isFav,
                              // opzionale: se ProductCard supporta uno stato di busy, passalo
                              // isBusy: busy,
                              onFavToggle: () async {
                                if (busy) return;
                                setState(() => _favBusy.add(p.id));
                                try {
                                  await shopCtrl.toggleFavourite(p.id);
                                  await favsCtrl.refresh();
                                } finally {
                                  if (mounted) {
                                    setState(() => _favBusy.remove(p.id));
                                  }
                                }
                              },
                              onTap: () => context.go('/product/${p.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}