import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'ar_live_page.dart';

/// Cross-platform AR switch page.
/// - Android → uses `ArLivePage` (ar_flutter_plugin + Sceneform/ARCore).
/// - iOS     → uses a minimal ARKit sample view (`arkit_plugin`).
/// - Others  → shows a simple "not supported" message.
///
/// This widget only routes to the appropriate implementation based on platform
/// without altering the AR logic itself.
class ArSwitchPage extends StatelessWidget {
  final String title;
  final String? glbUrl; // Optional: remote GLB when using Android AR view.
  final String? assetGlb; // Optional: asset GLB when using Android AR view.
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
    // ---- Responsive metrics ----
    // Basic responsive sizes reused across app bars and labels.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double titleFont = (w * 0.06).clamp(18.0, 24.0) * ts;
    final double toolbarH = (h * 0.08).clamp(48.0, 64.0);
    final double fallbackFont = (w * 0.045).clamp(14.0, 18.0) * ts;

    // ---- Android path (ARCore via ar_flutter_plugin) ----
    // Delegates to the full-featured AR page that handles plane taps, model
    // placement, rotation, and catalog picker.
    if (Platform.isAndroid) {
      return ArLivePage(
        title: title,
        glbUrl: glbUrl,
        assetGlb: assetGlb,
        scale: scale,
      );
    }

    // ---- iOS path (ARKit via arkit_plugin) ----
    // Shows a minimal ARKit scene with a single red cube example.
    if (Platform.isIOS) {
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
        body: const SafeArea(child: _ArKitSimpleView()),
      );
    }

    // ---- Fallback for unsupported platforms (e.g., web/desktop) ----
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

/// Minimal ARKit sample view:
/// - Creates an ARKit session view
/// - Adds a simple red cube in front of the camera
/// - Enables horizontal plane detection and tap recognizer
class _ArKitSimpleView extends StatefulWidget {
  const _ArKitSimpleView();

  @override
  State<_ArKitSimpleView> createState() => _ArKitSimpleViewState();
}

class _ArKitSimpleViewState extends State<_ArKitSimpleView> {
  late ARKitController arkitController;

  @override
  void dispose() {
    // Always dispose the controller to properly end the AR session.
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ARKitSceneView(
      // Called once the underlying ARKit view is ready.
      onARKitViewCreated: (controller) {
        arkitController = controller;
        _addExampleNode();
      },
      // Detect horizontal planes (e.g., floors/tables).
      planeDetection: ARPlaneDetection.horizontal,
      // Optional: allow tap gestures (not used in this minimal sample).
      enableTapRecognizer: true,
    );
  }

  /// Adds a basic 10cm red cube half a meter in front of the camera.
  /// This demonstrates that the AR session is working.
  Future<void> _addExampleNode() async {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.red),
    );
    final box = ARKitBox(
      materials: [material],
      width: 0.1,
      height: 0.1,
      length: 0.1,
    );

    // Z = -0.5 puts the node 0.5 meters forward in camera space.
    final node = ARKitNode(geometry: box, position: vm.Vector3(0, 0, -0.5));

    arkitController.add(node);
  }
}
