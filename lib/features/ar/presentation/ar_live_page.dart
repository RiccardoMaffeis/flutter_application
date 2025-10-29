import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';

import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_application/core/tour/coach_tour.dart';

/// Lightweight descriptor for an AR model entry shown in pickers/lists.
class ARItem {
  final String title;
  final String glbPath;
  final double scale;
  const ARItem(this.title, this.glbPath, this.scale);
}

/// Static catalog of XT models available for placement in AR.
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

/// Live AR page:
/// - Detects planes
/// - Lets the user place GLB models
/// - Allows rotating the selected model along X with a bottom slider
/// - Uses ShowcaseView for an onboarding tour of key controls
class ArLivePage extends ConsumerStatefulWidget {
  final String title;
  final String? glbUrl; // Optional remote GLB to load
  final String? assetGlb; // Optional bundled GLB asset to load
  final double scale; // Default scale for the model when added

  const ArLivePage({
    super.key,
    required this.title,
    this.glbUrl,
    this.assetGlb,
    this.scale = 0.2,
  });

  @override
  ConsumerState<ArLivePage> createState() => _ArLivePageState();
}

class _ArLivePageState extends ConsumerState<ArLivePage> {
  // ARCore/ARKit managers provided by ar_flutter_plugin.
  ARSessionManager? _session;
  ARObjectManager? _objectMgr;
  ARAnchorManager? _anchorMgr;

  // Guard to prevent multiple placements while an operation is in flight.
  bool _placeBusy = false;

  // List of placed nodes + their anchors, and current selection id.
  final List<_Placed> _placed = [];
  String? _selectedId;

  // Current rotation (X axis) of selected model, in degrees.
  double _sliderXDeg = 0;

  // When true, new placement appends instead of replacing existing ones.
  bool _appendMode = false;

  // If user pre-picked a catalog item, it is stored here before placement.
  ARItem? _pendingItem;

