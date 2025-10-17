import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// Simple welcome screen shown on first launch or when user is logged out.
/// Presents a centered card with a CTA to move to the login page and a footer
/// with a secondary action to go to the signup page.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    /// Reusable rounded (pill) button builder used across the screen.
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
        ),
        onPressed: () {
          // Provide tactile feedback on press.
          Feedback.forTap(context);
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Text(
          label,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
        ),
      );
      return SizedBox(width: width, height: height, child: btn);
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Device/viewport measures
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // Keyboard visibility
            final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            const footerHeight = 20.0;

            // ---- Responsive sizing ----
            final double cardW = (w - 32)
                .clamp(280.0, 460.0)
                .toDouble();
            final double cardH = (h * 0.26).clamp(180.0, 260.0).toDouble();

            final double titleSize = (w * 0.12).clamp(28.0, 50.0).toDouble();

            final double mainBtnW = (w * 0.60).clamp(180.0, 320.0).toDouble();
            final double mainBtnH = (h * 0.055).clamp(40.0, 54.0).toDouble();
            final double mainFont = (w * 0.06).clamp(18.0, 24.0).toDouble();

            final double secBtnW = (w * 0.36).clamp(120.0, 200.0).toDouble();
            final double secBtnH = (h * 0.05).clamp(36.0, 48.0).toDouble();
            final double secFont = (w * 0.05).clamp(16.0, 20.0).toDouble();

            // The central card with title and main action (now responsive).
            final card = Container(
              width: cardW,
              height: cardH,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 8),
                    color: Color(0x44000000),
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
                    radius: 24,
                    fontSize: mainFont,
                  ),
                ],
              ),
            );

            return Stack(
              children: [
                // Main content area: card centered and responsively scaled down.
                Positioned.fill(
                  left: 16,
                  right: 16,
                  top: 24,
                  bottom: kbOpen ? 0 : footerHeight + 24,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardW),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [card, const SizedBox(height: 8)],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer with secondary action (Sign up). Hidden when keyboard is open.
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Offstage(
                    offstage: kbOpen,
                    child: Center(
                      // Wrap avoids overflow on very narrow devices.
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
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
                            radius: 24,
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
