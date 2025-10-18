import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../ar/controllers/ar_landing_controller.dart';
import '../../../ar/domain/ar_choice.dart';

/// Landing screen for the AR section.
/// Uses Riverpod to read available AR choices and GoRouter for navigation.
class ARLandingPage extends ConsumerWidget {
  const ARLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the list of AR choices from the controller's state.
    final choices = ref.watch(arLandingControllerProvider).choices;

    // ---- Responsive metrics ----
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double headerHPad = (w * 0.04).clamp(12.0, 22.0);
    final double headerVPad = (h * 0.012).clamp(6.0, 14.0);
    final double headerTitleSize = (w * 0.085).clamp(28.0, 44.0) * ts;

    final double accentBarHeight = (h * 0.005).clamp(3.0, 6.0);
    final double accentBarHMargin = (w * 0.04).clamp(12.0, 24.0);

    final double listHPad = (w * 0.03).clamp(10.0, 18.0);
    final double listVGap = (h * 0.015).clamp(8.0, 16.0);

    final double assistantBtnSize = (w * 0.11).clamp(40.0, 56.0);
    final double assistantIcon = (assistantBtnSize * 0.64).clamp(22.0, 34.0);
    final double assistantBottom = (h * 0.12).clamp(76.0, 110.0);
    final double assistantRight = (w * 0.04).clamp(12.0, 20.0);

    // Bottom nav sizing + reserved space
    final double navSideMargin = (w * 0.04).clamp(12.0, 20.0);
    final double navHeight = (h * 0.075).clamp(54.0, 70.0);
    final double bottomReserved = navHeight + (h * 0.02).clamp(10.0, 18.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light neutral background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    headerHPad,
                    headerVPad,
                    headerHPad,
                    (h * 0.006).clamp(4.0, 10.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
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
                    ],
                  ),
                ),
                // Accent underline under the title (ABB-like red bar)
                Container(
                  height: accentBarHeight,
                  margin: EdgeInsets.symmetric(horizontal: accentBarHMargin),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: 3,
                        spreadRadius: 0.4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (h * 0.018).clamp(10.0, 20.0)),

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

                const Spacer(),
                SizedBox(
                  height: bottomReserved,
                ), // Reserve space for bottom nav
              ],
            ),

            // Floating circular button for the assistant, bottom-right
            Positioned(
              right: assistantRight,
              bottom: assistantBottom,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  onTap: () => context.push('/assistant'),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: assistantBtnSize,
                    height: assistantBtnSize,
                    child: Icon(
                      Icons.psychology_alt_outlined,
                      size: assistantIcon,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: navSideMargin,
              right: navSideMargin,
              bottom: (h * 0.02).clamp(10.0, 18.0),
              child: _BottomPillNav(
                index: 2,
                onChanged: (i) {
                  if (i == 2) return;
                  if (i == 1) context.go('/favourites');
                  if (i == 3) context.go('/profile');
                  if (i == 0) context.go('/home');
                },
              ),
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

/// Reusable bottom navigation with a sliding "pill" highlight.
/// - Accepts a `index` to indicate the selected tab
/// - Calls `onChanged` with the tapped index
class _BottomPillNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomPillNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            spreadRadius: 2,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.fromBorderSide(
          const BorderSide(color: Color(0x11000000)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          const pad = 6.0;
          final slotW = (cons.maxWidth - pad * 2) / 4;
          return Stack(
            children: [
              // Animated pill indicating the selected tab.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: pad + index * slotW,
                top: pad,
                bottom: pad,
                width: slotW,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              // Four icons (Home/Favourites/AR/Profile).
              Padding(
                padding: const EdgeInsets.all(pad),
                child: Row(
                  children: [
                    _NavIcon(
                      icon: Icons.shopping_bag_outlined,
                      selected: index == 0,
                      onTap: () => onChanged(0),
                    ),
                    _NavIcon(
                      icon: Icons.favorite_border,
                      selected: index == 1,
                      onTap: () => onChanged(1),
                    ),
                    _NavIcon(
                      icon: Icons.view_in_ar,
                      selected: index == 2,
                      onTap: () => onChanged(2),
                    ),
                    _NavIcon(
                      icon: Icons.person_outline,
                      selected: index == 3,
                      onTap: () => onChanged(3),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Single icon button used by the pill navigation.
/// - Changes color to white when selected (due to colored pill background)
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Icon(
            icon,
            size: 34,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
