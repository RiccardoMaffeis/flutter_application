import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_application/features/shop/controllers/shop_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IconButton for the cart with a responsive numeric badge.
// - Reads the cart item count from `cartCountProvider`.
// - Shows a pill-shaped badge (hidden when count == 0).
// - Caps display at '99+' for large counts.
// - Scales sizes and typography based on screen width and text scale.
class CartIconButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const CartIconButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reactive cart count from shop controller (kept in sync elsewhere).
    final count = ref.watch(cartCountProvider);

    // Responsive metrics derived from screen width and text scale.
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final textScale = media.textScaleFactor.clamp(1.0, 1.3);

    // Base icon and badge sizing, constrained to sensible min/max ranges.
    final double iconSize = (w * 0.085).clamp(26.0, 35.0);
    final double badgeMin = (iconSize * 0.52).clamp(16.0, 20.0);
    final double baseBadgeFont = (iconSize * 0.31).clamp(9.0, 12.0);
    final double badgeFont = (baseBadgeFont * textScale).toDouble();
    final double padH = (iconSize * 0.17).clamp(4.0, 6.0);
    final double padV = (iconSize * 0.09).clamp(2.0, 3.0);
    final double badgeRight = (iconSize * 0.08).clamp(1.0, 4.0);
    final double badgeTop = (iconSize * 0.08).clamp(1.0, 4.0);

    return Stack(
      clipBehavior: Clip.none, // Allow the badge to overflow the icon hitbox.
      children: [
        // Main cart icon; callback is injected by the parent.
        IconButton(
          onPressed: onPressed,
          iconSize: iconSize,
          icon: Icon(Icons.shopping_cart_outlined, size: iconSize),
        ),

        // Badge overlay: only visible when there are items in the cart.
        if (count > 0)
          Positioned(
            right: badgeRight,
            top: badgeTop,
            child: Container(
              // Horizontal padding to accommodate 1–3 digits; vertical for legibility.
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              // Ensure a minimum circular footprint (also used to compute radius).
              constraints: BoxConstraints(
                minWidth: badgeMin,
                minHeight: badgeMin,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accent, // Accent brand color.
                borderRadius: BorderRadius.circular(
                  badgeMin * 0.55,
                ), // Pill shape.
              ),
              alignment: Alignment.center,
              child: Text(
                // Cap at '99+' to avoid badge overflow for large counts.
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: badgeFont,
                  fontWeight: FontWeight.w800,
                  height: 1.0, // Tight line height to center glyphs better.
                ),
              ),
            ),
          ),
      ],
    );
  }
}
