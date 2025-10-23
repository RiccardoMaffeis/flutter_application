import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../ar/controllers/ar_landing_controller.dart';
import '../../../ar/domain/ar_choice.dart';

/// Landing screen for the AR section.
/// Uses Riverpod to read available AR choices and GoRouter for navigation.
class ARLandingPage extends ConsumerStatefulWidget {
  const ARLandingPage({super.key});

  @override
  ConsumerState<ARLandingPage> createState() => _ARLandingPageState();
}

class _ARLandingPageState extends ConsumerState<ARLandingPage> {
  @override
  Widget build(BuildContext context) {
    // Read the list of AR choices from the controller's state.
    final choices = ref.watch(arLandingControllerProvider).choices;

    // ---- Responsive metrics ----
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;

    final double headerHPad = (w * 0.04).clamp(12.0, 22.0);
    final double headerVPad = (h * 0.012).clamp(6.0, 14.0);
    final double headerTitleSize = (w * 0.075).clamp(28.0, 44.0) * ts;
    final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0)).toDouble();

    final double listHPad = (w * 0.03).clamp(10.0, 18.0);
    final double listVGap = (h * 0.015).clamp(8.0, 16.0);

    final double searchIconSize = (w * 0.085)
        .clamp(sp(26.0), sp(35.0))
        .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light neutral background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ----- Header (match Shop/Favourites: [left slot] [title] [cart]) -----
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    headerHPad,
                    headerVPad,
                    headerHPad,
                    (h * 0.006).clamp(4.0, 10.0),
                  ),
                  child: Row(
                    children: [
                      // Slot sinistro: IconButton invisibile per avere la stessa larghezza di Shop
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0,
                          child: IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.search, size: searchIconSize),
                          ),
                        ),
                      ),
                      // Titolo centrato
                      Expanded(
                        child: Center(
                          child: Text(
                            'Augmented Reality',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: headerTitleSize,
                                ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: (w * 0.085).clamp(sp(26.0), sp(35.0)),
                        child: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                // Accent underline under the title (ABB-like red bar)
                Container(
                  height: barH,
                  margin: EdgeInsets.symmetric(horizontal: sp(12)),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(sp(3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: sp(3),
                        spreadRadius: sp(0.4),
                        offset: Offset(0, sp(3)),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: sp(12)),

                // Vertical list of tappable AR choices (big chip-like tiles)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: listHPad),
                  child: Column(
                    children: [
                      for (final c in choices) ...[
                        _ChoiceTile(
                          choice: c,
                          onTap: () => context.push('/ar/${c.route}'),
                        ),
                        SizedBox(height: listVGap),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable tile representing one AR choice.
/// Shows the choice title and a right-aligned preview image (if available).
class _ChoiceTile extends StatelessWidget {
  final ARChoice choice;
  final VoidCallback onTap;

  const _ChoiceTile({required this.choice, required this.onTap});

  /// Build a strict asset path from the choice's asset, forcing it into
  /// 'lib/images/general' and ensuring the '.png' extension.
  String get _assetPath {
    final base = choice.asset.split('/').last;
    final name = base.endsWith('.png') ? base : '$base.png';
    return 'lib/images/general/$name';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth;
        final ts = MediaQuery.of(ctx).textScaleFactor.clamp(1.0, 1.3);

        final double cardRadius = (w * 0.055).clamp(18.0, 26.0);
        final double hPad = (w * 0.04).clamp(12.0, 20.0);
        final double tileHeight = (w * 0.18).clamp(64.0, 92.0);
        final double titleSize = (w * 0.06).clamp(16.0, 22.0) * ts;
        final double imgW = (w * 0.16).clamp(48.0, 72.0);
        final double imgH = (tileHeight * 0.58).clamp(36.0, 56.0);
        final double chevron = (w * 0.075).clamp(22.0, 30.0);
        final double gap = (w * 0.02).clamp(6.0, 10.0);

        return Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(cardRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(cardRadius),
            onTap: onTap,
            child: Container(
              height: tileHeight,
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  // Choice title
                  Expanded(
                    child: Text(
                      choice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  // Right preview image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      _assetPath,
                      width: imgW,
                      height: imgH,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.inventory_2_outlined,
                        size: imgH * 0.7,
                        color: Colors.black38,
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  Icon(Icons.chevron_right, size: chevron),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
