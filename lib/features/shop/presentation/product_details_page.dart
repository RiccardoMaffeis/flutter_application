import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/core/ar/arcore_check.dart';
import 'package:flutter_application/core/pdf/pdf_cache_service.dart';
import 'package:flutter_application/features/cart/controllers/cart_controller.dart';
import 'package:flutter_application/features/cart/presentation/cart_popup.dart';
import 'package:flutter_application/features/shop/domain/product.dart';
import 'package:flutter_application/features/shop/presentation/widgets/cart_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_application/core/tour/coach_tour.dart';

import '../../../core/theme/app_theme.dart';
import '../../shop/controllers/shop_controller.dart';
import '../../shop/domain/product_details.dart';

/// Product details screen:
/// - Shows hero image, specs, price and quantity stepper
/// - Allows adding to cart, opening datasheet PDF, toggling favourite
/// - Can launch AR viewer if a matching GLB model exists
class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int qty = 1; // Selected quantity to add to cart
  bool _pdfBusy = false; // Prevents multiple PDF taps while loading

  // Simple UI cooldown to avoid spamming actions (cart, etc.)
  DateTime? _cooldownUntil;

  bool get _cooldownActive =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  void _startCooldown([int ms = 700]) {
    _cooldownUntil = DateTime.now().add(Duration(milliseconds: ms));
  }

  /// Maps a category id to a visible family title (e.g., "XT3" or fallback)
  String _familyTitle(String categoryId) {
    final up = categoryId.toUpperCase();
    return up.startsWith('XT') ? up : 'Product';
  }

  /// Returns true if an asset exists in the bundle.
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Regex helpers to extract family (xtN) and number of poles from product text.
  static final _reFamily = RegExp(r'\b(xt\d+)\b', caseSensitive: false);
  static final _rePoles = RegExp(
    r'\b([23468])\s*(?:p|poli)\b',
    caseSensitive: false,
  );

  /// Attempts to resolve a GLB 3D model path for the product, trying several
  /// common folder/name patterns. Returns null if nothing is found.
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

  /// Scale factor hook for family-specific hero image tweaks (currently fixed).
  double _familyImageScale(String famUp) => 0.82;

  // Keys used by the in-app guided tour (ShowcaseView).
  final _kBack = GlobalKey();
  final _kPdf = GlobalKey();
  final _kAdd = GlobalKey();
  bool _tourScheduled = false;

  /// Starts (or queues) the guided tour for this screen once the frame is ready.
  void _scheduleTour(BuildContext context) {
    if (_tourScheduled) return;
    _tourScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(coachTourServiceProvider).startOrQueue(
        context,
        TourSection.product,
        [_kBack, _kPdf, _kAdd],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Product details (including specs) are provided via a FutureProvider family.
    final details = ref.watch(productDetailsProvider(widget.productId));
    // Shop state provides favourites and other global info.
    final shop = ref.watch(shopControllerProvider);
    final shopCtrl = ref.read(shopControllerProvider.notifier);

    // ---------- Responsive metrics ----------
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => (v * scale).toDouble();

    final double titleSize = (w * 0.09).clamp(sp(24.0), sp(40.0)).toDouble();
    final double iconSize = (w * 0.085).clamp(sp(26.0), sp(35.0)).toDouble();
    final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0)).toDouble();

    _familyImageScale('');
    final double imgSizeBaseFrac = 0.94;

    final double sidePad = (w * 0.04);
    final double sheetTopRadius = (w * 0.055);

    // CTA ("Add to cart") metrics
    final double ctaSide = (w * 0.12);
    final double ctaH = (h * 0.06);
    final double ctaRadius = ctaH * 0.5;
    final double ctaFont = (w * 0.055) * ts;

    // Typography for sections/specs/price
    final double sectionTitle = (w * 0.055) * ts;
    final double priceSize = (w * 0.07) * ts;
    final double specTitleSize = (w * 0.045) * ts;
    final double specValueSize = (w * 0.04) * ts;
    final double snackFont = (w * 0.04) * ts;

    // PDF floating button metrics
    final double pdfBtn = (w * 0.11);
    final double pdfIcon = (pdfBtn * 0.5);

    final bgScaffold = theme.scaffoldBackgroundColor;
    final onSurface = cs.onSurface.withOpacity(0.85);
    final dividerColor = cs.outlineVariant;

    // ---------- Async states: loading/error/data ----------
    return details.when(
      loading: () => Scaffold(
        backgroundColor: bgScaffold,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: bgScaffold,
        body: Center(
          child: Text(
            'Failed to load: $e',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: w * 0.045 * ts,
              color: onSurface,
            ),
          ),
        ),
      ),
      data: (ProductDetails d) {
        _scheduleTour(context);

        final p = d.product;
        final famTitle = _familyTitle(p.categoryId);
        final isFav = shop.favourites.contains(p.id);

        final famUp = p.categoryId.toUpperCase();
        final imageSize = w * imgSizeBaseFrac * _familyImageScale(famUp);
        final headerH = imageSize * 0.86;
        final overlap = imageSize * 0.16;

        return Scaffold(
          backgroundColor: bgScaffold,
          body: SafeArea(
            child: Column(
              children: [
                // ----- Header with truly centered title and symmetric paddings -----
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sp(12),
                    vertical: sp(6),
                  ),
                  child: SizedBox(
                    height: math.max(iconSize, sp(40)) + sp(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Centered title with extra horizontal padding so icons won't overlap it
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: iconSize * 2.4,
                          ),
                          child: Text(
                            famTitle,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: titleSize,
                                ),
                          ),
                        ),

                        // Back button (Showcase target) on the left
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Showcase(
                            key: _kBack,
                            description:
                                'Go back to the previous page or home.',
                            overlayOpacity: 0.2,
                            targetPadding: const EdgeInsets.all(2),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              iconSize: iconSize,
                              color: cs.onSurface,
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/home');
                                }
                              },
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                            ),
                          ),
                        ),

                        // Help (starts tour) + Cart on the right
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.help_outline, size: iconSize),
                                tooltip: 'Show page tour',
                                onPressed: () => ref
                                    .read(coachTourServiceProvider)
                                    .startNow(context, [_kBack, _kPdf, _kAdd]),
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
                      ],
                    ),
                  ),
                ),

                // Accent bar under the header (ABB style)
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

                // ----- Main content area (sheet + floating image + floating PDF button) -----
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // White sheet with rounded top that holds specs and actions
                      Positioned(
                        top: headerH - overlap,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(sheetTopRadius),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withOpacity(0.12),
                                blurRadius: w * 0.04,
                                offset: Offset(0, -w * 0.02),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  // Favourite + AR quick actions row
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      sidePad * 0.4,
                                      sidePad * 0.4,
                                      sidePad * 0.4,
                                      0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Toggle favourite
                                        IconButton(
                                          iconSize: iconSize,
                                          onPressed: () =>
                                              shopCtrl.toggleFavourite(p.id),
                                          tooltip: isFav
                                              ? 'Remove favourite'
                                              : 'Add favourite',
                                          icon: Icon(
                                            isFav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: isFav
                                                ? AppTheme.accent
                                                : cs.onSurface,
                                          ),
                                        ),
                                        // Open AR viewer (if model is available and AR supported)
                                        IconButton(
                                          iconSize: iconSize,
                                          tooltip: 'View in AR',
                                          onPressed: () async {
                                            final modelPath =
                                                await _findModelPath(p);
                                            if (modelPath == null) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '3D model not found for ${p.code}',
                                                    style: TextStyle(
                                                      fontSize: snackFont,
                                                    ),
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
                                              },
                                            );
                                          },
                                          icon: Icon(
                                            Icons.view_in_ar,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Scrollable specs + price + qty stepper
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        sidePad,
                                        h * 0.02,
                                        sidePad,
                                        h * 0.16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'General Information',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontSize: sectionTitle,
                                                  fontWeight: FontWeight.w900,
                                                  color: cs.onSurface,
                                                ),
                                          ),
                                          SizedBox(height: h * 0.01),
                                          // Render all specs except "price"-like ones (those are handled separately)
                                          ...d.specs.entries
                                              .where((e) {
                                                final k = e.key
                                                    .trim()
                                                    .toLowerCase();
                                                return !{
                                                  'price',
                                                  'prezzo',
                                                  'unit price',
                                                  'list price',
                                                }.contains(k);
                                              })
                                              .map(
                                                (e) => _SpecRow(
                                                  title: e.key,
                                                  value: e.value,
                                                  titleSize: specTitleSize,
                                                  valueSize: specValueSize,
                                                ),
                                              ),

                                          // Price + quantity selection
                                          Divider(
                                            height: h * 0.04,
                                            thickness: 1,
                                            color: dividerColor,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '${d.product.price.toStringAsFixed(2)} €',
                                                style: theme
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontSize: priceSize,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: cs.onSurface,
                                                    ),
                                              ),
                                              const Spacer(),
                                              _SmallQtyStepper(
                                                value: qty,
                                                onMinus: () => setState(
                                                  () => qty = qty > 1
                                                      ? qty - 1
                                                      : 1,
                                                ),
                                                onPlus: () =>
                                                    setState(() => qty++),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Bottom "Add to cart" CTA (Showcase target)
                              Positioned(
                                left: ctaSide,
                                right: ctaSide,
                                bottom: h * 0.02,
                                child: SafeArea(
                                  top: false,
                                  child: Showcase(
                                    key: _kAdd,
                                    description:
                                        'Add the selected quantity to your cart.',
                                    overlayOpacity: 0.2,
                                    targetPadding: const EdgeInsets.all(6),
                                    targetBorderRadius: BorderRadius.circular(
                                      ctaRadius,
                                    ),
                                    child: SizedBox(
                                      height: ctaH,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                cartControllerProvider.notifier,
                                              )
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
                                            borderRadius: BorderRadius.circular(
                                              ctaRadius,
                                            ),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: Text(
                                          'Add to cart',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: cs.onPrimary,
                                                fontSize: ctaFont,
                                                fontWeight: FontWeight.w700,
                                              ),
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

                      // Centered floating product image overlapping the sheet
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
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  size: w * 0.16,
                                  color: cs.onSurface.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating circular PDF button (Showcase target)
                      Positioned(
                        top: h * 0.01,
                        right: sidePad * 0.6,
                        child: Showcase(
                          key: _kPdf,
                          description: 'Open the product datasheet (PDF).',
                          overlayOpacity: 0.2,
                          targetPadding: const EdgeInsets.all(6),
                          child: Material(
                            color: AppTheme.accent,
                            shape: const CircleBorder(),
                            elevation: 2,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pdfBusy
                                  ? null
                                  : () async {
                                      setState(() => _pdfBusy = true);
                                      try {
                                        // Slight delay for better perceived feedback
                                        await Future.delayed(
                                          const Duration(milliseconds: 120),
                                        );
                                        final prod = d.product;
                                        // Detect family from product text
                                        final famUpper = _reFamily
                                            .firstMatch(
                                              '${prod.categoryId} ${prod.code} ${prod.displayName}'
                                                  .toLowerCase(),
                                            )
                                            ?.group(1)
                                            ?.toUpperCase();

                                        if (famUpper == null) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Family not recognized',
                                                style: TextStyle(
                                                  fontSize: snackFont,
                                                ),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        // Resolve PDF source (file or network) from cache/service
                                        final src = await PdfCacheService
                                            .instance
                                            .resolveByFamilyAndId(
                                              famUpper: famUpper,
                                              productId: prod.id,
                                            );

                                        if (!mounted) return;
                                        if (src == null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'PDF not found: $famUpper/${prod.id}.pdf',
                                                style: TextStyle(
                                                  fontSize: snackFont,
                                                ),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        // Navigate to a shared PDF viewer route
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
                                        if (mounted)
                                          setState(() => _pdfBusy = false);
                                      }
                                    },
                              child: SizedBox(
                                width: pdfBtn,
                                height: pdfBtn,
                                child: Tooltip(
                                  message: 'Open PDF / datasheet',
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 160),
                                    child: _pdfBusy
                                        ? SizedBox(
                                            key: const ValueKey('pdfbusy'),
                                            width: pdfIcon,
                                            height: pdfIcon,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                          )
                                        : Icon(
                                            key: const ValueKey('pdficon'),
                                            Icons.picture_as_pdf,
                                            color: cs.onPrimary,
                                            size: pdfIcon,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Single specification row with title and value.
/// Uses responsive typography sizes passed by parent.
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.007,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spec title (bold)
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: titleSize,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.004),
          // Spec value (regular)
          Text(
            value,
            textAlign: TextAlign.start,
            softWrap: true,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: valueSize,
              height: 1.3,
              color: cs.onSurface.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal quantity stepper used beside the price.
/// Calls [onMinus]/[onPlus] without holding internal state.
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
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final double height = (h * 0.05);
    final double iconBox = height * 0.7;
    final double iconSize = iconBox * 0.6;
    final double qtyFont = (w * 0.045);

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: w * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.4),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.12),
            blurRadius: w * 0.02,
            offset: Offset(0, w * 0.01),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease
          _TinyIconButton(
            icon: Icons.remove,
            onTap: onMinus,
            size: iconBox,
            iconSize: iconSize,
          ),
          SizedBox(width: w * 0.01),
          // Current qty (fixed width to avoid layout jump)
          SizedBox(
            width: w * 0.09,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: qtyFont,
                color: cs.onSurface,
              ),
            ),
          ),
          SizedBox(width: w * 0.012),
          // Increase
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

/// Unstyled tiny circular icon button used by the stepper.
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
    final s = size ?? MediaQuery.of(context).size.height * 0.04;
    final isz = iconSize ?? s * 0.6;
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: s, height: s),
      iconSize: isz,
      splashRadius: s * 0.65,
      color: cs.onSurface,
      icon: Icon(icon),
      tooltip: '',
    );
  }
}

/// Shows a floating, styled SnackBar confirming the item was added to cart.
/// Provides a quick "See" action to open the cart popup.
void showAddToCartSnack(
  BuildContext context, {
  required WidgetRef ref,
  required Product product,
  required int qty,
}) {
  HapticFeedback.lightImpact();

  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final mq = MediaQuery.of(context);
  final w = mq.size.width;
  final h = mq.size.height;
  final ts = mq.textScaleFactor.clamp(1.0, 1.3);

  final double radius = w * 0.04;
  final double titleFont = (w * 0.04) * ts;
  final double subtitleFont = (w * 0.035) * ts;
  final double actionFont = (w * 0.04) * ts;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.fromLTRB(w * 0.03, 0, w * 0.03, h * 0.015),
      duration: const Duration(seconds: 2),
      content: Container(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.03,
          vertical: h * 0.012,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.13),
              blurRadius: w * 0.04,
              offset: Offset(0, w * 0.02),
            ),
          ],
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            // Green circular badge with checkmark
            Container(
              width: w * 0.085,
              height: w * 0.085,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.35),
                    blurRadius: w * 0.02,
                    offset: Offset(0, w * 0.01),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.check, size: w * 0.055, color: Colors.white),
            ),
            SizedBox(width: w * 0.03),
            // Title + subtitle (product code + name and qty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product.code} added to cart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: titleFont,
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: h * 0.003),
                  Text(
                    'Qty $qty • ${product.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: subtitleFont,
                      color: cs.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: w * 0.02),
            // Quick action to open the cart overlay
            TextButton(
              onPressed: () => showCartPopup(context, ref),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.025,
                  vertical: h * 0.01,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(fontSize: actionFont),
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
