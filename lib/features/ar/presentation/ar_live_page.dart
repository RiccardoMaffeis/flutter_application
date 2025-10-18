// Fullscreen AR placement page using ar_flutter_plugin.
// Adds an overlay HUD (help card, top corner actions) and a tiny toast/snack system.
// You can place ABB XT GLB models on detected horizontal planes, rotate the selected node on X,
// and clear everything. A picker lets you choose the model before tapping on a plane.

import 'dart:async';
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
import 'package:flutter_application/core/theme/app_theme.dart';

import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Simple descriptor of an AR placeable item.
class ARItem {
  final String title;
  final String glbPath;
  final double scale;
  const ARItem(this.title, this.glbPath, this.scale);
}

/// Demo catalog of ABB XT models exposed to the picker dialog.
/// NOTE: These paths must exist in your assets and be properly declared in pubspec.yaml.
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

/// Fullscreen AR scene page
class ArLivePage extends StatefulWidget {
  // Page title.
  final String title;
  // If provided, loads a GLB from the network (NodeType.webGLB).
  final String? glbUrl; // Optional: load GLB from the web
  // If provided, loads a bundled asset GLB (staged into app folder at runtime).
  final String? assetGlb; // Optional: load GLB from bundled assets
  // Default scale when placing the model if not supplied by ARItem.
  final double scale; // Default scale used when placing the model

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
  // AR managers provided by ar_flutter_plugin after view initialization.
  ARSessionManager? _session;
  ARObjectManager? _objectMgr;
  ARAnchorManager? _anchorMgr;

  // True while we are placing a node to prevent re-entrancy on rapid taps.
  bool _placeBusy = false;

  // Bookkeeping for placed nodes and their anchors.
  final List<_Placed> _placed = [];
  // Currently selected node id (from onNodeTap callback).
  String? _selectedId;

  // Slider value for X-axis rotation (degrees) of the selected node.
  double _sliderXDeg = 0;
  // If true, do not clear previously placed models when placing a new one.
  bool _appendMode = false;
  // Pending catalog item to place on next plane tap.
  ARItem? _pendingItem;

  @override
  void dispose() {
    // Important: remove nodes/anchors before session dispose to avoid residuals.
    _removeAll();
    _session?.dispose();
    super.dispose();
  }

  // Remove all nodes and anchors from the scene and reset selection/UI state.
  Future<void> _removeAll() async {
    for (final e in List<_Placed>.from(_placed)) {
      await _objectMgr?.removeNode(e.node);
    }
    for (final e in List<_Placed>.from(_placed)) {
      await _anchorMgr?.removeAnchor(e.anchor);
    }
    _placed.clear();
    _selectedId = null;
    _sliderXDeg = 0;
    setState(() {});
  }

  // Update the X-axis rotation of the selected node (in degrees),
  // falling back to update only the slider UI if nothing is selected.
  void _setSelectedXDeg(double degrees) {
    if (_selectedId == null || _objectMgr == null) {
      setState(() => _sliderXDeg = degrees);
      return;
    }
    final idx = _placed.indexWhere((e) => e.id == _selectedId);
    if (idx == -1) {
      setState(() => _sliderXDeg = degrees);
      return;
    }
    final node = _placed[idx].node;
    final e = node.eulerAngles;
    node.eulerAngles = vm.Vector3(degrees * math.pi / 180.0, e.y, e.z);
    setState(() => _sliderXDeg = degrees);
  }

  // Copy an asset .glb to the app's documents directory so we can load it
  // using NodeType.fileSystemAppFolderGLB (required by ar_flutter_plugin).
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

  // Derive a thumbnail image path from the GLB path (used by the model picker).
  // Assumes 3Dmodels/.../*.glb mirrors images/.../*.png in your assets.
  String _imagePathFor(ARItem item) {
    var path = item.glbPath.replaceFirst('3Dmodels', 'images');
    path = path.replaceFirst(RegExp(r'\.glb$', caseSensitive: false), '');
    final lastSlash = path.lastIndexOf('/');
    final dir = path.substring(0, lastSlash + 1);
    var file = path.substring(lastSlash + 1);
    file = file.replaceAll('3P', '3p').replaceAll('4P', '4p');
    return '$dir$file.png';
  }

