import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/features/cart/controllers/cart_controller.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/domain/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/controllers/shop_controller.dart';
import '../../shop/controllers/product_details_provider.dart';
import '../../shop/domain/product_details.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int qty = 1;

  String _familyTitle(String categoryId) {
    final up = categoryId.toUpperCase();
    return up.startsWith('XT') ? up : 'Product';
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(productDetailsProvider(widget.productId));
    final shop = ref.watch(shopControllerProvider);
    final shopCtrl = ref.read(shopControllerProvider.notifier);
    final cartState = ref.watch(cartControllerProvider);
    final cartCount = cartState.items.when(
      data: (items) => items.fold<int>(0, (s, e) => s + e.qty),
      loading: () => 0,
      error: (_, __) => 0,
    );

    const double headerH = 320;
    const double overlap = 60;
    const double imageSize = 400;

    return details.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Failed to load: $e'))),
      data: (ProductDetails d) {
        final p = d.product;
        final isFav = shop.favourites.contains(p.id);
        final famTitle = _familyTitle(p.categoryId);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF5F5F7),
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 35),
              onPressed: () => context.go('/home'),
            ),
            centerTitle: true,
            title: Text(
              famTitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 40),
            ),
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => showCartPopup(context, ref),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 35),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 4,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cartCount > 99 ? '99+' : '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(6),
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
            ),
          ),

          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: headerH - overlap,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 16,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  iconSize: 35,
                                  onPressed: () =>
                                      shopCtrl.toggleFavourite(d.product.id),
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFav
                                        ? AppTheme.accent
                                        : Colors.black,
                                  ),
                                ),
                                IconButton(
                                  iconSize: 35,
                                  onPressed: () {}, // TODO: AR / fullscreen
                                  icon: const Icon(
                                    Icons.view_in_ar,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'General Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...d.specs.entries.map(
                              (e) => _SpecRow(title: e.key, value: e.value),
                            ),

                            const Divider(height: 26, thickness: 1),
                            Row(
                              children: [
                                Text(
                                  '${d.product.price.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                _SmallQtyStepper(
                                  value: qty,
                                  onMinus: () => setState(
                                    () => qty = qty > 1 ? qty - 1 : 1,
                                  ),
                                  onPlus: () => setState(() => qty++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 80,
                        right: 80,
                        bottom: 2,
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            height: 45,
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref
                                    .read(cartControllerProvider.notifier)
                                    .add(p, qty: qty);
                                if (!context.mounted) return;
                                showAddToCartSnack(
                                  context,
                                  ref: ref,
                                  product: p,
                                  qty: qty,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'Add to cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: headerH - imageSize + overlap,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: Image.asset(
                      d.product.imageUrl,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, size: 60),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String title;
  final String value;
  const _SpecRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.start,
            softWrap: true,
            style: const TextStyle(fontSize: 14, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _SmallQtyStepper extends StatelessWidget {
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _SmallQtyStepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TinyIconButton(icon: Icons.remove, onTap: onMinus),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          _TinyIconButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      iconSize: 16,
      splashRadius: 18,
      icon: Icon(icon),
    );
  }
}

void showAddToCartSnack(
  BuildContext context, {
  required WidgetRef ref,
  required Product product,
  required int qty,
}) {
  HapticFeedback.lightImpact();

  final textSecondary = Colors.black54;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          Colors.transparent, // lasciamo trasparente e stilizziamo il content
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product.code} added to cart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Qty $qty • ${product.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // bottone "See"
            TextButton(
              onPressed: () => showCartPopup(context, ref),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'See',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
