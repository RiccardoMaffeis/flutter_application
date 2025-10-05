import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/presentation/widgets/product_card.dart';
import '../controllers/favourites_controller.dart';
import '../../shop/controllers/shop_controller.dart'; // <— IMPORTANTE

class FavouritesPage extends ConsumerWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favouritesControllerProvider);
    final favsCtrl = ref.read(favouritesControllerProvider.notifier);

    // Stato globale Shop: contiene Set<String> favourites
    final shopState = ref.watch(shopControllerProvider);
    final shopCtrl  = ref.read(shopControllerProvider.notifier);

    // Se i preferiti cambiano altrove, ricarica la lista qui
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Favourite',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900, fontSize: 36),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {}, // TODO: cart
                        icon: const Icon(Icons.shopping_cart_outlined, size: 32),
                      ),
                    ],
                  ),
                ),
                // linea rossa
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

                Expanded(
                  child: favs.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(child: Text('No favourites yet'));
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.52, // stesso della ShopPage
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i];
                            final isFav = shopState.favourites.contains(p.id);

                            return ProductCard(
                              product: p,
                              isFavourite: isFav,
                              onFavToggle: () async {
                                await shopCtrl.toggleFavourite(p.id); // aggiorna globale
                                await favsCtrl.refresh();              // rimuovi dalla lista
                              },
                              onTap: () {}, // TODO: dettaglio/AR
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

            // bubble AI
            Positioned(
              right: 16,
              bottom: 90,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {}, // TODO
                  child: const SizedBox(
                    width: 44, height: 44,
                    child: Icon(Icons.psychology_alt_outlined, size: 35),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: _BottomPillNav(
                index: 1,
                onChanged: (i) {
                  if (i == 0) context.go('/home');
                  if (i == 1) return;
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
          BoxShadow(color: Color(0x22000000), blurRadius: 22, spreadRadius: 2, offset: Offset(0,10)),
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0,2)),
        ],
        border: Border.fromBorderSide(const BorderSide(color: Color(0x11000000))),
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
                left: pad + index * slotW, top: pad, bottom: pad, width: slotW,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accent, borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(pad),
                child: Row(
                  children: [
                    _NavIcon(icon: Icons.shopping_bag_outlined, selected: index==0, onTap: ()=>onChanged(0)),
                    _NavIcon(icon: Icons.favorite_border,       selected: index==1, onTap: ()=>onChanged(1)),
                    _NavIcon(icon: Icons.person_outline,         selected: index==2, onTap: ()=>onChanged(2)),
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
  const _NavIcon({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Icon(icon, size: 34, color: selected ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