  @override
  Widget build(BuildContext context) {
    // Basic responsive metrics for consistent sizing on phones/tablets.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double toolbarH = (h * 0.08).clamp(48.0, 64.0);
    final double titleFont = (w * 0.06).clamp(18.0, 24.0) * ts;

    final double cornerIcon = (w * 0.10).clamp(28.0, 40.0);
    final double cornerPad = (w * 0.032).clamp(8.0, 14.0);
    final double cornerTop = (mq.padding.top * 0.1 + 8).clamp(6.0, 12.0);

    final double sliderBottom = (h * 0.14).clamp(84.0, 120.0);
    final double sliderMinW = (w * 0.45).clamp(180.0, 240.0);
    final double sliderMaxW = (w * 0.70).clamp(220.0, 320.0);
    final double sliderValueFont = (w * 0.035).clamp(12.0, 16.0) * ts;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarH,
        title: Text(
          widget.title,
          style: TextStyle(fontSize: titleFont, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // The actual AR view with horizontal plane detection.
          ARView(
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
            onARViewCreated: _onViewCreated,
          ),

          // Bottom, persistent help card explaining controls.
          const Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _BottomHelpCard(),
          ),

          // Top-left: add model button.
          Positioned(
            left: cornerPad,
            top: cornerTop,
            child: Material(
              type: MaterialType.transparency,
              child: IconButton(
                icon: Icon(Icons.add, size: cornerIcon, color: Colors.white),
                tooltip: 'Add a model',
                onPressed: _onPressAdd,
                splashRadius: (cornerIcon * 0.6).clamp(20.0, 28.0),
              ),
            ),
          ),

          // Top-right: remove all button (disabled when nothing placed).
          Positioned(
            right: cornerPad,
            top: cornerTop,
            child: Material(
              type: MaterialType.transparency,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: cornerIcon,
                  color: _placed.isEmpty
                      ? Colors.white.withOpacity(0.4)
                      : Colors.white,
                ),
                tooltip: 'Remove all models',
                onPressed: _placed.isEmpty
                    ? null
                    : () async {
                        final ok = await _confirmClearAll(context);
                        if (ok == true) {
                          await _removeAll();
                          if (mounted) {
                            showArSnack(
                              context,
                              title: 'All models removed',
                              icon: Icons.delete_outline,
                            );
                          }
                        }
                      },
                splashRadius: (cornerIcon * 0.6).clamp(20.0, 28.0),
              ),
            ),
          ),

