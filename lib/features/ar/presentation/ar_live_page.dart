import 'dart:io';

import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

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
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;

  ARNode? _node;
  ARPlaneAnchor? _anchor;

  @override
  void dispose() {
    _removePlacedNode();
    _arSessionManager?.dispose();
    super.dispose();
  }

  Future<void> _removePlacedNode() async {
    if (_node != null) {
      await _arObjectManager?.removeNode(_node!);
      _node = null;
    }
    if (_anchor != null) {
      await _arAnchorManager?.removeAnchor(_anchor!);
      _anchor = null;
    }
  }

  Future<String> _ensureGlbInAppFolder(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final docs = await getApplicationDocumentsDirectory();
    final fileName = p.basename(assetPath);
    final out = File(p.join(docs.path, fileName));
    if (!await out.exists()) {
      await out.create(recursive: true);
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
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
            onARViewCreated: _onARViewCreated,
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

  Future<void> _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;

    try {
      await _arSessionManager!.onInitialize(
        showFeaturePoints: false,
        showPlanes: true,
        customPlaneTexturePath: null,
        showWorldOrigin: false,
        handleTaps: true,
        handlePans: true,
        handleRotation: true,
      );
      await _arObjectManager!.onInitialize();
    } catch (_) {
      if (!mounted) return;
      await _showArCoreMissingDialog();
      return;
    }

    _arSessionManager!.onPlaneOrPointTap = (hits) async {
      if (hits.isEmpty) return;

      await _removePlacedNode();

      final hit = hits.first;
      _anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final addedAnchor = await _arAnchorManager!.addAnchor(_anchor!);
      if (addedAnchor != true) return;

      final uri = widget.glbUrl ?? widget.assetGlb;
      if (uri == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No 3D model available')));
        return;
      }

      ARNode node;

      if (widget.glbUrl != null) {
        node = ARNode(
          type: NodeType.webGLB,
          uri: widget.glbUrl!,
          scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
          position: vm.Vector3.zero(),
          rotation: vm.Vector4(0, 1, 0, 0),
        );
      } else if (uri.toLowerCase().endsWith('.glb')) {
        final fileName = await _ensureGlbInAppFolder(uri);
        node = ARNode(
          type: NodeType.fileSystemAppFolderGLB,
          uri: fileName,
          scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
          position: vm.Vector3.zero(),
          rotation: vm.Vector4(0, 1, 0, 0),
        );
      } else if (uri.toLowerCase().endsWith('.gltf')) {
        node = ARNode(
          type: NodeType.localGLTF2,
          uri: uri,
          scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
          position: vm.Vector3.zero(),
          rotation: vm.Vector4(0, 1, 0, 0),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unsupported format: $uri')));
        return;
      }

      final ok = await _arObjectManager!.addNode(node, planeAnchor: _anchor);
      if (ok == true && mounted) {
        setState(() => _node = node);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load the model')),
        );
      }
    };
  }

  Future<void> _showArCoreMissingDialog() async {
    final market = Uri.parse('market://details?id=com.google.ar.core');
    final web = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.ar.core',
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Missing AR service'),
        content: const Text(
          'To use augmented reality you must install or update '
          '“Google Play Services for AR”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (!await launchUrl(market)) {
                await launchUrl(web, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open Play Store'),
          ),
        ],
      ),
    );
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