  // Showcase keys for the page tour: back, add, delete, rotate controls.
  final _kBack = GlobalKey();
  final _kAdd = GlobalKey();
  final _kDelete = GlobalKey();
  final _kRotate = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Schedule the AR page tour; CoachTourService ensures the section
    // is shown only once per device unless reset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(coachTourServiceProvider).startOrQueue(
        context,
        TourSection.arLive,
        [_kBack, _kAdd, _kDelete, _kRotate],
      );
    });
  }

  @override
  void dispose() {
    // Clean up all placed nodes/anchors and AR session on dispose.
    _removeAll();
    _session?.dispose();
    super.dispose();
  }

  /// Removes all nodes and anchors from the scene and clears local state.
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
    if (mounted) setState(() {});
  }

  /// Updates the X-axis rotation of the selected node (in degrees).
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

  /// Copies a bundled GLB asset into the app's documents directory
  /// so it can be loaded by ar_flutter_plugin using fileSystemAppFolder path.
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

  /// Gets a preview image path that mirrors a given GLB path.
  /// Example: lib/3Dmodels/.../XT1_3p.glb -> lib/images/.../XT1_3p.png
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
    // Responsive metrics helpers (scale based on the shortest side).
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final shortest = math.min(size.width, size.height);
    double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    // AppBar sizing.
    final double toolbarH = sp(58);
    final double titleFont = sp(19) * ts;

    // Corner icon placement (for add/trash overlay buttons).
    final double cornerIcon = sp(32);
    final double cornerPad = sp(10);
    final double cornerTop = (mq.padding.top * 0.12 + sp(6)).clamp(
      sp(6),
      sp(14),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarH,
        leading: Showcase(
          key: _kBack,
          description: 'Go back to the previous screen.',
          overlayOpacity: 0.2,
          targetPadding: const EdgeInsets.all(2),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(fontSize: titleFont, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          // Manual trigger to replay the page tour.
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Show page tour',
            onPressed: () {
              ref.read(coachTourServiceProvider).startNow(context, [
                _kBack,
                _kAdd,
                _kDelete,
                _kRotate,
              ]);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main AR view with horizontal plane detection and interaction.
          ARView(
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
            onARViewCreated: _onViewCreated,
          ),

          // Floating "+" button (top-left) to choose a model to place.
          Positioned(
            left: cornerPad,
            top: cornerTop,
            child: Showcase(
              key: _kAdd,
              description: 'Pick a device to add, then tap a detected plane.',
              overlayOpacity: 0.2,
              targetPadding: const EdgeInsets.all(4),
              child: Material(
                type: MaterialType.transparency,
                child: IconButton(
                  icon: Icon(Icons.add, size: cornerIcon, color: Colors.white),
                  tooltip: 'Add a model',
                  onPressed: _onPressAdd,
                  splashRadius: (cornerIcon * 0.6).clamp(sp(18), sp(28)),
                ),
              ),
            ),
          ),

          // Floating "trash" button (top-right) to clear all placed models.
          Positioned(
            right: cornerPad,
            top: cornerTop,
            child: Showcase(
              key: _kDelete,
              description: 'Remove all placed models from the scene.',
              overlayOpacity: 0.2,
              targetPadding: const EdgeInsets.all(4),
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
                  splashRadius: (cornerIcon * 0.6).clamp(sp(18), sp(28)),
                ),
              ),
            ),
          ),

          // Bottom controls: rotation slider (X axis) with a Showcase bubble.
          Positioned(
            left: sp(12),
            right: sp(12),
            bottom: sp(18),
            child: SafeArea(
              minimum: EdgeInsets.only(bottom: sp(4)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Showcase(
                      key: _kRotate,
                      description:
                          'Rotate the selected model with this bar.\n'
                          'First, tap a model to select it.',
                      overlayOpacity: 0.2,
                      targetPadding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(sp(18)),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: sp(10),
                            vertical: sp(6),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: (size.width * 0.45).clamp(
                                sp(170),
                                sp(260),
                              ),
                              maxWidth: (size.width * 0.72).clamp(
                                sp(220),
                                sp(360),
                              ),
                            ),
                            child: Opacity(
                              opacity: _selectedId == null ? 0.5 : 1,
                              child: IgnorePointer(
                                ignoring: _selectedId == null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.screen_rotation_alt_outlined,
                                      size: sp(18),
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: sp(6)),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: sp(4),
                                          activeTrackColor: AppTheme.accent,
                                          inactiveTrackColor: Colors.white,
                                          thumbColor: AppTheme.accent,
                                          overlayColor: AppTheme.accent
                                              .withOpacity(0.12),
                                          thumbShape: RoundSliderThumbShape(
                                            enabledThumbRadius: sp(9),
                                          ),
                                          overlayShape: RoundSliderOverlayShape(
                                            overlayRadius: sp(15),
                                          ),
                                          showValueIndicator:
                                              ShowValueIndicator.never,
                                        ),
                                        child: Slider(
                                          value: _sliderXDeg.clamp(-180, 180),
                                          onChanged: (v) => _setSelectedXDeg(v),
                                          min: -180,
                                          max: 180,
                                          divisions: math.max(
                                            60,
                                            (180 * (shortest / 375)).round(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: sp(6)),
                                    SizedBox(
                                      width: sp(48),
                                      child: Text(
                                        '${_sliderXDeg.toStringAsFixed(0)}°',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize:
                                              (sp(13) *
                                              mq.textScaleFactor.clamp(
                                                1.0,
                                                1.3,
                                              )),
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

                  SizedBox(height: sp(12)),

                  // Static bottom help card with quick tips.
                  const _BottomHelpCard(),
                ],
              ),
            ),
          ),

          // Busy overlay for placement flow (shows a spinner and a message).
          Positioned.fill(
            child: const _BusyOverlay(visible: false, message: ''),
          ),
          Positioned.fill(
            child: _BusyOverlay(visible: _placeBusy, message: 'Placing…'),
          ),
        ],
      ),
    );
  }

  /// Opens the picker dialog; if user selects an item,
  /// switches to append mode and shows a toast with instructions.
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

  /// Simple modal that lists available models (with thumbnail) to pick from.
  Future<ARItem?> _showModelPickerDialog(BuildContext context) async {
    return showDialog<ARItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final size = mq.size;
        final shortest = math.min(size.width, size.height);
        double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
        final ts = mq.textScaleFactor.clamp(1.0, 1.3);

        final double titleFont = sp(28) * ts;
        final double listMaxH = (size.height * 0.55).clamp(sp(240), sp(520));
        final double thumb = sp(52);
        final double itemFont = sp(16) * ts;
        final double btnH = sp(46);
        final double btnFont = sp(16) * ts;
        final double dlgRadius = sp(18);
        final double listRadius = sp(12);
        final EdgeInsets pad = EdgeInsets.fromLTRB(
          sp(20),
          sp(18),
          sp(20),
          sp(18),
        );
        final EdgeInsets tilePad = EdgeInsets.symmetric(
          horizontal: sp(8),
          vertical: sp(6),
        );

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dlgRadius),
          ),
          child: Padding(
            padding: pad,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: sp(6)),
                Text(
                  'Pick a device',
                  style: TextStyle(
                    fontSize: titleFont,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: sp(12)),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: listMaxH,
                    minHeight: (listMaxH * 0.45).clamp(sp(180), sp(260)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(listRadius),
                    child: Material(
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: kXtModels.length,
                        separatorBuilder: (_, __) => Divider(height: sp(1)),
                        itemBuilder: (_, i) {
                          final it = kXtModels[i];
                          final tpath = _imagePathFor(it);
                          return ListTile(
                            contentPadding: tilePad,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(sp(8)),
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
                SizedBox(height: sp(12)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, btnH),
                          padding: EdgeInsets.symmetric(vertical: sp(10)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(sp(18)),
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

  /// Configures AR managers and wires up tap gestures:
  /// - onNodeTap: selects a model and syncs the rotation slider
  /// - onPlaneOrPointTap: places a new model at the first hit pose
  Future<void> _onViewCreated(
    ARSessionManager session,
    ARObjectManager objectMgr,
    ARAnchorManager anchorMgr,
    ARLocationManager locationMgr,
  ) async {
    _session = session;
    _objectMgr = objectMgr;
    _anchorMgr = anchorMgr;

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

    // Select node on tap and update the slider to reflect current X rotation.
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

    // Place node on plane tap. Handles append/replace and GLB source selection.
    _session!.onPlaneOrPointTap = (hits) async {
      if (_placeBusy) return;
      setState(() => _placeBusy = true);
      try {
        await Future.delayed(const Duration(milliseconds: 120));
        if (hits.isEmpty) return;

        if (!_appendMode) {
          await _removeAll();
        }

        final hit = hits.first;
        final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
        final okAnchor = await _anchorMgr!.addAnchor(anchor);
        if (okAnchor != true) return;

        final yaw180 = vm.Vector4(0, 1, 0, math.pi); // Face the camera
        final newId = 'mdl_${DateTime.now().microsecondsSinceEpoch}';

        ARNode node;
        if (_pendingItem != null) {
          // Use the catalog item selected in the picker.
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
          // Use the GLB provided by widget as bundled asset.
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
          // Use a remote GLB.
          node = ARNode(
            name: newId,
            type: NodeType.webGLB,
            uri: widget.glbUrl!,
            scale: vm.Vector3(widget.scale, widget.scale, widget.scale),
            position: vm.Vector3.zero(),
            rotation: yaw180,
          );
        } else {
          // No model source available.
          if (!mounted) return;
          showArSnack(
            context,
            title: 'No 3D model provided',
            centered: true,
            showIcon: false,
          );
          return;
        }

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

  /// Confirmation dialog before removing all nodes from the scene.
  Future<bool?> _confirmClearAll(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final size = mq.size;
        final shortest = math.min(size.width, size.height);
        double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
        final ts = mq.textScaleFactor.clamp(1.0, 1.3);

        final double titleFont = sp(28) * ts;
        final double btnH = sp(48);
        final double btnFont = sp(17) * ts;
        final double dlgRadius = sp(18);
        final EdgeInsets pad = EdgeInsets.fromLTRB(
          sp(20),
          sp(18),
          sp(20),
          sp(18),
        );

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dlgRadius),
          ),
          child: Padding(
            padding: pad,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: sp(6)),
                Text(
                  'Remove all?',
                  style: TextStyle(
                    fontSize: titleFont,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: sp(16)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, btnH),
                          padding: EdgeInsets.symmetric(vertical: sp(10)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(sp(18)),
                          ),
                          side: const BorderSide(color: Color(0x22000000)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: btnFont),
                        ),
                      ),
                    ),
                    SizedBox(width: sp(8)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          minimumSize: Size(0, btnH),
                          padding: EdgeInsets.symmetric(vertical: sp(10)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(sp(18)),
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

/// Small container to bind a node to its anchor with a unique id.
class _Placed {
  final String id;
  final ARPlaneAnchor anchor;
  final ARNode node;
  _Placed({required this.id, required this.anchor, required this.node});
}

/// Bottom helper card with quick instructions for AR interactions.
class _BottomHelpCard extends StatelessWidget {
  const _BottomHelpCard();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final shortest = math.min(size.width, size.height);
    double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
    final scaler = MediaQuery.textScalerOf(context);

    final double icon = sp(20);
    final double font = scaler.scale(sp(13));
    final double padH = sp(14);
    final double padV = sp(10);
    final double gap = sp(10);
    final double radius = sp(14);

    return SafeArea(
      minimum: EdgeInsets.zero,
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: sp(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined, size: icon),
              SizedBox(width: gap),
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

/// Full-screen busy overlay used while placing models or doing heavy AR work.
class _BusyOverlay extends StatelessWidget {
  final bool visible;
  final String message;
  const _BusyOverlay({required this.visible, this.message = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final shortest = math.min(size.width, size.height);
    double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double boxPadH = sp(14);
    final double boxPadV = sp(10);
    final double textSize = sp(14) * ts;
    final double spinner = sp(18);
    final double radius = sp(12);
    final double blur = sp(16);
    final double offsetY = sp(8);
    final double gap = sp(10);
    final double stroke = (spinner / 10).clamp(1.5, 2.5);

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
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x22000000),
                    blurRadius: blur,
                    offset: Offset(0, offsetY),
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
                    child: CircularProgressIndicator(strokeWidth: stroke),
                  ),
                  SizedBox(width: gap),
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

/// Small circular icon button used inside the snackbar action area.
class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final shortest = math.min(w, MediaQuery.of(context).size.height);
    double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);

    final double side = sp(30);
    final double ic = sp(18);

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

/// Lightweight top-of-screen toast/snackbar with subtle elevation.
/// Uses an OverlayEntry and auto-dismisses after a short duration.
void showArSnack(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.info_outline,
  Color? color,
  IconData? actionIcon,
  VoidCallback? onAction,
  bool centered = false,
  bool showIcon = true,
}) {
  HapticFeedback.lightImpact();

  final overlay = Overlay.of(context);
  final mq = MediaQuery.of(context);
  final size = mq.size;
  final shortest = math.min(size.width, size.height);
  double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
  final scaler = MediaQuery.textScalerOf(context);

  // Position just under the AppBar, centered horizontally with side padding.
  final double cornerTop = (mq.padding.top * 0.12 + sp(6)).clamp(sp(6), sp(14));
  final double appBarTop = mq.padding.top + kToolbarHeight;
  final double topY = appBarTop + cornerTop;

  final double sidePad = (size.width * 0.18).clamp(sp(24), sp(100));
  final double iconSize = sp(18);
  final double titleFont = scaler.scale(sp(13));
  final double subFont = scaler.scale(sp(12));
  final double padH = sp(12);
  final double padV = sp(8);
  final double radius = sp(14);
  final double gapW = sp(8);
  final double gapH1 = sp(4);
  final double gapH2 = sp(2);
  final double elevationBlur = sp(12);
  final double elevationY = sp(6);

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
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A000000),
                  blurRadius: elevationBlur,
                  offset: Offset(0, elevationY),
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
                        SizedBox(height: gapH1),
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
                        SizedBox(height: gapH2),
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
                        SizedBox(width: gapW),
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
                              SizedBox(height: gapH2),
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
                        SizedBox(width: sp(6)),
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
  // Auto-dismiss duration scaled by device size for consistency.
  final baseSec = 2.0;
  final factor = (shortest / 375.0).clamp(0.9, 1.2);
  Timer(
    Duration(milliseconds: (baseSec * 1000 * factor).round()),
    entry.remove,
  );
}
