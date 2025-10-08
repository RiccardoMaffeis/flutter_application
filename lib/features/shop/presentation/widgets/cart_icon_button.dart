import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_application/features/shop/controllers/cart_count_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartIconButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const CartIconButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.shopping_cart_outlined, size: 35),
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppTheme.accent, // o Colors.redAccent
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
