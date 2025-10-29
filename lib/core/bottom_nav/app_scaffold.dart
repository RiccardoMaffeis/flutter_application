import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application/core/bottom_nav/global_ui_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_application/core/tour/coach_tour.dart';

/// AppScaffold
/// - Hosts the nested navigation shell (GoRouter's StatefulNavigationShell)
/// - Draws a floating Assistant button
/// - Shows a custom bottom "pill" navigation bar
/// - Triggers a one-time guided tour for the bottom navigation
class AppScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  const AppScaffold({super.key, required this.shell});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  // Showcase keys for the bottom navigation and assistant FAB
  final _kTabShop = GlobalKey();
  final _kTabFavourites = GlobalKey();
  final _kTabAR = GlobalKey();
  final _kTabProfile = GlobalKey();
  final _kAssistant = GlobalKey();

  // Prevents scheduling the nav tour multiple times per mount
  bool _navTourScheduled = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mq = MediaQuery.of(context);
    final w = size.width;
    final shortest = math.min(size.width, size.height);
    // Responsive scaler relative to a 375pt logical device
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => (v * s).toDouble();

    // Current route location (used to decide when to hide chrome)
    final location = GoRouterState.of(context).uri.toString();
    final bool isArDetails =
        location.startsWith('/ar/xt') || location.startsWith('/ar/emax');

    // Global UI flags (hide chrome while searching or on certain pages)
    final bool hideChrome = ref.watch(hideChromeProvider);
    final bool hideNav = isArDetails || hideChrome;

    // Schedule the bottom nav tour only once and only if the nav is visible
    if (!_navTourScheduled && !hideNav) {
      _navTourScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(coachTourServiceProvider).startOrQueue(
          context,
          TourSection.nav,
          [_kTabShop, _kTabFavourites, _kTabAR, _kTabProfile, _kAssistant],
        );
      });
    }

    // Sizes for nav and assistant FAB
    final navHeight = sp(58);
    final btnSize = (w * 0.12).clamp(sp(40.0), sp(52.0)).toDouble();

    // Assistant FAB offset adapts when bottom nav is hidden
    final double assistantBottomOffset = hideNav
        ? (mq.padding.bottom + sp(30))
        : (navHeight + mq.padding.bottom + sp(30));

    return Scaffold(
      extendBody: true, // allow content under the rounded bottom nav shadow
      backgroundColor: const Color(0xFFF5F5F7),

      body: Stack(
        children: [
          // Body is the nested navigation shell
          Positioned.fill(child: widget.shell),

          // Floating Assistant button (hidden on AR details or when chrome is hidden)
          if (!hideNav)
            Positioned(
              right: sp(16),
              bottom: assistantBottomOffset,
              child: Showcase(
                key: _kAssistant,
                description:
                    'Open the in-app Assistant.\nAsk about datasheets, manuals and specs.',
                overlayOpacity: 0.2,
                targetPadding: const EdgeInsets.all(6),
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
                        // Scale the chatbot image inside the circular button
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
            ),
        ],
      ),

      // Rounded "pill" bottom navigation; hidden on AR details or when chrome is hidden
      bottomNavigationBar: hideNav
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(sp(16), sp(8), sp(16), sp(16)),
                child: _BottomPillNav(
                  index: widget.shell.currentIndex,
                  height: sp(58),
                  onChanged: (i) =>
                      widget.shell.goBranch(i, initialLocation: false),
                  kShop: _kTabShop,
                  kFavourites: _kTabFavourites,
                  kAR: _kTabAR,
                  kProfile: _kTabProfile,
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

  // Showcase keys for each tab
  final GlobalKey kShop;
  final GlobalKey kFavourites;
  final GlobalKey kAR;
  final GlobalKey kProfile;

  const _BottomPillNav({
    required this.index,
    required this.onChanged,
    required this.height,
    required this.kShop,
    required this.kFavourites,
    required this.kAR,
    required this.kProfile,
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
          // Soft layered elevation for a floating pill look
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
          // Horizontal padding scales with available width/height
          final pad =
              (math.min(cons.maxWidth, height) / 375.0).clamp(0.85, 1.30) * 6;
          final slotW = (cons.maxWidth - pad * 2) / 4;

          return Stack(
            children: [
              // Animated selection highlight sliding under the active tab
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

              // Four evenly spaced tab icons with Showcase wrappers
              Padding(
                padding: EdgeInsets.all(pad),
                child: Row(
                  children: [
                    Showcase(
                      key: kShop,
                      description: 'Shop: browse ABB products and categories.',
                      overlayOpacity: 0.2,
                      targetPadding: const EdgeInsets.all(2),
                      child: _NavIcon(
                        icon: Icons.shopping_bag_outlined,
                        selected: index == 0,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    Showcase(
                      key: kFavourites,
                      description:
                          'Favourites: save items to revisit or compare later.',
                      overlayOpacity: 0.2,
                      targetPadding: const EdgeInsets.all(2),
                      child: _NavIcon(
                        icon: Icons.favorite_border,
                        selected: index == 1,
                        onTap: () => onChanged(1),
                      ),
                    ),
                    Showcase(
                      key: kAR,
                      description: 'AR: place 3D models in your environment.',
                      overlayOpacity: 0.2,
                      targetPadding: const EdgeInsets.all(2),
                      child: _NavIcon(
                        icon: Icons.view_in_ar,
                        selected: index == 2,
                        onTap: () => onChanged(2),
                      ),
                    ),
                    Showcase(
                      key: kProfile,
                      description:
                          'Profile: account, preferences and settings.',
                      overlayOpacity: 0.2,
                      targetPadding: const EdgeInsets.all(2),
                      child: _NavIcon(
                        icon: Icons.person_outline,
                        selected: index == 3,
                        onTap: () => onChanged(3),
                      ),
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