          // Bottom-centered rotation slider. It is enabled only when a node is selected.
          Positioned(
            left: 0,
            right: 0,
            bottom: sliderBottom,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: sliderMinW,
                      maxWidth: sliderMaxW,
                    ),
                    child: Opacity(
                      opacity: _selectedId == null ? 0.5 : 1,
                      child: IgnorePointer(
                        ignoring: _selectedId == null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.screen_rotation_alt_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  activeTrackColor: AppTheme.accent,
                                  inactiveTrackColor: Colors.white,
                                  thumbColor: AppTheme.accent,
                                  overlayColor: AppTheme.accent.withOpacity(
                                    0.12,
                                  ),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                  showValueIndicator: ShowValueIndicator.never,
                                ),
                                child: Slider(
                                  value: _sliderXDeg.clamp(-180, 180),
                                  onChanged: (v) => _setSelectedXDeg(v),
                                  min: -180,
                                  max: 180,
                                  divisions: 180,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${_sliderXDeg.toStringAsFixed(0)}°',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: sliderValueFont,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Invisible overlay slot (kept for layout symmetry / future use).
          Positioned.fill(
            child: const _BusyOverlay(visible: false, message: ''),
          ),
          // Busy overlay while placing a model.
          Positioned.fill(
            child: _BusyOverlay(visible: _placeBusy, message: 'Placing…'),
          ),
        ],
      ),
    );
  }

  // Open the picker, then enable append mode and show a snack prompting to tap a plane.
  Future<void> _onPressAdd() async {
    final picked = await _showModelPickerDialog(context);
    if (picked != null) {
      setState(() {
        _pendingItem = picked;
        _appendMode = true;
      });
      showArSnack(
        context,
        title: 'Add mode enabled',
        subtitle: 'Tap a plane to place "${picked.title}"',
        icon: Icons.add,
        color: AppTheme.accent,
      );
    }
  }

  // Simple modal dialog to choose among kXtModels.
  Future<ARItem?> _showModelPickerDialog(BuildContext context) async {
    return showDialog<ARItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final w = mq.size.width;
        final h = mq.size.height;
        final ts = mq.textScaleFactor.clamp(1.0, 1.3);

        final double titleFont = (w * 0.08).clamp(24.0, 40.0) * ts;
        final double listMaxH = (h * 0.55).clamp(240.0, 480.0);
        final double thumb = (w * 0.12).clamp(40.0, 56.0);
        final double itemFont = (w * 0.045).clamp(14.0, 18.0) * ts;
        final double btnH = (h * 0.06).clamp(40.0, 50.0);
        final double btnFont = (w * 0.045).clamp(14.0, 18.0) * ts;

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Text(
                  'Pick a device',
                  style: TextStyle(
                    fontSize: titleFont,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: listMaxH,
                    minHeight: (listMaxH * 0.45).clamp(180.0, 260.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: kXtModels.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final it = kXtModels[i];
                          final tpath = _imagePathFor(it);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                tpath,
                                width: thumb,
                                height: thumb,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.precision_manufacturing),
                              ),
                            ),
                            title: Text(
                              it.title,
                              style: TextStyle(
                                fontSize: itemFont,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop(it),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, btnH),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          side: const BorderSide(color: Color(0x22000000)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: btnFont),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Called once the ARView is created; initialize plugin managers and set handlers.
  Future<void> _onViewCreated(
    ARSessionManager session,
    ARObjectManager objectMgr,
    ARAnchorManager anchorMgr,
    ARLocationManager locationMgr,
  ) async {
    _session = session;
    _objectMgr = objectMgr;
    _anchorMgr = anchorMgr;

    // Session & object manager initialization.
    await _session!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );
    await _objectMgr!.onInitialize();

    // Select node on tap; sync slider to current X rotation.
    _objectMgr!.onNodeTap = (List<String> nodeNames) {
      if (nodeNames.isEmpty) return;
      final id = nodeNames.first;

      final idx = _placed.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final node = _placed[idx].node;
        final xDeg = node.eulerAngles.x * 180.0 / math.pi;
        setState(() {
          _selectedId = id;
          _sliderXDeg = xDeg;
        });
      } else {
        setState(() => _selectedId = id);
      }

      showArSnack(
        context,
        title: 'Model selected',
        subtitle: 'Use the slider to rotate (X axis)',
        icon: Icons.check,
      );
    };

    // Place a node when a plane is tapped; supports append or replace mode.
    _session!.onPlaneOrPointTap = (hits) async {
      if (_placeBusy) return;
      setState(() => _placeBusy = true);
      try {
        // Small delay improves perceived responsiveness and avoids multiple hits.
        await Future.delayed(const Duration(milliseconds: 120));
        if (hits.isEmpty) return;

        if (!_appendMode) {
          await _removeAll();
        }

        final hit = hits.first;
        final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
        final okAnchor = await _anchorMgr!.addAnchor(anchor);
        if (okAnchor != true) return;

        // Rotate model 180° around Y so it faces the user by default.
        final yaw180 = vm.Vector4(0, 1, 0, math.pi);
        final newId = 'mdl_${DateTime.now().microsecondsSinceEpoch}';

        ARNode node;
        if (_pendingItem != null) {
          // Use the chosen catalog item (asset GLB staged into app folder).
          final fileName = await _stageGlbIntoAppFolder(_pendingItem!.glbPath);
          node = ARNode(
            name: newId,
            type: NodeType.fileSystemAppFolderGLB,
            uri: fileName,
            scale: vm.Vector3(
              _pendingItem!.scale,
              _pendingItem!.scale,
              _pendingItem!.scale,
            ),
            position: vm.Vector3.zero(),
            rotation: yaw180,
          );
        } else if (widget.assetGlb != null && widget.assetGlb!.isNotEmpty) {
          // If the page was configured with an asset GLB, use that.
          final fileName = await _stageGlbIntoAppFolder(widget.assetGlb!);
          node = ARNode(
            name: newId,
            type: NodeType.fileSystemAppFolderGLB,
            uri: fileName,
            scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
            position: vm.Vector3.zero(),
            rotation: yaw180,
          );
        } else if (widget.glbUrl != null && widget.glbUrl!.isNotEmpty) {
          // Otherwise, load from web (requires network permissions).
          node = ARNode(
            name: newId,
            type: NodeType.webGLB,
            uri: widget.glbUrl!,
            scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
            position: vm.Vector3.zero(),
            rotation: yaw180,
          );
        } else {
          // No model source provided.
          if (!mounted) return;
          showArSnack(
            context,
            title: 'No 3D model provided',
            centered: true,
            showIcon: false,
          );
          return;
        }

        // Add node to the newly created plane anchor.
        final okNode = await _objectMgr!.addNode(node, planeAnchor: anchor);
        if (okNode == true && mounted) {
          setState(() {
            _placed.add(_Placed(id: newId, anchor: anchor, node: node));
            _appendMode = false;
            _pendingItem = null;
          });
        } else {
          if (!mounted) return;
          showArSnack(
            context,
            title: 'Failed to place the model',
            subtitle: 'Try again or pick another file',
            icon: Icons.error_outline,
            centered: true,
          );
        }
      } finally {
        if (mounted) setState(() => _placeBusy = false);
      }
    };
  }

  // Confirmation dialog before removing all placed nodes.
  Future<bool?> _confirmClearAll(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final w = mq.size.width;
        final h = mq.size.height;
        final ts = mq.textScaleFactor.clamp(1.0, 1.3);

        final double titleFont = (w * 0.08).clamp(26.0, 40.0) * ts;
        final double btnH = (h * 0.06).clamp(40.0, 52.0);
        final double btnFont = (w * 0.048).clamp(15.0, 19.0) * ts;

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Text(
                  'Remove all?',
                  style: TextStyle(
                    fontSize: titleFont,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, btnH),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          side: const BorderSide(color: Color(0x22000000)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: btnFont),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          minimumSize: Size(0, btnH),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: btnFont,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Simple tuple for a placed node with its plane anchor and generated id.
class _Placed {
  final String id;
  final ARPlaneAnchor anchor;
  final ARNode node;
  _Placed({required this.id, required this.anchor, required this.node});
}

// Compact card that explains how to interact with the page (bottom of the screen).
class _BottomHelpCard extends StatelessWidget {
  const _BottomHelpCard();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double icon = (w * 0.06).clamp(18.0, 22.0);
    final double font = (w * 0.035).clamp(11.0, 13.0) * ts;
    final double padH = (w * 0.04).clamp(12.0, 18.0);
    final double padV = (w * 0.025).clamp(8.0, 12.0);

    return SafeArea(
      minimum: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined, size: icon),
              SizedBox(width: (w * 0.03).clamp(8.0, 14.0)),
              Expanded(
                child: Text(
                  'Tap a plane to place the model.\n'
                  'Press “+” (top-left) to pick a device to add.\n'
                  'Tap the trash (top-right) to remove all models.',
                  style: TextStyle(fontSize: font, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Semi-transparent busy overlay with a spinner and message (used while placing).
class _BusyOverlay extends StatelessWidget {
  final bool visible;
  final String message;
  const _BusyOverlay({required this.visible, this.message = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double boxPadH = (w * 0.035).clamp(12.0, 16.0);
    final double boxPadV = (w * 0.028).clamp(8.0, 12.0);
    final double textSize = (w * 0.038).clamp(13.0, 15.0) * ts;
    final double spinner = (w * 0.05).clamp(16.0, 20.0);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: Container(
          color: Colors.black.withOpacity(0.15),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: boxPadH,
                vertical: boxPadV,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
                border: Border.all(color: const Color(0x11000000)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: spinner,
                    height: spinner,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: textSize,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Small circular icon button used by the snack action (if provided).
class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double side = (w * 0.08).clamp(26.0, 32.0);
    final double ic = (w * 0.05).clamp(16.0, 20.0);

    return SizedBox(
      width: side,
      height: side,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: ic),
        ),
      ),
    );
  }
}

/// Smaller, raised & top-aligned snack banner (aligned with the corner icons)
/// This uses an OverlayEntry instead of ScaffoldMessenger to align with the AR HUD.
/// Automatically hides after 2 seconds.
void showArSnack(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.info_outline,
  Color? color, // reserved
  IconData? actionIcon,
  VoidCallback? onAction,
  bool centered = false,
  bool showIcon = true,
}) {
  HapticFeedback.lightImpact();

  final overlay = Overlay.of(context);
  final mq = MediaQuery.of(context);
  final w = mq.size.width;
  final ts = mq.textScaleFactor.clamp(1.0, 1.3);

  // Compute the same top offset used by the corner icons,
  // but measured in the global overlay coordinate space:
  final double cornerTop = (mq.padding.top * 0.1 + 8).clamp(6.0, 12.0);
  final double appBarTop = mq.padding.top + kToolbarHeight;
  final double topY = appBarTop + cornerTop; // aligned with side icons

  // Width/padding & compact sizing
  final double sidePad = (w * 0.18).clamp(24.0, 96.0);
  final double iconSize = (w * 0.048).clamp(16.0, 20.0);
  final double titleFont = (w * 0.034).clamp(12.0, 13.0) * ts;
  final double subFont = (w * 0.030).clamp(11.0, 12.0) * ts;
  final double padH = (w * 0.028).clamp(10.0, 14.0);
  final double padV = (w * 0.020).clamp(6.0, 10.0);
  const double radius = 14.0;

  final entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        top: topY,
        left: sidePad,
        right: sidePad,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
              border: Border.all(color: const Color(0x11000000)),
            ),
            child: centered
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showIcon) ...[
                        Icon(icon, size: iconSize, color: Colors.black87),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: titleFont,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: subFont,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      if (showIcon) ...[
                        Icon(icon, size: iconSize, color: Colors.black87),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: titleFont,
                                color: Colors.black87,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: subFont,
                                  color: Colors.black54,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (actionIcon != null && onAction != null) ...[
                        const SizedBox(width: 6),
                        _TinyIconButton(icon: actionIcon, onTap: onAction),
                      ],
                    ],
                  ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Timer(const Duration(seconds: 2), entry.remove);
}
