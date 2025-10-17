import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application/core/ar/arcore_check.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/product.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final bool isFavourite;
  final VoidCallback onFavToggle;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavourite,
    required this.onFavToggle,
    required this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _cardBusy = false;
  bool _favBusy = false;
  bool _arBusy = false;

  DateTime? _cooldownUntil;
  bool get _cooldownActive =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
  void _startCooldown([int ms = 600]) =>
      _cooldownUntil = DateTime.now().add(Duration(milliseconds: ms));

  static final RegExp _reFamily = RegExp(r'xt\d+', caseSensitive: false);
  static final RegExp _rePoles = RegExp(
    r'([23468])\s*(?:p|poli|pole|poles)\b',
    caseSensitive: false,
  );

  static Future<String?> _findModelPath(Product p) async {
    final hay = '${p.categoryId} ${p.code} ${p.displayName}'.toLowerCase();
    final fam = _reFamily.firstMatch(hay)?.group(0)?.toUpperCase();
    final polesNum = _rePoles.firstMatch(hay)?.group(1);
    final poles = polesNum == null ? null : '${polesNum}p';

    final candidates = <String>[
      if (fam != null && poles != null) 'lib/3Dmodels/$fam/${fam}_$poles.glb',
      if (fam != null && poles != null) 'lib/3Dmodels/${fam}_$poles.glb',
      if (fam != null) 'lib/3Dmodels/$fam/${fam}.glb',
      if (fam != null) 'lib/3Dmodels/${fam}.glb',
    ];

    for (final path in candidates) {
      if (await _assetExists(path)) return path;
    }
    return null;
  }

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _safeCardTap() {
    if (_cardBusy || _cooldownActive) return;
    _cardBusy = true;
    _startCooldown(500);
    setState(() {});
    widget.onTap();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _cardBusy = false;
      setState(() {});
    });
  }

  Future<void> _safeFavToggle() async {
    if (_favBusy || _cooldownActive) return;
    setState(() {
      _favBusy = true;
      _startCooldown(500);
    });
    try {
      widget.onFavToggle();
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _favBusy = false);
      }
    }
  }

  Future<void> _openAR() async {
    if (_arBusy || _cooldownActive) return;
    setState(() {
      _arBusy = true;
      _startCooldown(600);
    });
    try {
      final modelPath = await _findModelPath(widget.product);
      if (modelPath == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('3D model not found for ${widget.product.code}'),
          ),
        );
        return;
      }

      final ok = await ArCoreCheck.ensureAvailable(context);
      if (!ok || !context.mounted) return;

      await context.push(
        '/ar-live',
        extra: {
          'title': widget.product.code,
          'assetGlb': modelPath,
          'scale': 0.18,
        },
      );
    } finally {
      if (mounted) setState(() => _arBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavourite = widget.isFavourite;
    final product = widget.product;

    return LayoutBuilder(
      builder: (context, cons) {
        // ---- Responsive metrics based on card width ----
        final w = cons.maxWidth;

        final double radius = (w * 0.11).clamp(16.0, 24.0);
        final double codeFont = (w * 0.075).clamp(14.0, 18.0);
        final double nameFont = (w * 0.06).clamp(12.0, 14.0);
        const double nameLineHeight = 1.25;
        final double twoLinesHeight = nameFont * nameLineHeight * 2;

        final double topPad = (w * 0.055).clamp(14.0, 20.0);
        final double innerHPad = (w * 0.05).clamp(10.0, 14.0);
        final double innerBottomPad = (w * 0.045).clamp(10.0, 18.0);

        final double actionBox = (w * 0.18).clamp(32.0, 40.0);
        final double actionIcon = (actionBox * 0.9).clamp(26.0, 36.0);
        final double spinner = (actionBox * 0.5).clamp(16.0, 20.0);

        return Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: _cardBusy ? null : _safeCardTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Code (top)
                Padding(
                  padding: EdgeInsets.fromLTRB(innerHPad, topPad, innerHPad, 6),
                  child: Text(
                    product.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: codeFont,
                    ),
                  ),
                ),

                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius * 0.5),
                    ),
                    child: Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Transform.scale(
                        scale: 1.05,
                        child: Image.asset(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stack) {
                            debugPrint(
                              'Asset missing: ${product.imageUrl} -> $error',
                            );
                            return const Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: Colors.black26,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Name + actions
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    innerHPad,
                    innerBottomPad,
                    innerHPad,
                    innerBottomPad,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: twoLinesHeight),
                        child: Text(
                          product.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: nameFont,
                            height: nameLineHeight,
                          ),
                          strutStyle: StrutStyle(
                            forceStrutHeight: true,
                            fontSize: nameFont,
                            height: nameLineHeight,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Favourite
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: actionBox,
                              height: actionBox,
                            ),
                            onPressed: _favBusy ? null : _safeFavToggle,
                            icon: _favBusy
                                ? SizedBox(
                                    width: spinner,
                                    height: spinner,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isFavourite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFavourite
                                        ? AppTheme.accent
                                        : Colors.black,
                                    size: actionIcon,
                                  ),
                          ),

                          // AR
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _arBusy ? null : _openAR,
                              child: SizedBox(
                                width: actionBox,
                                height: actionBox,
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: _arBusy
                                        ? SizedBox(
                                            key: const ValueKey('arbusy'),
                                            width: spinner,
                                            height: spinner,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                          )
                                        : Icon(
                                            key: const ValueKey('aricon'),
                                            Icons.view_in_ar,
                                            size: actionIcon,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
