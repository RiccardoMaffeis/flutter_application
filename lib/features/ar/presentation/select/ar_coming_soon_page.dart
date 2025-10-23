import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// Generic "Coming Soon" screen with a centered message and a
/// responsive header. It supports:
/// - A back arrow that pops the current route if possible,
///   otherwise navigates to '/ar' using GoRouter.
/// - Simple responsive sizing for icons and typography.
/// - A red accent bar under the header to match brand styling.
class ComingSoonPage extends StatelessWidget {
  final String title;
  final String message;

  const ComingSoonPage({
    super.key,
    this.title = 'Coming soon',
    this.message = 'This feature is on the way.\nStay tuned!',
  });

  /// Handles the top-left back action:
  /// - If the current Navigator can pop → pop()
  /// - Otherwise → go('/ar') as a safe fallback route
  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/ar');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ---- Responsive metrics pulled from MediaQuery ----
    // We compute a few sizes based on screen width/height and text scale
    // to keep the layout consistent across devices.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30).toDouble();
    double sp(double v) => v * scale;
    final double searchIconSize = (w * 0.085)
        .clamp(sp(26.0), sp(35.0))
        .toDouble();

    // Header sizing (icon/button area + title)
    final double headerTopGap = (h * 0.006).clamp(4.0, 8.0);
    final double headerTitleSize = (w * 0.075).clamp(22.0, 38.0) * ts;
    final double barH = (w * 0.01).clamp(sp(3.0), sp(4.0)).toDouble();

    final double bodyBottomGap = (h * 0.03).clamp(16.0, 28.0);
    final double centerIcon = (w * 0.18).clamp(56.0, 92.0);
    final double centerIconGap = (h * 0.015).clamp(8.0, 14.0);
    final double titleFont = (w * 0.055).clamp(18.0, 28.0) * ts;
    final double msgFont = (w * 0.042).clamp(14.0, 20.0) * ts;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: headerTopGap),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sp(12),
                vertical: sp(6),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: searchIconSize,
                    onPressed: () => _handleBack(context),
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        'Augmented Reality',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: headerTitleSize,
                            ),
                      ),
                    ),
                  ),

                  IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.search, size: searchIconSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- Accent bar under header ----
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

            // ---- Body: icon + title + message ----
            // Uses Expanded+Center to keep it vertically centered on taller screens.
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Placeholder construction icon
                    Icon(Icons.construction_outlined, size: centerIcon),

                    SizedBox(height: centerIconGap),

                    // Coming soon title (bold, large)
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleFont,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    // Small vertical gap before the message
                    SizedBox(height: (h * 0.01).clamp(6.0, 10.0)),

                    // Explanatory text with horizontal padding for readability
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (w * 0.08).clamp(16.0, 40.0),
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: msgFont,
                          color: Colors.black54,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom spacer to balance vertical rhythm on devices with home indicators
            SizedBox(height: bodyBottomGap),
          ],
        ),
      ),
    );
  }
}
