import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class AndroidArView extends StatefulWidget {
  final String? glbUrl;
  final String? assetGlb;
  final double scale;

  const AndroidArView({super.key, this.glbUrl, this.assetGlb, this.scale = 0.2});

  @override
  State<AndroidArView> createState() => _AndroidArViewState();
}

class _AndroidArViewState extends State<AndroidArView> {
  ArCoreController? arCoreController;

  @override
  void dispose() {
    arCoreController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArCoreView(
      onArCoreViewCreated: _onArCoreViewCreated,
      enablePlaneRenderer: true,
      enableTapRecognizer: true,
    );
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;

    arCoreController!.onPlaneTap = (List<ArCoreHitTestResult> hits) {
      if (hits.isEmpty) return;
      final hit = hits.first;

      // Carica il modello
      final uri = widget.glbUrl ?? widget.assetGlb;
      if (uri == null) return;

      final node = ArCoreReferenceNode(
        name: "model",
        object3DFileName: uri, // dipende dove è il file — se da asset, potresti dover copiarlo
        scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
        position: vm.Vector3(
          hit.pose.translation.x,
          hit.pose.translation.y,
          hit.pose.translation.z,
        ),
      );

      controller.addArCoreNodeWithAnchor(node);
    };
  }
}
