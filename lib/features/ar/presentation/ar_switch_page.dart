import 'dart:async';
import 'dart:io' show Platform, File;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double titleFont = (w * 0.06).clamp(w * 0.045, w * 0.085) * ts;
    final double toolbarH = (h * 0.08).clamp(h * 0.07, h * 0.10);
    final double fallbackFont = (w * 0.045).clamp(w * 0.035, w * 0.065) * ts;

    if (Platform.isAndroid) {
      return ArLivePage(
        title: title,
        glbUrl: glbUrl,
        assetGlb: assetGlb,
        scale: scale,
      );
    }

    if (Platform.isIOS) {
      return _ArKitXtLiveView(
        title: title,
        androidLikeDefaultGlbAsset: assetGlb,
        defaultScale: scale,
        appBarTitleFont: titleFont,
        appBarHeight: toolbarH,
      );
    }

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

class _ArKitXtLiveView extends StatefulWidget {
  final String title;
  final String? androidLikeDefaultGlbAsset;
  final double defaultScale;
  final double appBarTitleFont;
  final double appBarHeight;

  const _ArKitXtLiveView({
    required this.title,
    this.androidLikeDefaultGlbAsset,
    this.defaultScale = 0.2,
    required this.appBarTitleFont,
    required this.appBarHeight,
  });

  @override
  State<_ArKitXtLiveView> createState() => _ArKitXtLiveViewState();
}

class _ArKitXtLiveViewState extends State<_ArKitXtLiveView> {
  late ARKitController _controller;

  final List<_PlacedIOS> _placed = [];
  String? _selectedId;

  bool _appendMode = false;
  ARItem? _pendingItem;
  bool _placeBusy = false;

  double _sliderXDeg = 0;

