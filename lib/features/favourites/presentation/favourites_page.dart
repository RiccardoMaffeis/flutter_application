import 'package:flutter/material.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/presentation/widgets/cart_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/presentation/widgets/product_card.dart';
import '../controllers/favourites_controller.dart';
import '../../shop/controllers/shop_controller.dart';

/// Page that displays the user's favourite products.
/// - Reads favourites via Riverpod providers
/// - Shows a responsive grid of ProductCard widgets
/// - Includes a floating assistant button and a custom bottom "pill" nav
class FavouritesPage extends ConsumerWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Basic responsive metrics derived from MediaQuery for consistent sizing.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    // ---- Responsive metrics ----
    final double titleFont = (w * 0.09).clamp(24.0, 40.0) * ts;
    final double headerSpacer = (w * 0.12).clamp(40.0, 56.0);
    final double barH = (w * 0.01).clamp(3.0, 4.0);

    // State/placeholder text sizes (errors, empty state).
    final double stateFont = (w * 0.045).clamp(14.0, 18.0) * ts;

    // Reserve space for bottom navigation so content doesn't collide.
    final double navHeight = (w * 0.12).clamp(52.0, 64.0);
    final double bottomSpacer = navHeight + mq.padding.bottom + 24;

    // Grid breakpoints based on width; tune child aspect ratio accordingly.
    int columns;
    if (w >= 1000) {
      columns = 4;
    } else if (w >= 700) {
      columns = 3;
    } else {
      columns = 2;
    }
    final double aspect = columns >= 4 ? 0.70 : (columns == 3 ? 0.60 : 0.52);

    // Favourites async state + controller (fetches/refreshes list of products).
    final favs = ref.watch(favouritesControllerProvider);
    final favsCtrl = ref.read(favouritesControllerProvider.notifier);

    // Shop state contains the set of favourite IDs; used to mark ProductCard stars.
    final shopState = ref.watch(shopControllerProvider);
    final shopCtrl = ref.read(shopControllerProvider.notifier);

    // Rebuild/refresh favourites when the set of favourite IDs changes.
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
                // ----- Header -----
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      // Spacer to keep title centered (mirrors the trailing cart button width).
                      SizedBox(width: headerSpacer),
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
                      // Cart icon opens the cart popup dialog.
                      CartIconButton(
                        onPressed: () => showCartPopup(context, ref),
                      ),
                    ],
                  ),
                ),
                // Accent bar (brand color) below the header
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

                // ----- Content -----
                Expanded(
                  child: favs.when(
                    // Loading spinner while favourites are being fetched.
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    // Error state with message.
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
                    // Data: show empty state or the grid of favourite products.
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
                            // Compute "is favourite" flag from ShopState for the star toggle.
                            final isFav = shopState.favourites.contains(p.id);
                            return ProductCard(
                              product: p,
                              isFavourite: isFav,
                              // Toggle favourite in shop controller and refresh the favourites list.
                              onFavToggle: () async {
                                await shopCtrl.toggleFavourite(p.id);
                                await favsCtrl.refresh();
                              },
                              // Navigate to product details route.
                              onTap: () => context.go('/product/${p.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Bottom spacer to avoid overlap with the pill navigation.
                SizedBox(height: bottomSpacer),
              ],
            ),

            // ----- Floating assistant bubble -----
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

            // ----- Bottom "pill" navigation -----
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _BottomPillNav(
                  index: 1, // Highlight the "Favourites" tab.
                  onChanged: (i) {
                    // Simple index-based route switching.
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
