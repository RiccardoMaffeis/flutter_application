import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// Simple data holder for an AR-presentable item.
/// - [label]: human readable title
/// - [glbPath]: path to the embedded .glb model inside assets
/// - [scale]: model scale to use in AR scene
class ARItem {
  final String label;
  final String glbPath;
  final double scale;
  const ARItem(this.label, this.glbPath, this.scale);
}

/// Catalog of XT models available for AR placement.
/// Note: paths must exist under your bundled assets for [_assetExists] to pass.
const List<ARItem> kXtModels = [
  ARItem('XT1 3 poli', 'lib/3Dmodels/XT1/XT1_3p.glb', 0.20),
  ARItem('XT1 4 poli', 'lib/3Dmodels/XT1/XT1_4p.glb', 0.20),
  ARItem('XT2 3 poli', 'lib/3Dmodels/XT2/XT2_3p.glb', 0.20),
  ARItem('XT2 4 poli', 'lib/3Dmodels/XT2/XT2_4p.glb', 0.20),
  ARItem('XT3 3 poli', 'lib/3Dmodels/XT3/XT3_3p.glb', 0.20),
  ARItem('XT3 4 poli', 'lib/3Dmodels/XT3/XT3_4p.glb', 0.20),
  ARItem('XT4 3 poli', 'lib/3Dmodels/XT4/XT4_3p.glb', 0.20),
  ARItem('XT5 3 poli', 'lib/3Dmodels/XT5/XT5_3p.glb', 0.20),
  ARItem('XT5 4 poli', 'lib/3Dmodels/XT5/XT5_4p.glb', 0.20),
  ARItem('XT6 4 poli', 'lib/3Dmodels/XT6/XT6_4p.glb', 0.20),
  ARItem('XT7 3 poli', 'lib/3Dmodels/XT7/XT7_3p.glb', 0.20),
  ARItem('XT7 4 poli', 'lib/3Dmodels/XT7/XT7_4p.glb', 0.20),
];

/// Page that lists XT variants and opens the AR scene for the selected item.
class ARXTPage extends StatelessWidget {
  const ARXTPage({super.key});

  /// Checks whether an asset exists in the app bundle.
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Handles back navigation:
  /// - If possible, pop current route
  /// - Otherwise, go back to '/ar' landing
  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/ar');
    }
  }

  /// Converts a GLB path into a companion PNG preview path.
  /// Example: lib/3Dmodels/XT1/XT1_3p.glb -> lib/images/XT1/XT1_3p.png
  String _imagePathFor(ARItem item) {
    var p = item.glbPath.replaceFirst('3Dmodels', 'images');
    p = p.replaceFirst(RegExp(r'\.glb$', caseSensitive: false), '');
    final lastSlash = p.lastIndexOf('/');
    final dir = p.substring(0, lastSlash + 1);
    var file = p.substring(lastSlash + 1);
    file = file.replaceAll('3P', '3p').replaceAll('4P', '4p');
    return '$dir$file.png';
  }

  /// Validates the model asset, shows a SnackBar if missing, otherwise
  /// navigates to the AR live page with the selected model and scale.
  Future<void> _openModel(BuildContext context, ARItem item) async {
    final ok = await _assetExists(item.glbPath);
    if (!ok && context.mounted) {
      final w = MediaQuery.of(context).size.width;
      final ts = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);
      final double snackFont = (w * 0.04).clamp(13.0, 16.0) * ts;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Model not found: ${item.glbPath}',
            style: TextStyle(fontSize: snackFont, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    context.push(
      '/ar-live',
      extra: {
        'title': item.label,
        'assetGlb': item.glbPath,
        'scale': item.scale,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive metrics.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;

    // Header and layout sizing.
    final double searchIconSize = (w * 0.085)
        .clamp(sp(26.0), sp(35.0))
        .toDouble();

    final double titleSize = (w * 0.07).clamp(22.0, 38.0) * ts;
    final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0)).toDouble();
    final EdgeInsets listPad = EdgeInsets.fromLTRB(
      (w * 0.03).clamp(10.0, 16.0),
      (h * 0.01).clamp(6.0, 12.0),
      (w * 0.03).clamp(10.0, 16.0),
      (h * 0.02).clamp(10.0, 20.0),
    );
    final double itemSpacing = (h * 0.012).clamp(8.0, 14.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top spacer to breathe under the status bar.
            SizedBox(height: (h * 0.006).clamp(4.0, 8.0)),

            // Header row: back button, centered title, trailing spacer (to keep title centered).
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sp(12),
                vertical: sp(6),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: searchIconSize,
                    onPressed: () => _handleBack(context),
                  ),

                  // Centered page title.
                  Expanded(
                    child: Center(
                      child: Text(
                        'Augmented Reality',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: titleSize,
                            ),
                      ),
                    ),
                  ),
                  // Spacer with fixed width equals to leading icon size + small gap.
                  SizedBox(width: searchIconSize + 16),
                ],
              ),
            ),

            // Accent bar under the header.
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

            // Scrollable list of XT model choices (cards).
            Expanded(
              child: ListView.separated(
                padding: listPad,
                physics: const BouncingScrollPhysics(),
                itemCount: kXtModels.length,
                separatorBuilder: (_, __) => SizedBox(height: itemSpacing),
                itemBuilder: (context, i) {
                  final item = kXtModels[i];
                  final imgPath = _imagePathFor(item);
                  return _XtButton(
                    label: item.label,
                    imageAsset: imgPath,
                    onTap: () => _openModel(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single list item representing a model.
/// Shows a thumbnail, the label, and a chevron; triggers [onTap] on press.
class _XtButton extends StatelessWidget {
  final String label;
  final String? imageAsset;
  final VoidCallback onTap;
  const _XtButton({required this.label, required this.onTap, this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        // Adapt to the available width for consistent sizing across devices.
        final w = cons.maxWidth;
        final ts = MediaQuery.of(ctx).textScaleFactor.clamp(1.0, 1.3);

        // Tile sizing and typography.
        final double cardRadius = (w * 0.06).clamp(18.0, 28.0);
        final double hPad = (w * 0.036).clamp(12.0, 18.0);
        final double vPad = (w * 0.028).clamp(10.0, 14.0);
        final double thumb = (w * 0.16).clamp(44.0, 68.0);
        final double gap = (w * 0.03).clamp(10.0, 14.0);
        final double labelSize = (w * 0.06).clamp(16.0, 22.0) * ts;
        final double chevron = (w * 0.075).clamp(22.0, 30.0);

        return Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(cardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(cardRadius),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Row(
                children: [
                  // Optional thumbnail preview (falls back to placeholder icon on load error).
                  if (imageAsset != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(cardRadius * 0.6),
                      child: Image.asset(
                        imageAsset!,
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: thumb,
                          height: thumb,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F3),
                            borderRadius: BorderRadius.circular(
                              cardRadius * 0.6,
                            ),
                          ),
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                  ],
                  // Title and chevron.
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: labelSize,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: chevron),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
