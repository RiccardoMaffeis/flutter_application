import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'ar_live_page.dart';

/// Cross-platform AR switch page.
/// - Android → uses `ArLivePage` (ar_flutter_plugin + Sceneform/ARCore).
/// - iOS     → shows a minimal ARKit sample view (`arkit_plugin`) with responsive sizing.
/// - Others  → shows a simple "not supported" message.
class ArSwitchPage extends StatelessWidget {
  final String title;
  final String? glbUrl; // Optional: remote GLB for Android AR view.
  final String? assetGlb; // Optional: asset GLB for Android AR view.
  final double scale; // Default model scale (Android path).

  const ArSwitchPage({
    super.key,
    required this.title,
    this.glbUrl,
    this.assetGlb,
    this.scale = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    // ---- Responsive metrics (no absolute magic numbers) ----
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    // Title font sized by width, with bounds also relative to width
    final double titleFont = (w * 0.06).clamp(w * 0.045, w * 0.085) * ts;
    // AppBar height by height, bounded by height
    final double toolbarH = (h * 0.08).clamp(h * 0.07, h * 0.10);
    // Fallback message font by width, bounded by width
    final double fallbackFont = (w * 0.045).clamp(w * 0.035, w * 0.065) * ts;

    if (Platform.isAndroid) {
      // Delegate to the Android AR page (already responsive).
      return ArLivePage(
        title: title,
        glbUrl: glbUrl,
        assetGlb: assetGlb,
        scale: scale,
      );
    }

    if (Platform.isIOS) {
      // iOS path with responsive app bar and a sample ARKit view.
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: toolbarH,
          title: Text(
            title,
            style: TextStyle(fontSize: titleFont, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: const SafeArea(child: _ArKitResponsiveSample()),
      );
    }

    // Fallback for unsupported platforms (web/desktop, etc.)
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarH,
        title: Text(
          title,
          style: TextStyle(fontSize: titleFont, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Text(
            'AR not supported on this platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fallbackFont,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal ARKit sample view with **responsive** cube size & distance:
/// - Cube size is derived from screen diagonal (dp) → meters mapping
/// - Cube distance is a multiple of its size (no fixed meters)
class _ArKitResponsiveSample extends StatefulWidget {
  const _ArKitResponsiveSample();

  @override
  State<_ArKitResponsiveSample> createState() => _ArKitResponsiveSampleState();
}

class _ArKitResponsiveSampleState extends State<_ArKitResponsiveSample> {
  late ARKitController _controller;

  // Computed each build from MediaQuery, used when view is created.
  double? _boxSizeMeters; // Edge size of the cube
  double? _boxDistanceMeters; // Distance in front of camera
  Color? _boxColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ---- Responsive sizing for AR content (approximate mapping) ----
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final diag = math.sqrt(w * w + h * h); // device-diagonal in logical px

    // Map diagonal (logical px) to cube size in meters with only relative terms.
    // Example: phones ~800–1100 diag → ~0.08–0.12m cube.
    final double rawSize = diag / (w + h); // ~0.5–0.7 on phones
    final double cubeSize = (rawSize * 0.16).clamp(
      0.06,
      0.16,
    ); // min/max kept reasonable for AR

    // Distance proportional to cube size (keeps framing similar across devices).
    final double cubeDistance = (cubeSize * 5.0).clamp(
      cubeSize * 3.5,
      cubeSize * 8.0,
    );

    _boxSizeMeters = cubeSize;
    _boxDistanceMeters = cubeDistance;
    _boxColor = Theme.of(context).colorScheme.primary;

    return ARKitSceneView(
      onARKitViewCreated: _onViewCreated,
      planeDetection: ARPlaneDetection.horizontal,
      enableTapRecognizer: true,
    );
  }

  void _onViewCreated(ARKitController controller) {
    _controller = controller;
    _addResponsiveNode();
  }

  Future<void> _addResponsiveNode() async {
    final size = _boxSizeMeters ?? 0.1;
    final dist = _boxDistanceMeters ?? (size * 5.0);
    final color = _boxColor ?? Colors.red;

    final material = ARKitMaterial(diffuse: ARKitMaterialProperty.color(color));

    final box = ARKitBox(
      materials: [material],
      width: size,
      height: size,
      length: size,
      chamferRadius: size * 0.04, // small rounding proportional to size
    );

    // Place the node straight ahead by `dist` meters from the camera.
    final node = ARKitNode(geometry: box, position: vm.Vector3(0, 0, -dist));

    _controller.add(node);
  }
}
