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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light neutral background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header grande + underline rossa
                // Top title centered with heavy weight
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Augmented Reality',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 39,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Accent underline under the title (ABB-like red bar)
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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

                const SizedBox(height: 14),

                // Vertical list of tappable AR choices (big chip-like tiles)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (final c in choices) ...[
                        _ChoiceTile(
                          choice: c,
                          onTap: () => context.push('/ar/select'), // Navigate to selection page
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),

                const Spacer(), // Pushes bottom content to the bottom
                const SizedBox(height: 86), // Reserve space above bottom pill nav
              ],
            ),

            // Floating circular button for the assistant, bottom-right
            Positioned(
              right: 16,
              bottom: 96,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  onTap: () => context.push('/assistant'),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.psychology_alt_outlined, size: 28),
                  ),
                ),
              ),
            ),

            // Bottom nav stile “pillola”
            // Custom "pill" bottom navigation with 4 slots and a sliding highlight
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _BottomPillNav(
                index: 2, // AR tab selected
                onChanged: (i) {
                  // Map indices to routes; ignore if already selected
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
    return Material(
      color: Colors.white,
      elevation: 6, // Card-like elevation
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Choice title (bold, prominent)
              Text(
                choice.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Right-side small preview image with graceful fallback icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _assetPath,
                  width: 56,
                  height: 40,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined,
                    size: 28,
                    color: Colors.black38,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 28), // Disclosure arrow
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom bottom navigation styled as a rounded "pill".
/// Shows 4 icons and animates a colored highlight under the selected one.
class _BottomPillNav extends StatelessWidget {
  final int index; // Currently selected tab index (0..3)
  final ValueChanged<int> onChanged; // Callback when a tab is tapped

  const _BottomPillNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          // Soft, elevated shadow stack for a floating effect
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
        border: Border.fromBorderSide(BorderSide(color: Color(0x11000000))),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          // Compute slot width for the sliding highlight
          const pad = 6.0;
          final slotW = (cons.maxWidth - pad * 2) / 4;

          return Stack(
            children: [
              // Animated colored capsule that moves to the selected slot
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

              // Row of tappable icons; color switches based on selection
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

/// Single nav icon that expands to fill its slot and toggles color when selected.
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
            color: selected ? Colors.white : Colors.black87, // Contrast with highlight
          ),
        ),
      ),
    );
  }
}
