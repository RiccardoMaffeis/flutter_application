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

    // The central card with title and main action.
    final card = Container(
      width: 380,
      height: 200,
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
          const SizedBox(height: 8),
          const Text(
            'Welcome!',
            style: TextStyle(fontSize: 50, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 27),
          // Primary action: navigate to login.
          pillButton(label: 'Next', onPressed: () => context.go('/login')),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Reserve space for the footer when the keyboard is not visible.
            const footerHeight = 20.0;
            final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

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
                        constraints: const BoxConstraints(maxWidth: 460),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Need an account?',
                          style: TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 10),
                        pillButton(
                          label: 'Sign up',
                          onPressed: () => context.go('/signup'),
                          width: 140,
                          height: 40,
                          fontSize: 20,
                          radius: 24,
                        ),
                      ],
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
