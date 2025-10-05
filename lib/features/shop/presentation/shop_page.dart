import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/shop_controller.dart';
import 'widgets/product_card.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopControllerProvider);
    final ctrl = ref.read(shopControllerProvider.notifier);

    // Etichette visive per le categorie (in ordine)
    const categoryLabels = ['All', 'XT1', 'XT2', 'XT3', 'XT4', 'XT5', 'XT6', 'XT7'];

    // Trova l'indice della categoria selezionata nello stato
    final selectedIdx = state.categories.indexWhere(
      (c) => c.id == state.selectedCategoryId,
    );

    // Titolo da mostrare sopra la griglia
    final sectionTitle =
        (selectedIdx >= 0 && selectedIdx < categoryLabels.length)
        ? categoryLabels[selectedIdx]
        : categoryLabels.first; // fallback: "All"

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),

      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // riga con icone e titolo centrato
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {}, // TODO: search
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
                      IconButton(
                        onPressed: () {}, // TODO: cart
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 35,
                        ),
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
                        offset: const Offset(
                          0,
                          3,
                        ), // sposta l’ombra verso il basso
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // strip categorie: etichette testuali fisse
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
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // griglia prodotti
                Expanded(
                  child: state.products.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load: $e')),
                    data: (items) {
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
                              onTap: () {
                                // TODO: product details / AR
                              },
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
                index: _navIndex,
                onChanged: (i) => setState(() => _navIndex = i),
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
