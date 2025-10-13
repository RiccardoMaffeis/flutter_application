import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application/core/ar/arcore_check.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/product.dart';

class ProductCard extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    const double titleFontSize = 14;
    const double titleLineHeight = 1.25;
    final double twoLinesHeight = titleFontSize * titleLineHeight * 2;

    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
              child: Text(
                product.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),

            // image (ENLARGED)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
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

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: titleFontSize,
                        height: titleLineHeight,
                      ),
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        fontSize: titleFontSize,
                        height: titleLineHeight,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        onPressed: onFavToggle,
                        icon: Icon(
                          isFavourite ? Icons.favorite : Icons.favorite_border,
                          color: isFavourite ? AppTheme.accent : Colors.black,
                          size: 35,
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            final modelPath = await _findModelPath(product);

                            if (modelPath == null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '3D model not found for ${product.code}',
                                  ),
                                ),
                              );
                              return;
                            }

                            final ok = await ArCoreCheck.ensureAvailable(
                              context,
                            );
                            if (!ok || !context.mounted) return;

                            context.push(
                              '/ar-live',
                              extra: {
                                'title': product.code,
                                'assetGlb': modelPath,
                                'scale': 0.18,
                              },
                            );
                          },

                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.view_in_ar, size: 35),
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
  }
}