  @override
  void dispose() {
    _removeAll();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final shortest = math.min(size.width, size.height);
    double sp(double v) => v * (shortest / 375.0).clamp(0.80, 1.35);
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double cornerIcon = sp(32);
    final double cornerPad = sp(10);
    final double cornerTop = (mq.padding.top * 0.12 + sp(6)).clamp(
      sp(6),
      sp(14),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: widget.appBarHeight,
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: widget.appBarTitleFont,
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ARKitSceneView(
            planeDetection: ARPlaneDetection.horizontal,
            enableTapRecognizer: true,
            onARKitViewCreated: _onViewCreated,
          ),

          Positioned(
            left: cornerPad,
            top: cornerTop,
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
                splashRadius: (cornerIcon * 0.6).clamp(sp(18), sp(28)),
              ),
            ),
          ),

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
                                        activeTrackColor: const Color(
                                          0xFFED1C24,
                                        ), // ABB-ish accent
                                        inactiveTrackColor: Colors.white,
                                        thumbColor: const Color(0xFFED1C24),
                                        overlayColor: const Color(
                                          0xFFED1C24,
                                        ).withOpacity(0.12),
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
                                        fontSize: (sp(13) * ts),
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
                  SizedBox(height: sp(12)),
                  const _BottomHelpCard(),
                ],
              ),
            ),
          ),

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

  void _onViewCreated(ARKitController controller) {
    _controller = controller;

    _controller.onARTap = (List<ARKitTestResult> hits) async {
      if (_placeBusy) return;
      setState(() => _placeBusy = true);
      try {
        await Future.delayed(const Duration(milliseconds: 120));
        if (hits.isEmpty) return;

        if (!_appendMode) {
          await _removeAll();
        }

        final hit = hits.first;
        final col = hit.worldTransform.getColumn(3);
        final pos = vm.Vector3(col.x, col.y, col.z);

        final newId = 'mdl_${DateTime.now().microsecondsSinceEpoch}';
        final double s = _pendingItem?.scale ?? widget.defaultScale;

        final yawPi = vm.Vector3(0, math.pi, 0);

        ARKitNode node;

        if (_pendingItem != null) {
          final usdzAsset = _iosUsdzFromGlb(_pendingItem!.glbPath);
          final urlPath = await _stageUsdzIntoAppFolder(usdzAsset);
          node = ARKitReferenceNode(
            name: newId,
            url: urlPath,
            position: pos,
            eulerAngles: yawPi,
            scale: vm.Vector3(s, s, s),
          );
        } else if (widget.androidLikeDefaultGlbAsset != null &&
            widget.androidLikeDefaultGlbAsset!.isNotEmpty) {
          final usdzAsset = _iosUsdzFromGlb(widget.androidLikeDefaultGlbAsset!);
          final urlPath = await _stageUsdzIntoAppFolder(usdzAsset);
          node = ARKitReferenceNode(
            name: newId,
            url: urlPath,
            position: pos,
            eulerAngles: yawPi,
            scale: vm.Vector3(s, s, s),
          );
        } else {
          if (!mounted) return;
          showArSnack(
            context,
            title: 'No 3D model provided',
            centered: true,
            showIcon: false,
          );
          return;
        }

        await _controller.add(node);
        if (mounted) {
          setState(() {
            _placed.add(_PlacedIOS(id: newId, node: node));
            _appendMode = false;
            _pendingItem = null;
            _selectedId = newId;
            _sliderXDeg = 0;
          });
        }

        showArSnack(
          context,
          title: 'Model placed',
          subtitle: 'Tap again to add more or move around',
          icon: Icons.check,
        );
      } finally {
        if (mounted) setState(() => _placeBusy = false);
      }
    };

    _controller.onNodeTap = (nodes) {
      if (nodes.isEmpty) return;
      final id = nodes.first;
      final idx = _placed.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final node = _placed[idx].node;
        final xDeg = (node.eulerAngles.x) * 180.0 / math.pi;
        setState(() {
          _selectedId = id;
          _sliderXDeg = xDeg;
        });
        showArSnack(
          context,
          title: 'Model selected',
          subtitle: 'Use the slider to rotate (X axis)',
          icon: Icons.check,
        );
      } else {
        setState(() => _selectedId = id);
      }
    };
  }

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
      );
    }
  }

  Future<void> _removeAll() async {
    for (final e in List<_PlacedIOS>.from(_placed)) {
      try {
        await _controller.remove(e.id);
      } catch (_) {}
    }

    _placed.clear();
    _selectedId = null;
    _sliderXDeg = 0;
    if (mounted) setState(() {});
  }

  void _setSelectedXDeg(double degrees) {
    if (_selectedId == null) {
      setState(() => _sliderXDeg = degrees);
      return;
    }
    final idx = _placed.indexWhere((e) => e.id == _selectedId);
    if (idx == -1) {
      setState(() => _sliderXDeg = degrees);
      return;
    }
    final node = _placed[idx].node;
    final eul = node.eulerAngles;
    node.eulerAngles = vm.Vector3(degrees * math.pi / 180.0, eul.y, eul.z);
    setState(() => _sliderXDeg = degrees);
  }

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
                          final tpath = _imagePathFor(it.glbPath);
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
                          backgroundColor: const Color(0xFFED1C24),
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

  String _iosUsdzFromGlb(String pathInCatalog) {
    final lower = pathInCatalog.toLowerCase();
    if (lower.endsWith('.usdz')) return pathInCatalog;
    if (lower.endsWith('.glb')) {
      return pathInCatalog.substring(0, pathInCatalog.length - 4) + '.usdz';
    }
    return '$pathInCatalog.usdz';
  }

  Future<String> _stageUsdzIntoAppFolder(String assetPath) async {
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
    return outFile.path;
  }

  String _imagePathFor(String anyModelPath) {
    var path = anyModelPath.replaceFirst('3Dmodels', 'images');
    path = path.replaceAll(RegExp(r'\.usdz$', caseSensitive: false), '');
    path = path.replaceAll(RegExp(r'\.glb$', caseSensitive: false), '');
    final last = path.lastIndexOf('/');
    final dir = path.substring(0, last + 1);
    final file = path.substring(last + 1);
    return '$dir$file.png';
  }
}

class _PlacedIOS {
  final String id;
  final ARKitNode node;
  _PlacedIOS({required this.id, required this.node});
}

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
  final double gapH2 = sp(2);
  final double elevationBlur = sp(12);
  final double elevationY = sp(6);

  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
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
                      SizedBox(height: gapH2),
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
                      SizedBox(
                        width: sp(30),
                        height: sp(30),
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onAction,
                            child: Icon(actionIcon, size: sp(18)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  final baseSec = 2.0;
  final factor = (shortest / 375.0).clamp(0.9, 1.2);
  Timer(
    Duration(milliseconds: (baseSec * 1000 * factor).round()),
    entry.remove,
  );
}
