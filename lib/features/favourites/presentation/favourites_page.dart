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
class FavouritesPage extends ConsumerWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;

    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    // ---- Responsive metrics ----
    final double headerHeight = sp(56);
    final double titleFont = (w * 0.09).clamp(sp(24.0), sp(40.0)) * ts;

    final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0));
    final double barRadius = sp(3);
    final double barBlur = sp(3);
    final double barOffsetY = sp(3);

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
                  child: SizedBox(
                    height: headerHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: CartIconButton(
                            onPressed: () => showCartPopup(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Accent bar
                Container(
                  height: barH,
                  margin: EdgeInsets.symmetric(horizontal: sp(12)),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(barRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: barBlur,
                        spreadRadius: sp(0.4),
                        offset: Offset(0, barOffsetY),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: (h * 0.02).clamp(sp(8.0), sp(16.0))),

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
                            return ProductCard(
                              product: p,
                              isFavourite: isFav,
                              onFavToggle: () async {
                                await shopCtrl.toggleFavourite(p.id);
                                await favsCtrl.refresh();
                              },
                              onTap: () => context.go('/product/${p.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Spacer to avoid overlap with bottom navigation.
                SizedBox(height: bottomSpacer),
              ],
            ),

            // ----- Floating assistant bubble -----
            Positioned(
              right: sp(16),
              bottom: navHeight + mq.padding.bottom + sp(26),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: sp(4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/assistant'),
                  child: SizedBox(
                    width: (w * 0.12).clamp(sp(40.0), sp(52.0)),
                    height: (w * 0.12).clamp(sp(40.0), sp(52.0)),
                    child: Icon(
                      Icons.psychology_alt_outlined,
                      size: (w * 0.095).clamp(sp(28.0), sp(36.0)),
                    ),
                  ),
                ),
              ),
            ),

            // ----- Bottom "pill" navigation -----
            Positioned(
              left: sp(16),
              right: sp(16),
              bottom: sp(16),
              child: SafeArea(
                top: false,
                child: _BottomPillNav(
                  index: 1,
                  onChanged: (i) {
                    if (i == 0) context.go('/home');
                    if (i == 1) return;
                    if (i == 3) context.go('/profile');
                    if (i == 2) context.go('/ar');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable bottom navigation with a sliding "pill" highlight (responsive).
class _BottomPillNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomPillNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;

    const tabs = 4;
    final double pad = sp(6);
    final double height = sp(58);
    final double pillRadius = sp(22);
    final double navRadius = sp(28);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(navRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0x22000000),
            blurRadius: sp(22),
            spreadRadius: sp(2),
            offset: Offset(0, sp(10)),
          ),
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: sp(8),
            offset: Offset(0, sp(2)),
          ),
        ],
        border: Border.fromBorderSide(
          const BorderSide(color: Color(0x11000000)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          final slotW = (cons.maxWidth - pad * 2) / tabs;
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
                    borderRadius: BorderRadius.circular(pillRadius),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(pad),
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

/// Single icon button used by the pill navigation (responsive).
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
    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(sp(22)),
        child: Center(
          child: Icon(
            icon,
            size: sp(34),
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
