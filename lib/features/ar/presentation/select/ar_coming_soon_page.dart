import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ComingSoonPage extends StatelessWidget {
  final String title;
  final String message;

  const ComingSoonPage({
    super.key,
    this.title = 'Coming soon',
    this.message = 'This feature is on the way.\nStay tuned!',
  });

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/ar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;

    // Header sizing
    final double iconSize = (w * 0.075).clamp(24.0, 36.0);
    final double headerHPad = (w * 0.016).clamp(6.0, 12.0);
    final double headerVPad = (h * 0.01).clamp(6.0, 10.0);
    final double headerTopGap = (h * 0.006).clamp(4.0, 8.0);
    final double headerTitleSize = (w * 0.075).clamp(22.0, 38.0);

    // Accent bar
    final double accentHMargin = (w * 0.04).clamp(12.0, 20.0);
    final double accentHeight = (h * 0.005).clamp(3.0, 6.0);

    // Body content
    final double bodyTopGap = (h * 0.03).clamp(16.0, 28.0);
    final double bodyBottomGap = (h * 0.03).clamp(16.0, 28.0);
    final double centerIcon = (w * 0.18).clamp(56.0, 92.0);
    final double centerIconGap = (h * 0.015).clamp(8.0, 14.0);
    final double titleFont = (w * 0.055).clamp(18.0, 28.0);
    final double msgFont = (w * 0.042).clamp(14.0, 20.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: headerTopGap),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                headerHPad,
                headerVPad,
                headerHPad,
                headerVPad,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: iconSize,
                    onPressed: () => _handleBack(context),
                  ),
                  Expanded(
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
                  // Keep title perfectly centered by reserving equal trailing space
                  SizedBox(width: iconSize + headerHPad * 2),
                ],
              ),
            ),
            // Accent bar
            Container(
              height: accentHeight,
              margin: EdgeInsets.symmetric(horizontal: accentHMargin),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: bodyTopGap),

            // Content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.construction_outlined, size: centerIcon),
                    SizedBox(height: centerIconGap),
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
                    SizedBox(height: (h * 0.01).clamp(6.0, 10.0)),
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
            SizedBox(height: bodyBottomGap),
          ],
        ),
      ),
    );
  }
}
