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
/// `title` is for UI, `glbPath` points to a local asset, `scale` is the default 3D scale.
class ARItem {
  final String title;
  final String glbPath;
  final double scale;
  const ARItem(this.title, this.glbPath, this.scale);
}

/// Demo catalog of ABB XT models exposed to the picker dialog.
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

/// Fullscreen AR scene page:
/// - Displays camera feed and AR planes
/// - Lets users place one or more GLB models on tapped planes
/// - Provides a rotation slider for the selected model (X-axis)
class ArLivePage extends StatefulWidget {
  final String title;
  final String? glbUrl; // Optional: load GLB from the web
  final String? assetGlb; // Optional: load GLB from bundled assets
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
  // AR managers provided by ar_flutter_plugin
  ARSessionManager? _session;
  ARObjectManager? _objectMgr;
  ARAnchorManager? _anchorMgr;

  // Current placed models (node + its plane anchor)
  final List<_Placed> _placed = [];
  String? _selectedId; // Name/id of the currently selected node (if any)
  double _sliderXDeg =
      0; // Rotation value bound to the slider (degrees around X)
  bool _appendMode =
      false; // If true, new placements do not clear previous nodes
  ARItem?
  _pendingItem; // The item selected from the picker, to be placed on next tap

  @override
  void dispose() {
    // Clean scene and release session resources on page disposal
    _removeAll();
    _session?.dispose();
    super.dispose();
  }

  /// Removes every placed node and its anchor from the scene and resets UI state.
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

  /// Updates the X-axis rotation for the selected node and syncs the slider value.
  /// If no node is selected, only the slider value is updated.
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

    // Keep Y and Z as-is, replace X with slider value (converted to radians)
    final e = node.eulerAngles;
    final newEuler = vm.Vector3(degrees * math.pi / 180.0, e.y, e.z);
    node.eulerAngles = newEuler;

