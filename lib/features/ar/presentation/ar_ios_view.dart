import 'dart:io';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math_64.dart';

class IosArView extends StatefulWidget {
  final String? glbUrl;
  final String? assetGlb;
  final double scale;

  const IosArView({super.key, this.glbUrl, this.assetGlb, this.scale = 0.2});

  @override
  State<IosArView> createState() => _IosArViewState();
}

class _IosArViewState extends State<IosArView> {
  ARKitController? arkitController;
  String? localFilePath;

  @override
  void initState() {
    super.initState();
    if (widget.assetGlb != null) {
      _copyAssetToFile(widget.assetGlb!);
    } else if (widget.glbUrl != null) {
    }
  }

  Future<void> _copyAssetToFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${assetPath.split('/').last}');

    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    setState(() {
      localFilePath = file.path;
    });
  }

  @override
  void dispose() {
    arkitController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (localFilePath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ARKitSceneView(
      onARKitViewCreated: _onARKitViewCreated,
      planeDetection: ARPlaneDetection.horizontal,
    );
  }

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;

    final node = ARKitReferenceNode(
      url: localFilePath!,
      scale: Vector3.all(widget.scale),
      position: Vector3.zero(),
    );

    arkitController!.add(node);
  }
}
