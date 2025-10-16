import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'ar_live_page.dart';

class ArSwitchPage extends StatelessWidget {
  final String title;
  final String? glbUrl;
  final String? assetGlb;
  final double scale;

  const ArSwitchPage({
    super.key,
    required this.title,
    this.glbUrl,
    this.assetGlb,
    this.scale = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return ArLivePage(
        title: title,
        glbUrl: glbUrl,
        assetGlb: assetGlb,
        scale: scale,
      );
    }

    if (Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const _ArKitSimpleView(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('AR not supported on this platform')),
    );
  }
}

class _ArKitSimpleView extends StatefulWidget {
  const _ArKitSimpleView();

  @override
  State<_ArKitSimpleView> createState() => _ArKitSimpleViewState();
}

class _ArKitSimpleViewState extends State<_ArKitSimpleView> {
  late ARKitController arkitController;

  @override
  void dispose() {
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ARKitSceneView(
      onARKitViewCreated: (controller) {
        arkitController = controller;
        _addExampleNode();
      },
      planeDetection: ARPlaneDetection.horizontal,
      enableTapRecognizer: true,
    );
  }

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

    final node = ARKitNode(
      geometry: box,
      position: vm.Vector3(0, 0, -0.5),
    );

    arkitController.add(node);
  }
}
