import 'package:flutter/material.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/presentation/widgets/cart_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/presentation/widgets/product_card.dart';
import '../controllers/favourites_controller.dart';
import '../../shop/controllers/shop_controller.dart';

/// Favourites page:
/// - Shows a grid of the user's favourite products
/// - Reacts to favourites changes from ShopController
/// - Provides quick access to the cart popup and bottom pill navigation
class FavouritesPage extends ConsumerWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;

    // ---- Responsive metrics ----
    final double titleFont = (w * 0.09).clamp(24.0, 40.0);
    final double headerSpacer = (w * 0.12).clamp(40.0, 56.0);
    final double barH = (w * 0.01).clamp(3.0, 4.0);

    // Bottom nav size and extra spacing so content doesn't collide
    final double navHeight = (w * 0.12).clamp(52.0, 64.0);
    final double bottomSpacer = navHeight + mq.padding.bottom + 24;

    // Grid breakpoints
    int columns;
    if (w >= 1000) {
      columns = 4;
    } else if (w >= 700) {
      columns = 3;
    } else {
      columns = 2;
    }
    final double aspect = columns >= 4
        ? 0.70
        : (columns == 3 ? 0.60 : 0.52); // card ratio tuning

    // Derived list of favourite products (AsyncValue<List<Product>>)
    final favs = ref.watch(favouritesControllerProvider);
    final favsCtrl = ref.read(favouritesControllerProvider.notifier);

    // Shop state includes the favourites Set<String> and other shop data
    final shopState = ref.watch(shopControllerProvider);
    final shopCtrl = ref.read(shopControllerProvider.notifier);

    // When the favourites Set changes in ShopController, refresh local list
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
                // ----- Header with title and cart button -----
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: headerSpacer,
                      ), // spacer to balance cart icon
                      Expanded(
                        child: Center(
                          child: Text(
                            'Favourite',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: titleFont,
                                ),
                          ),
                        ),
                      ),
                      // Opens the cart popup dialog
                      CartIconButton(
                        onPressed: () => showCartPopup(context, ref),
                      ),
                    ],
                  ),
                ),
                // Accent underline under the title
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
                SizedBox(height: (h * 0.02).clamp(8.0, 16.0)),

                // ----- Content: grid of favourite products or placeholders -----
                Expanded(
                  child: favs.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(child: Text('No favourites yet'));
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: bottomSpacer),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: aspect,
                              ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i];
                            final isFav = shopState.favourites.contains(p.id);

                            // Product card with favourite toggle and navigation to details
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
                // dynamic space so the grid never collides with the bottom nav
                SizedBox(height: bottomSpacer),
              ],
            ),

            // ----- Floating assistant bubble (placeholder action) -----
            Positioned(
              right: 16,
              bottom: navHeight + mq.padding.bottom + 26,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/assistant'),
                  child: SizedBox(
                    width: (w * 0.12).clamp(40.0, 52.0),
                    height: (w * 0.12).clamp(40.0, 52.0),
                    child: Icon(
                      Icons.psychology_alt_outlined,
                      size: (w * 0.095).clamp(28.0, 36.0),
                    ),
                  ),
                ),
              ),
            ),

            // ----- Bottom "pill" navigation bar -----
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _BottomPillNav(
                  index: 1, // this page (Favourites) is selected
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

/// Reusable "pill" bottom navigation with an animated highlight.
class _BottomPillNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomPillNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final double h = (w * 0.12).clamp(52.0, 64.0);
        final double pad = (h * 0.1).clamp(6.0, 8.0);

        return Container(
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(h * 0.48),
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
            builder: (context, inner) {
              final slotW = (inner.maxWidth - pad * 2) / 4;

              return Stack(
                children: [
                  // Animated highlight under the selected icon
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
                        borderRadius: BorderRadius.circular(h * 0.38),
                      ),
                    ),
                  ),
                  // Row of icons
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
      },
    );
  }
}

/// Single navigation icon within the pill bar.
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
    final w = MediaQuery.of(context).size.width;
    final double size = (w * 0.085).clamp(26.0, 34.0);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Icon(
            icon,
            size: size,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
