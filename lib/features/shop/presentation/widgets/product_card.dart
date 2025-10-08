import 'package:flutter/services.dart'; // <-- aggiunto per rootBundle
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application/core/ar/arcore_check.dart'; // <-- aggiunto
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

  // helper come nel ProductDetailsPage
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

            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
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

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
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
                            final modelPath =
                                'lib/3Dmodels/1SDH001295R0008.glb';

                            if (!await _assetExists(modelPath)) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('3D model not found'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            final ok = await ArCoreCheck.ensureAvailable(
                              context,
                            );
                            if (!ok) return;

                            if (!context.mounted) return;
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
