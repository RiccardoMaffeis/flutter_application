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
import 'package:vector_math/vector_math_64.dart' as vm;

class ArLivePage extends StatefulWidget {
  final String title;
  final String? glbUrl; // URL di un .glb (Android/iOS)
  final String? assetGlb; // path asset (es. 'assets/models/xt1.glb')
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
    _arSessionManager?.dispose();
    super.dispose();
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
          Positioned(left: 16, right: 16, bottom: 20, child: _BottomHelpCard()),
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

    // Tap su piano => ancora + modello
    _arSessionManager!.onPlaneOrPointTap = (hits) async {
      if (hits.isEmpty) return;
      final hit = hits.first;

      // crea anchor dove hai toccato
      _anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final added = await _arAnchorManager!.addAnchor(_anchor!);
      if (added != true) return;

      // crea il nodo (modello .glb)
      final node = ARNode(
        type: widget.glbUrl != null ? NodeType.webGLB : NodeType.localGLTF2,
        uri: widget.glbUrl ?? widget.assetGlb!,
        scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
        position: vm.Vector3.zero(),
        rotation: vm.Vector4(1, 0, 0, 0), // no rotazione iniziale
      );

      final didAddNode = await _arObjectManager!.addNode(
        node,
        planeAnchor: _anchor,
      );
      if (didAddNode == true) {
        // se esisteva già un nodo, rimuovilo
        if (_node != null) {
          await _arObjectManager!.removeNode(_node!);
        }
        _node = node;
        setState(() {});
      }
    };
  }
}

class _BottomHelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: const [
            Icon(Icons.touch_app_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tocca un piano per posizionare il modello. Pizzica per zoom, ruota con due dita.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
