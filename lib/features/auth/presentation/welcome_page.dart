import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// Welcome screen shown on first launch or when user is logged out.
/// - Fully responsive: sizes, paddings, radii, shadows scale with screen.
/// - Limits (clamp) are widened so the layout breathes on large displays.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    /// Reusable rounded (pill) button used across the screen.
    Widget pillButton({
      required String label,
      required VoidCallback onPressed,
      double width = 240,
      double height = 45,
      double radius = 24,
      double fontSize = 25,
    }) {
      final btn = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: EdgeInsets.zero,
          minimumSize: Size(width, height),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
        ),
        onPressed: () {
          Feedback.forTap(context);
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Text(label),
      );
      return SizedBox(width: width, height: height, child: btn);
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Viewport measures
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // Keyboard visibility
            final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

            // ---- Responsive scale factor (relative to a 375pt baseline) ----
            final shortest = math.min(w, h);
            final s = (shortest / 375.0).clamp(0.85, 1.30);
            double sp(double v) => v * s;

            // Footer height (scaled)
            final double footerHeight = sp(20);

            // ---- Responsive sizing ----
            final double cardW = ((w - sp(32)))
                .clamp(sp(280), sp(540))
                .toDouble();
            final double cardH = (h * 0.26).clamp(sp(160), sp(360)).toDouble();

            final double titleSize = (w * 0.12)
                .clamp(sp(22), sp(64))
                .toDouble();

            final double mainBtnW = (w * 0.60)
                .clamp(sp(160), sp(420))
                .toDouble();
            final double mainBtnH = (h * 0.055)
                .clamp(sp(36), sp(64))
                .toDouble();
            final double mainFont = (w * 0.06).clamp(sp(16), sp(28)).toDouble();

            final double secBtnW = (w * 0.36)
                .clamp(sp(120), sp(260))
                .toDouble();
            final double secBtnH = (h * 0.05).clamp(sp(34), sp(56)).toDouble();
            final double secFont = (w * 0.05).clamp(sp(14), sp(22)).toDouble();

            // Scaled cosmetics
            final double pad = sp(24);
            final double radius = sp(24);
            final double shadowBlur = sp(18);
            final double shadowYOffset = sp(8);
            final double sidePad = sp(16);
            final double topPad = sp(24);
            final double bottomExtra = sp(24);
            final double gapSmall = sp(8);
            final double wrapSpacing = sp(12);
            final double wrapRunSpacing = sp(8);

            // Central card with title and main action.
            final card = Container(
              width: cardW,
              height: cardH,
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    blurRadius: shadowBlur,
                    offset: Offset(0, shadowYOffset),
                    color: const Color(0x44000000),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: cardH * 0.04),
                  Text(
                    'Welcome!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: cardH * 0.14),
                  // Primary action: navigate to login.
                  pillButton(
                    label: 'Next',
                    onPressed: () => context.go('/login'),
                    width: mainBtnW,
                    height: mainBtnH,
                    radius: radius,
                    fontSize: mainFont,
                  ),
                ],
              ),
            );

            return Stack(
              children: [
                // Main content: card centered and responsively scaled down.
                Positioned.fill(
                  left: sidePad,
                  right: sidePad,
                  top: topPad,
                  bottom: kbOpen ? 0 : footerHeight + bottomExtra,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardW),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            card,
                            SizedBox(height: gapSmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer with secondary action (Sign up). Hidden when keyboard is open.
                Positioned(
                  left: sidePad,
                  right: sidePad,
                  bottom: footerHeight,
                  child: Offstage(
                    offstage: kbOpen,
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: wrapSpacing,
                        runSpacing: wrapRunSpacing,
                        children: [
                          Text(
                            'Need an account?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: secFont,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          pillButton(
                            label: 'Sign up',
                            onPressed: () => context.go('/signup'),
                            width: secBtnW,
                            height: secBtnH,
                            fontSize: secFont,
                            radius: radius,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
