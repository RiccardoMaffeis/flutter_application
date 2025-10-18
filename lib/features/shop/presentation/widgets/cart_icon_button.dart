import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_application/features/shop/controllers/shop_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartIconButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const CartIconButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);

    // ---- Responsive metrics ----
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final textScale = media.textScaleFactor.clamp(1.0, 1.3);

    final double iconSize = (w * 0.085).clamp(26.0, 35.0);
    final double badgeMin = (iconSize * 0.52).clamp(16.0, 20.0);
    final double baseBadgeFont = (iconSize * 0.31).clamp(9.0, 12.0);
    final double badgeFont = (baseBadgeFont * textScale).toDouble();
    final double padH = (iconSize * 0.17).clamp(4.0, 6.0);
    final double padV = (iconSize * 0.09).clamp(2.0, 3.0);
    final double badgeRight = (iconSize * 0.08).clamp(1.0, 4.0);
    final double badgeTop = (iconSize * 0.08).clamp(1.0, 4.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          iconSize: iconSize,
          icon: Icon(Icons.shopping_cart_outlined, size: iconSize),
        ),
        if (count > 0)
          Positioned(
            right: badgeRight,
            top: badgeTop,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              constraints: BoxConstraints(
                minWidth: badgeMin,
                minHeight: badgeMin,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(badgeMin * 0.55),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: badgeFont,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
