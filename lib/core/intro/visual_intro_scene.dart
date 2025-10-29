import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// Animated visual intro scene:
/// - Drops a couple of chips along bezier paths into a circular brand "bag"
/// - Shows expanding impact splashes
/// - Then optionally auto-navigates to [nextRoute] when the animation completes
class VisualIntroScene extends StatefulWidget {
  const VisualIntroScene({
    super.key,
    this.nextRoute = '/welcome',
    this.autonext = true,
    this.durationMs = 2400,
    this.brandColor = AppTheme.accent,
    this.logoAsset = 'lib/images/general/icon_fg.png',
    this.logoSize = 120,
    this.frontScale = 0.90,
  });

  /// Route to push when the animation finishes (if [autonext] is true).
  final String nextRoute;

  /// If true, automatically navigates to [nextRoute] when the animation ends.
  final bool autonext;

  /// Total duration of the intro animation in milliseconds.
  final int durationMs;

  /// Main brand color used by the circular background and splash effect.
  final Color brandColor;

  /// Optional center logo image; if null a default icon is shown.
  final String? logoAsset;

  /// Base diameter of the circular brand "bag".
  final double logoSize;

  /// Multiplicative scale applied to the front logo over the circular bag.
  final double frontScale;

  @override
  State<VisualIntroScene> createState() => _VisualIntroSceneState();
}

