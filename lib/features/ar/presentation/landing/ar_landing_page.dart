import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../ar/controllers/ar_landing_controller.dart';
import '../../../ar/domain/ar_choice.dart';

class ARLandingPage extends ConsumerWidget {
  const ARLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(arLandingControllerProvider).choices;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header grande + underline rossa
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

                // Lista scelte (due “big chips”)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (final c in choices) ...[
                        _ChoiceTile(
                          choice: c,
                          onTap: () => context.push('/ar/select'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),

                const Spacer(),
                const SizedBox(height: 86),
              ],
            ),

            // Bubble AI in basso a destra
            Positioned(
              right: 16,
              bottom: 96,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  onTap: () {
                    // TODO: apri il tuo assistant (es. /assistant)
                  },
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
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

class _ChoiceTile extends StatelessWidget {
  final ARChoice choice;
  final VoidCallback onTap;

  const _ChoiceTile({required this.choice, required this.onTap});

  /// Forza: lib/images/general/<basename>.png
  String get _assetPath {
    final base = choice.asset.split('/').last; // prendi solo il nome
    final name = base.endsWith('.png') ? base : '$base.png';
    return 'lib/images/general/$name';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
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
              Text(
                choice.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
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
              const Icon(Icons.chevron_right, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

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
        border: Border.fromBorderSide(BorderSide(color: Color(0x11000000))),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, cons) {
          const pad = 6.0;
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
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),

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