    setState(() => _sliderXDeg = degrees);
  }

  /// Copies an asset GLB into the application documents directory and returns the file name.
  /// ar_flutter_plugin's NodeType.fileSystemAppFolderGLB expects a file located in the app folder.
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

  /// Derives a thumbnail PNG path from the GLB asset path.
  /// Example: 'lib/3Dmodels/XT2/XT2_4p.glb' -> 'lib/images/XT2/XT2_4p.png'
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          // Camera + AR rendering surface
          ARView(
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
            onARViewCreated: _onViewCreated,
          ),

          // Bottom helper card with quick instructions
          const Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _BottomHelpCard(),
          ),

          // Add button (opens the model picker dialog)
          Positioned(
            left: 12,
            top: 8,
            child: Material(
              type: MaterialType.transparency,
              child: IconButton(
                icon: const Icon(Icons.add, size: 40, color: Colors.white),
                tooltip: 'Add a model',
                onPressed: _onPressAdd,
                splashRadius: 24,
              ),
            ),
          ),

          // Delete-all button (clears anchors + nodes, with confirmation)
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              type: MaterialType.transparency,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 40,
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
                splashRadius: 24,
              ),
            ),
          ),

          // Rotation slider (X-axis) shown centered above the bottom card;
          // enabled only when a node is selected.
          Positioned(
            left: 0,
            right: 0,
            bottom: 92,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 180,
                      maxWidth: 260,
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
                              size: 16,
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
                              width: 40,
                              child: Text(
                                '${_sliderXDeg.toStringAsFixed(0)}°',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 14,
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
        ],
      ),
    );
  }

  /// Opens a modal dialog to pick a model to add.
  /// When confirmed, enables "append mode": next plane tap will place the chosen item.
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

  /// Dialog showing the list of available models with thumbnails.
  /// Returns the chosen `ARItem` or null if cancelled.
  Future<ARItem?> _showModelPickerDialog(BuildContext context) async {
    return showDialog<ARItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Pick a device',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 420,
                  minHeight: 200,
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
                        final thumb = _imagePathFor(it);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              thumb,
                              width: 44,
                              height: 44,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.precision_manufacturing),
                            ),
                          ),
                          title: Text(
                            it.title,
                            style: const TextStyle(
                              fontSize: 16,
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
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: const BorderSide(color: Color(0x22000000)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Called when the ARView is ready. Initializes AR managers and sets callbacks:
  /// - `onNodeTap` selects a model
  /// - `onPlaneOrPointTap` places a model (pending or default)
  Future<void> _onViewCreated(
    ARSessionManager session,
    ARObjectManager objectMgr,
    ARAnchorManager anchorMgr,
    ARLocationManager locationMgr,
  ) async {
    _session = session;
    _objectMgr = objectMgr;
    _anchorMgr = anchorMgr;

    // Configure AR session visualization and gesture handling.
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

    // When a node is tapped, remember it as "selected" and sync the slider to its X rotation.
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

    // When a plane/point is tapped, create an anchor and add the selected or default GLB node.
    _session!.onPlaneOrPointTap = (hits) async {
      if (hits.isEmpty) return;

      // Unless in append mode, clear existing nodes to keep a single model in the scene.
      if (!_appendMode) {
        await _removeAll();
      }

      final hit = hits.first;
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final okAnchor = await _anchorMgr!.addAnchor(anchor);
      if (okAnchor != true) return;

      // Rotate 180° around Y so front faces the camera by default.
      final yaw180 = vm.Vector4(0, 1, 0, math.pi);
      final newId = 'mdl_${DateTime.now().microsecondsSinceEpoch}';

      ARNode node;
      if (_pendingItem != null) {
        // A catalog item was picked -> stage from assets to app folder and load.
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
        // A direct asset path was provided by the route -> stage and load.
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
        // A web URL was provided by the route -> load over network.
        node = ARNode(
          name: newId,
          type: NodeType.webGLB,
          uri: widget.glbUrl!,
          scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
          position: vm.Vector3.zero(),
          rotation: yaw180,
        );
      } else {
        // Nothing to load -> inform the user.
        if (!mounted) return;
        showArSnack(
          context,
          title: 'No 3D model provided',
          centered: true,
          showIcon: false,
        );
        return;
      }

      // Add the node attached to the newly created plane anchor.
      final okNode = await _objectMgr!.addNode(node, planeAnchor: anchor);
      if (okNode == true && mounted) {
        setState(() {
          _placed.add(_Placed(id: newId, anchor: anchor, node: node));
          _appendMode = false; // Exit append mode after first placement
          _pendingItem = null; // Clear pending item
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
    };
  }

  /// Ask the user to confirm removal of all nodes/anchors.
  Future<bool?> _confirmClearAll(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Remove all?',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: const BorderSide(color: Color(0x22000000)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small holder for a placed model and its anchor.
/// `id` corresponds to the node name used by ar_flutter_plugin.
class _Placed {
  final String id;
  final ARPlaneAnchor anchor;
  final ARNode node;

  _Placed({required this.id, required this.anchor, required this.node});
}

/// Bottom helper card with brief usage instructions.
class _BottomHelpCard extends StatelessWidget {
  const _BottomHelpCard();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(left: 0, right: 0, bottom: 0),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
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
                  'Tap a plane to place the model.\n'
                  'Press “+” (top-left) to pick a device to add.\n'
                  'Tap the trash (top-right) to remove all models.',
                  style: TextStyle(fontSize: 12, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon button used inside the custom snackbar.
class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      iconSize: 16,
      splashRadius: 18,
      icon: Icon(icon),
    );
  }
}

/// Lightweight, custom overlay "snack" banner:
/// - Uses `OverlayEntry` so it doesn't depend on ScaffoldMessenger
/// - Vibrates lightly (haptic) on show
/// - Auto-dismisses after 2 seconds
/// - Supports optional action icon/callback and centered layout
void showArSnack(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.info_outline,
  Color? color, // (Unused in current container but kept for future styling)
  IconData? actionIcon,
  VoidCallback? onAction,
  bool centered = false, // When true, layout is column-centered
  bool showIcon = true, // Hide icon for ultra-minimal messages
}) {
  HapticFeedback.lightImpact();

  // Get the overlay layer (assumes presence of an Overlay in the tree).
  final overlay = Overlay.of(context);

  // Position the banner below the AppBar.
  final topY = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

  final entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        top: topY,
        left: 64, // Side padding for a centered-ish banner
        right: 64,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
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
                        Icon(icon, size: 22, color: Colors.black87),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
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
                          style: const TextStyle(
                            fontSize: 12,
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
                        Icon(icon, size: 22, color: Colors.black87),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
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

  // Insert and schedule auto-removal after a short delay.
  overlay.insert(entry);
  Timer(const Duration(seconds: 2), entry.remove);
}
