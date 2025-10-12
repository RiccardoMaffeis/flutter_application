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
/// Each entry points to a local .glb asset and a default scale factor.
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
/// It shows a header and a scrollable list of buttons with thumbnails.
class ARSelectPage extends StatelessWidget {
  const ARSelectPage({super.key});

  /// Returns true if the given asset path exists and can be loaded.
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Handles the back action:
  /// - If there's a previous route, pop it.
  /// - Otherwise, go back to '/ar'.
  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/ar');
    }
  }

  /// Converts a GLB asset path into a PNG image preview path:
  /// - Replaces the '3Dmodels' root with 'images'
  /// - Drops the '.glb' extension
  /// - Normalizes '3P'/'4P' into lowercase
  /// - Appends '.png'
  ///
  /// Example:
  /// 'lib/3Dmodels/XT2/XT2_4p.glb' -> 'lib/images/XT2/XT2_4p.png'
  String _imagePathFor(ARItem item) {
    var p = item.glbPath.replaceFirst('3Dmodels', 'images');
    p = p.replaceFirst(RegExp(r'\.glb$', caseSensitive: false), '');
    final lastSlash = p.lastIndexOf('/');
    final dir = p.substring(0, lastSlash + 1);
    var file = p.substring(lastSlash + 1);
    file = file.replaceAll('3P', '3p').replaceAll('4P', '4p');
    return '$dir$file.png';
  }

  /// Validates the presence of the GLB asset and, if found, navigates
  /// to the AR live view passing title, asset path and scale via `extra`.
  Future<void> _openModel(BuildContext context, ARItem item) async {
    final ok = await _assetExists(item.glbPath);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modello non trovato: ${item.glbPath}')),
      );
      return;
    }
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
    return Scaffold(
      backgroundColor: const Color(
        0xFFF2F2F7,
      ), // Subtle iOS-like gray background
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            // Header with back button, centered title, and invisible trailing icon for symmetry
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: 28,
                    onPressed: () => _handleBack(context),
                  ),
                  Expanded(
                    child: Text(
                      'Augmented Reality',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, fontSize: 31),
                    ),
                  ),
                  // Placeholder to keep the title centered visually
                  Opacity(
                    opacity: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ),
            // Thin accent bar under the header
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),

            // Scrollable list of model buttons with separators
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: kXtModels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
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

/// Reusable button widget for a single XT model:
/// - Optional left thumbnail (from local assets)
/// - Bold label
/// - Chevron on the right
class _XtButton extends StatelessWidget {
  final String label;
  final String? imageAsset;
  final VoidCallback onTap;
  const _XtButton({required this.label, required this.onTap, this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2, // Subtle elevation for card-like appearance
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Optional preview image; shows a neutral placeholder on error
              if (imageAsset != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    imageAsset!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Main label
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Trailing chevron to indicate navigation
              const Icon(Icons.chevron_right, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
