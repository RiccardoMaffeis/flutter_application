import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application/core/bottom_nav/global_ui_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppScaffold extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AppScaffold({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final mq = MediaQuery.of(context);
    final w = size.width;
    final shortest = math.min(size.width, size.height);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => (v * s).toDouble();

    final location = GoRouterState.of(context).uri.toString();
    final bool isArDetails =
        location.startsWith('/ar/xt') || location.startsWith('/ar/emax');

    final bool hideChrome = ref.watch(hideChromeProvider);

    final bool hideNav = isArDetails || hideChrome;

    final navHeight = sp(58);
    final btnSize = (w * 0.12).clamp(sp(40.0), sp(52.0)).toDouble();

    final double assistantBottomOffset = hideNav
        ? (mq.padding.bottom + sp(30))
        : (navHeight + mq.padding.bottom + sp(30));

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5F5F7),

      body: Stack(
        children: [
          Positioned.fill(child: shell),

          if (!hideNav)
            Positioned(
              right: sp(16),
              bottom: assistantBottomOffset,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: sp(4),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/assistant'),
                  child: SizedBox(
                    width: btnSize,
                    height: btnSize,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        heightFactor: 0.75,
                        child: Image.asset(
                          'lib/images/general/chatbot.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: hideNav
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(sp(16), sp(8), sp(16), sp(16)),
                child: _BottomPillNav(
                  index: shell.currentIndex,
                  height: navHeight,
                  onChanged: (i) => shell.goBranch(i, initialLocation: false),
                ),
              ),
            ),
    );
  }
}

class _BottomPillNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  const _BottomPillNav({
    required this.index,
    required this.onChanged,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => (v * s).toDouble();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(sp(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x22000000),
            blurRadius: sp(22),
            spreadRadius: sp(2),
            offset: Offset(0, sp(10)),
          ),
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: sp(8),
            offset: Offset(0, sp(2)),
          ),
        ],
        border: Border.fromBorderSide(
          const BorderSide(color: Color(0x11000000)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          final pad =
              (math.min(cons.maxWidth, height) / 375.0).clamp(0.85, 1.30) *
              6; // scala minima
          final slotW = (cons.maxWidth - pad * 2) / 4;
          return Stack(
            children: [
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
                    borderRadius: BorderRadius.circular(sp(22)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(pad),
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
    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => (v * s).toDouble();

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(sp(22)),
        child: Center(
          child: Icon(
            icon,
            size: sp(34),
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
