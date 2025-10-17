import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/core/ar/arcore_check.dart';
import 'package:flutter_application/core/pdf/pdf_cache_service.dart';
import 'package:flutter_application/features/cart/controllers/cart_controller.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/domain/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/controllers/shop_controller.dart';
import '../../shop/domain/product_details.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int qty = 1;

  bool _pdfBusy = false;

  String _familyTitle(String categoryId) {
    final up = categoryId.toUpperCase();
    return up.startsWith('XT') ? up : 'Product';
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static final _reFamily = RegExp(r'\b(xt\d+)\b', caseSensitive: false);
  static final _rePoles = RegExp(
    r'\b([23468])\s*(?:p|poli)\b',
    caseSensitive: false,
  );

  Future<String?> _findModelPath(Product p) async {
    final hay = '${p.categoryId} ${p.code} ${p.displayName}'.toLowerCase();
    final fam = _reFamily.firstMatch(hay)?.group(1)?.toUpperCase();
    final poles = _rePoles.firstMatch(hay)?.group(1);
    final pp = poles == null ? null : '${poles}p';

    final candidates = <String>[
      if (fam != null && pp != null) 'lib/3Dmodels/$fam/${fam}_$pp.glb',
      if (fam != null && pp != null) 'lib/3Dmodels/${fam}_$pp.glb',
      if (fam != null) 'lib/3Dmodels/$fam/${fam}.glb',
      if (fam != null) 'lib/3Dmodels/${fam}.glb',
    ];

    for (final path in candidates) {
      if (await _assetExists(path)) return path;
    }
    return null;
  }

  double _arScaleFor(String famUp) {
    switch (famUp) {
      case 'XT1':
        return 0.18;
      case 'XT2':
        return 0.18;
      default:
        return 0.20;
    }
  }

  double _familyImageScale(String famUp) => 0.82;

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

    return details.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Failed to load: $e'))),
      data: (ProductDetails d) {
        final p = d.product;
        final isFav = shop.favourites.contains(p.id);
        final famTitle = _familyTitle(p.categoryId);

        return LayoutBuilder(
          builder: (context, cons) {
            final w = cons.maxWidth;
            final h = cons.maxHeight;

            // -------- Responsive metrics --------
            final double titleFont = (w * 0.09).clamp(24.0, 40.0);
            final double iconSize = (w * 0.085).clamp(26.0, 35.0);
            final double barH = (w * 0.01).clamp(3.0, 4.0);

            // Product image sizing
            const double baseFrac = 0.94;
            final famUp = p.categoryId.toUpperCase();
            final famScale = _familyImageScale(famUp);
            final double imageSize = (w * baseFrac * famScale).clamp(
              220.0,
              440.0,
            );

            // Header block & overlap
            final double headerH = (imageSize * 0.86).clamp(180.0, 380.0);
            final double overlap = (imageSize * 0.16).clamp(20.0, 90.0);

            // Bottom "Add to cart" CTA paddings and sizes
            final double ctaSidePad = (w * 0.12).clamp(16.0, 120.0);
            final double ctaHeight = (h * 0.06).clamp(44.0, 52.0);
            final double ctaFont = (w * 0.055).clamp(18.0, 22.0);

            // Section fonts
            final double sectionTitle = (w * 0.055).clamp(18.0, 22.0);
            final double priceFont = (w * 0.07).clamp(22.0, 28.0);
            final double specTitleFont = (w * 0.045).clamp(14.0, 16.0);
            final double specValueFont = (w * 0.04).clamp(13.0, 14.0);

            // Floating PDF button size
            final double pdfBtn = (w * 0.11).clamp(38.0, 46.0);
            final double pdfIcon = (pdfBtn * 0.52).clamp(18.0, 24.0);

            // Fav / AR icons
            final double actionIcon = iconSize;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F5F7),
              appBar: AppBar(
                backgroundColor: const Color(0xFFF5F5F7),
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, size: iconSize),
                  onPressed: () => context.go('/home'),
                ),
                centerTitle: true,
                title: Text(
                  famTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: titleFont,
                  ),
                ),
                actions: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => showCartPopup(context, ref),
                        icon: Icon(
                          Icons.shopping_cart_outlined,
                          size: iconSize,
                        ),
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
                    height: barH,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
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
                  // White rounded sheet below the header
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
                          Column(
                            children: [
                              // Favourites + AR actions
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      iconSize: actionIcon,
                                      onPressed: () => shopCtrl.toggleFavourite(
                                        d.product.id,
                                      ),
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
                                      iconSize: actionIcon,
                                      onPressed: () async {
                                        final modelPath = await _findModelPath(
                                          p,
                                        );

                                        if (modelPath == null) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '3D model not found for ${p.code}',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final ok =
                                            await ArCoreCheck.ensureAvailable(
                                              context,
                                            );
                                        if (!ok || !mounted) return;

                                        context.push(
                                          '/ar-live',
                                          extra: {
                                            'title': p.id,
                                            'assetGlb': modelPath,
                                            'scale': _arScaleFor(
                                              p.categoryId.toUpperCase(),
                                            ),
                                          },
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.view_in_ar,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Scrollable content
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    (h * 0.02).clamp(12.0, 20.0),
                                    16,
                                    (h * 0.16).clamp(100.0, 140.0),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'General Information',
                                        style: TextStyle(
                                          fontSize: sectionTitle,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...d.specs.entries.map(
                                        (e) => _SpecRow(
                                          title: e.key,
                                          value: e.value,
                                          titleSize: specTitleFont,
                                          valueSize: specValueFont,
                                        ),
                                      ),
                                      const Divider(height: 26, thickness: 1),
                                      Row(
                                        children: [
                                          Text(
                                            '${d.product.price.toStringAsFixed(2)} €',
                                            style: TextStyle(
                                              fontSize: priceFont,
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
                              ),
                            ],
                          ),

                          // Add to cart CTA (bottom, centered)
                          Positioned(
                            left: ctaSidePad,
                            right: ctaSidePad,
                            bottom: 20,
                            child: SafeArea(
                              top: false,
                              child: SizedBox(
                                height: ctaHeight,
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
                                  child: Text(
                                    'Add to cart',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ctaFont,
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

                  // Product image (overlapping the header)
                  Positioned(
                    top: headerH - imageSize + overlap,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IgnorePointer(
                        child: SizedBox(
                          width: imageSize,
                          height: imageSize,
                          child: Image.asset(
                            d.product.imageUrl,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating PDF button
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Material(
                      color: AppTheme.accent,
                      shape: const CircleBorder(),
                      elevation: 3,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pdfBusy
                            ? null
                            : () async {
                                setState(() => _pdfBusy = true);
                                try {
                                  // Optional: tiny delay to soften double taps
                                  await Future.delayed(
                                    const Duration(milliseconds: 120),
                                  );

                                  final prod = d.product;
                                  final famUpper = _reFamily
                                      .firstMatch(
                                        '${prod.categoryId} ${prod.code} ${prod.displayName}'
                                            .toLowerCase(),
                                      )
                                      ?.group(1)
                                      ?.toUpperCase();

                                  if (famUpper == null) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Family not recognized'),
                                      ),
                                    );
                                    return;
                                  }

                                  final src = await PdfCacheService.instance
                                      .resolveByFamilyAndId(
                                        famUpper: famUpper,
                                        productId: prod.id,
                                      );

                                  if (!mounted) return;
                                  if (src == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'PDF not found: $famUpper/${prod.id}.pdf',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (src is PdfFile) {
                                    await context.push(
                                      '/pdf-viewer',
                                      extra: {
                                        'title': prod.code,
                                        'pdfFile': src.path,
                                      },
                                    );
                                  } else if (src is PdfNetwork) {
                                    await context.push(
                                      '/pdf-viewer',
                                      extra: {
                                        'title': prod.code,
                                        'pdfUrl': src.url,
                                      },
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _pdfBusy = false);
                                }
                              },
                        child: SizedBox(
                          width: pdfBtn,
                          height: pdfBtn,
                          child: Tooltip(
                            message: 'Open PDF / datasheet',
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 120),
                              child: _pdfBusy
                                  ? SizedBox(
                                      key: const ValueKey('pdfbusy'),
                                      width: pdfIcon,
                                      height: pdfIcon,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      key: const ValueKey('pdficon'),
                                      Icons.picture_as_pdf,
                                      color: Colors.white,
                                      size: pdfIcon,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String title;
  final String value;
  final double titleSize;
  final double valueSize;
  const _SpecRow({
    required this.title,
    required this.value,
    required this.titleSize,
    required this.valueSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: titleSize),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.start,
            softWrap: true,
            style: TextStyle(fontSize: valueSize, height: 1.3),
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
    final w = MediaQuery.of(context).size.width;
    final double h = (w * 0.09).clamp(34.0, 40.0);
    final double iconBox = (h * 0.7).clamp(24.0, 28.0);
    final double iconSize = (iconBox * 0.6).clamp(14.0, 16.0);
    final double qtyFont = (w * 0.045).clamp(16.0, 18.0);

    return Container(
      height: h,
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
          _TinyIconButton(
            icon: Icons.remove,
            onTap: onMinus,
            size: iconBox,
            iconSize: iconSize,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: (w * 0.09).clamp(24.0, 32.0),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: qtyFont),
            ),
          ),
          const SizedBox(width: 6),
          _TinyIconButton(
            icon: Icons.add,
            onTap: onPlus,
            size: iconBox,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double? size;
  final double? iconSize;

  const _TinyIconButton({
    required this.icon,
    required this.onTap,
    this.size,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 28.0;
    final isz = iconSize ?? 16.0;
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: s, height: s),
      iconSize: isz,
      splashRadius: (s * 0.65).clamp(16.0, 22.0),
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
      backgroundColor: Colors.transparent,
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
