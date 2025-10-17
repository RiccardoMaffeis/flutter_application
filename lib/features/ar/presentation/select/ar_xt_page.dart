import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Simple value object describing an AR item (UI label + GLB asset path + scale).
class ARItem {
  final String label;
  final String glbPath;
  final double scale;
  const ARItem(this.label, this.glbPath, this.scale);
}

/// Catalog of selectable XT models for AR.
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

/// Page that lets the user pick one of the available AR models.
class ARXTPage extends StatelessWidget {
  const ARXTPage({super.key});

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/ar');
    }
  }

  String _imagePathFor(ARItem item) {
    var p = item.glbPath.replaceFirst('3Dmodels', 'images');
    p = p.replaceFirst(RegExp(r'\.glb$', caseSensitive: false), '');
    final lastSlash = p.lastIndexOf('/');
    final dir = p.substring(0, lastSlash + 1);
    var file = p.substring(lastSlash + 1);
    file = file.replaceAll('3P', '3p').replaceAll('4P', '4p');
    return '$dir$file.png';
  }

  Future<void> _openModel(BuildContext context, ARItem item) async {
    final ok = await _assetExists(item.glbPath);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modello non trovato: ${item.glbPath}')),
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
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;

    // Header sizing
    final double iconSize = (w * 0.075).clamp(24.0, 36.0);
    final double titleSize = (w * 0.075).clamp(22.0, 38.0);
    final double headerHPad = (w * 0.016).clamp(6.0, 12.0);
    final double headerVPad = (h * 0.01).clamp(6.0, 10.0);
    final double accentHMargin = (w * 0.04).clamp(12.0, 20.0);
    final double accentHeight = (h * 0.005).clamp(3.0, 6.0);

    // List spacing
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
            SizedBox(height: (h * 0.006).clamp(4.0, 8.0)),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                headerHPad,
                headerVPad,
                headerHPad,
                headerVPad,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: iconSize,
                    onPressed: () => _handleBack(context),
                  ),
                  Expanded(
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
                  // Spacer with same width of leading icon for perfect centering
                  SizedBox(width: iconSize + headerHPad * 2),
                ],
              ),
            ),
            // Accent bar
            Container(
              height: accentHeight,
              margin: EdgeInsets.symmetric(horizontal: accentHMargin),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: (h * 0.01).clamp(6.0, 12.0)),

            // List
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

/// Reusable button for a single XT model.
class _XtButton extends StatelessWidget {
  final String label;
  final String? imageAsset;
  final VoidCallback onTap;
  const _XtButton({required this.label, required this.onTap, this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth;

        final double cardRadius = (w * 0.06).clamp(18.0, 28.0);
        final double hPad = (w * 0.036).clamp(12.0, 18.0);
        final double vPad = (w * 0.028).clamp(10.0, 14.0);
        final double thumb = (w * 0.16).clamp(44.0, 68.0);
        final double gap = (w * 0.03).clamp(10.0, 14.0);
        final double labelSize = (w * 0.06).clamp(16.0, 22.0);
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