class _VisualIntroSceneState extends State<VisualIntroScene>
    with SingleTickerProviderStateMixin {
  /// Drives the whole timeline for drops + splashes.
  late final AnimationController ctrl;

  /// Prevents double navigation if rebuilds happen at completion.
  bool pushed = false;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..forward();

    // When the timeline ends, navigate if autonext is enabled.
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && widget.autonext && !pushed) {
        pushed = true;
        if (mounted) context.go(widget.nextRoute);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache images to avoid first-frame flicker during the animation.
    final asset = widget.logoAsset;
    if (asset != null) precacheImage(AssetImage(asset), context);
    precacheImage(const AssetImage('lib/images/general/chatbot.png'), context);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  /// Returns normalized progress (0..1) for a sub-range [a,b] of the global timeline [v].
  double _phase(double v, double a, double b) =>
      v <= a ? 0.0 : (v >= b ? 1.0 : (v - a) / (b - a));

  /// Simple linear interpolation between [a] and [b] using [t] in [0,1].
  double _lerp(num a, num b, double t) => (a + (b - a) * t).toDouble();

  @override
  Widget build(BuildContext context) {
    final brand = widget.brandColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bc) {
            // Canvas dimensions and key reference points for motion paths.
            final W = bc.maxWidth, H = bc.maxHeight;
            final bagCenter = Offset(W / 2, H * 0.55);
            final bagR = widget.logoSize / 2;
            final bagMouth = bagCenter.translate(0, -bagR * 0.35);

            // Configure each falling chip: quadratic bezier path + impact splash window.
            final specs = <_DropSpec>[
              _DropSpec.asset(
                asset: 'lib/images/general/chatbot.png',
                start: Offset(W * 0.18, -H * 0.12),
                ctrl: Offset(W * 0.28, H * 0.18),
                end: bagMouth,
                t0: 0.00,
                t1: 0.58,
                splash0: 0.58,
                splash1: 0.78,
              ),
              _DropSpec.icon(
                icon: Icons.view_in_ar,
                start: Offset(W * 0.58, -H * 0.16),
                ctrl: Offset(W * 0.52, H * 0.20),
                end: bagMouth,
                t0: 0.10,
                t1: 0.68,
                splash0: 0.68,
                splash1: 0.88,
              ),
            ];

            return Stack(
              children: [
                // Rear circular brand background.
                Center(
                  child: _LogoBagBack(size: widget.logoSize, color: brand),
                ),

                // Falling chips along bezier paths with slight rotation/scale.
                AnimatedBuilder(
                  animation: ctrl,
                  builder: (_, __) {
                    return Stack(
                      children: [
                        for (final s in specs)
                          Builder(
                            builder: (_) {
                              final t = CurvedAnimation(
                                parent: ctrl,
                                curve: Interval(
                                  s.t0,
                                  s.t1,
                                  curve: Curves.easeIn,
                                ),
                              ).value;
                              final p = _quadBezier(s.start, s.ctrl, s.end, t);
                              final rot = (1 - t) * 0.6; // small spin-in
                              final scale = _lerp(
                                1.0,
                                0.85,
                                t,
                              ); // subtle shrink
                              return Positioned(
                                left: p.dx - 18,
                                top: p.dy - 18,
                                child: Transform.rotate(
                                  angle: rot,
                                  child: Transform.scale(
                                    scale: scale,
                                    child: _FallingChip(
                                      icon: s.icon,
                                      asset: s.asset,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),

                // Foreground circle + logo on top (slightly scaled).
                Center(
                  child: _LogoBagFront(
                    size: widget.logoSize,
                    asset: widget.logoAsset,
                    fallbackColor: brand,
                    frontScale: widget.frontScale,
                  ),
                ),

                // Impact splash rings timed to each chip's arrival window.
                AnimatedBuilder(
                  animation: ctrl,
                  builder: (_, __) {
                    final v = ctrl.value;
                    return Stack(
                      children: [
                        for (final s in specs)
                          Positioned(
                            left: bagMouth.dx - 40,
                            top: bagMouth.dy - 40,
                            child: _ImpactSplash(
                              progress: _phase(v, s.splash0, s.splash1),
                              brand: brand,
                              size: 80,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Quadratic bezier interpolation from p0->p2 with control p1 at time t.
  Offset _quadBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    final x = u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx;
    final y = u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
  }
}

/// Simple circular brand background with soft shadow.
class _LogoBagBack extends StatelessWidget {
  const _LogoBagBack({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            spreadRadius: 2,
            offset: Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

/// Foreground brand circle holding the logo (or fallback icon).
class _LogoBagFront extends StatelessWidget {
  const _LogoBagFront({
    required this.size,
    required this.asset,
    required this.fallbackColor,
    required this.frontScale,
  });
  final double size;
  final String? asset;
  final Color fallbackColor;
  final double frontScale;

  @override
  Widget build(BuildContext context) {
    final double fs = frontScale.clamp(0.0, 1.2).toDouble();
    final w = size * fs, h = size * fs;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: asset != null
            ? Image.asset(asset!, width: w, height: h, fit: BoxFit.contain)
            : Icon(Icons.shopping_bag, size: w * 0.65, color: fallbackColor),
      ),
    );
  }
}

/// Small circular chip widget that can render either an icon or an asset image.
class _FallingChip extends StatelessWidget {
  const _FallingChip({this.icon, this.asset});
  final IconData? icon;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F7),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDDDEE1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: asset != null
            ? Image.asset(asset!, width: 18, height: 18, fit: BoxFit.contain)
            : Icon(icon!, size: 18, color: Colors.black87),
      ),
    );
  }
}

/// Expanding ring + rays effect to emphasize an impact moment.
class _ImpactSplash extends StatelessWidget {
  const _ImpactSplash({
    required this.progress,
    required this.brand,
    required this.size,
  });
  final double progress; // 0..1 local progress of this splash
  final Color brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0) return const SizedBox.shrink();

    // Animate radius, opacity and stroke over time.
    final radius = 8.0 + 28.0 * Curves.easeOut.transform(p);
    final alpha = (1.0 - p).clamp(0.0, 1.0).toDouble();
    final stroke = (2.5 - 1.5 * p).clamp(1.0, 2.5).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SplashPainter(
          radius: radius,
          stroke: stroke,
          color: brand.withOpacity(0.8 * alpha),
          rays: (6 + (p * 6)).toInt(),
          rayLen: 10 + 8 * (1 - p),
        ),
      ),
    );
  }
}

/// Custom painter that draws an outer ring plus radial rays.
class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.radius,
    required this.stroke,
    required this.color,
    required this.rays,
    required this.rayLen,
  });
  final double radius;
  final double stroke;
  final Color color;
  final int rays;
  final double rayLen;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Outer ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawCircle(c, radius, ring);

    // Radial rays
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.7
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (int i = 0; i < rays; i++) {
      final a = (math.pi * 2) * (i / rays);
      final start = Offset(
        c.dx + (radius - rayLen) * math.cos(a),
        c.dy + (radius - rayLen) * math.sin(a),
      );
      final end = Offset(
        c.dx + (radius + rayLen) * math.cos(a),
        c.dy + (radius + rayLen) * math.sin(a),
      );
      canvas.drawLine(start, end, ray);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) =>
      old.radius != radius ||
      old.stroke != stroke ||
      old.color != color ||
      old.rays != rays ||
      old.rayLen != rayLen;
}

/// Animation spec for each falling element:
/// - [start] -> [end] via quadratic bezier with control point [ctrl]
/// - [t0..t1] is the time window (0..1) for the fall animation
/// - [splash0..splash1] is the time window (0..1) for the impact splash
class _DropSpec {
  const _DropSpec.icon({
    required this.icon,
    required this.start,
    required this.ctrl,
    required this.end,
    required this.t0,
    required this.t1,
    required this.splash0,
    required this.splash1,
  }) : asset = null;

  const _DropSpec.asset({
    required this.asset,
    required this.start,
    required this.ctrl,
    required this.end,
    required this.t0,
    required this.t1,
    required this.splash0,
    required this.splash1,
  }) : icon = null;

  final IconData? icon;
  final String? asset;

  final Offset start;
  final Offset ctrl;
  final Offset end;
  final double t0, t1;
  final double splash0, splash1;
}
