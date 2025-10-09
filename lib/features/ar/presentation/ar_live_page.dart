import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';

import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ArLivePage extends StatefulWidget {
  final String title;
  final String? glbUrl;
  final String? assetGlb;
  final double scale;

  const ArLivePage({
    super.key,
    required this.title,
    this.glbUrl,
    this.assetGlb,
    this.scale = 0.2,
  });

  @override
  State<ArLivePage> createState() => _ArLivePageState();
}

class _ArLivePageState extends State<ArLivePage> {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;

  ARPlaneAnchor? _anchor;
  ARNode? _node;

  @override
  void dispose() {
    _removeAll();
    _session?.dispose();
    super.dispose();
  }

  Future<void> _removeAll() async {
    if (_node != null) {
      await _objects?.removeNode(_node!);
      _node = null;
    }
    if (_anchor != null) {
      await _anchors?.removeAnchor(_anchor!);
      _anchor = null;
    }
  }

  Future<String> _stageGlbIntoAppFolder(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final docs = await getApplicationDocumentsDirectory();
    final fileName = p.basename(assetPath);
    final outFile = File(p.join(docs.path, fileName));

    if (!await outFile.exists()) {
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(bytes, flush: true);
    }
    return fileName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          ARView(
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
            onARViewCreated: _onViewCreated,
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _BottomHelpCard(),
          ),
        ],
      ),
    );
  }

  Future<void> _onViewCreated(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    ARLocationManager location,
  ) async {
    _session = session;
    _objects = objects;
    _anchors = anchors;

    await _session!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );
    await _objects!.onInitialize();

    _session!.onPlaneOrPointTap = (hits) async {
      if (hits.isEmpty) return;

      await _removeAll();

      final hit = hits.first;
      _anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final okAnchor = await _anchors!.addAnchor(_anchor!);
      if (okAnchor != true) return;

      final yaw180 = vm.Vector4(0, 1, 0, math.pi);

      ARNode node;
      if (widget.glbUrl != null && widget.glbUrl!.isNotEmpty) {
        node = ARNode(
          type: NodeType.webGLB,
          uri: widget.glbUrl!,
          scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
          position: vm.Vector3.zero(),
          rotation: yaw180,
        );
      } else if (widget.assetGlb != null && widget.assetGlb!.isNotEmpty) {
        final fileName = await _stageGlbIntoAppFolder(widget.assetGlb!);
        node = ARNode(
          type: NodeType.fileSystemAppFolderGLB,
          uri: fileName,
          scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
          position: vm.Vector3.zero(),
          rotation: yaw180,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No 3D model provided')));
        return;
      }

      final okNode = await _objects!.addNode(node, planeAnchor: _anchor);
      if (okNode == true && mounted) {
        setState(() => _node = node);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to place the model')),
        );
      }
    };
  }
}

class _BottomHelpCard extends StatelessWidget {
  const _BottomHelpCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      child: Card(
        color: theme.colorScheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap a plane to place the model. Pinch to zoom, rotate with two fingers.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
