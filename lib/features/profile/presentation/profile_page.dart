import 'package:flutter/material.dart';
import 'package:flutter_application/features/assistant/controllers/ai_chat_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';

/// Profile screen:
/// - Shows basic user info (name/email/DOB/city) from `profileControllerProvider`
/// - Lets the user log out (confirms via dialog, clears relevant providers)
/// - Uses a custom bottom pill navigation at the bottom
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  /// Formats a DateTime as DD/MM/YYYY (returns '—' if null).
  String _fmtDob(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  /// Handles logout:
  /// - Shows a blocking confirmation dialog
  /// - On confirm: Firebase signOut, invalidate chat/profile providers
  /// - Navigates to '/welcome' if still mounted
  Future<void> _onLogoutPressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LogoutDialog(),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      ref.invalidate(aiChatControllerProvider);
      ref.invalidate(profileControllerProvider);
      if (context.mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the profile async state (loading/data/error).
    final prof = ref.watch(profileControllerProvider);

    // ---- Responsive metrics (solo testi) ----
    // Compute text-only sizes based on screen width and clamped text scale.
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);

    final double headerTitle = (w * 0.09).clamp(28.0, 40.0) * ts;
    final double headerIcon = (w * 0.085).clamp(
      26.0,
      35.0,
    ); // icona (ok se resta fissa)
    final double sectionGap = (w * 0.08).clamp(28.0, 40.0);
    final double errorFont = (w * 0.045).clamp(14.0, 18.0) * ts;

    // Reusable divider for the info card rows.
    const divider = Divider(
      height: 1,
      thickness: 1.2,
      color: Color(0x44000000),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ----- Header with centered title and logout icon -----
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      // Fixed-width spacer to keep title centered.
                      const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Profile',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: headerTitle,
                                ),
                          ),
                        ),
                      ),
                      // Logout action opens the confirmation dialog.
                      IconButton(
                        onPressed: () => _onLogoutPressed(context, ref),
                        icon: Icon(Icons.logout, size: headerIcon),
                      ),
                    ],
                  ),
                ),
                // Accent bar under header (brand color).
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
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
                SizedBox(height: sectionGap),

                // ----- Profile content: loading/error/data states -----
                prof.when(
                  // Full-height loader.
                  loading: () => const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  // Error: ask to log in (original Italian copy preserved).
                  error: (e, _) => Expanded(
                    child: Center(
                      child: Text(
                        'Accedi per vedere il profilo',
                        style: TextStyle(
                          fontSize: errorFont,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  data: (p) => Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Avatar with camera overlay button (upload TODO).
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Material(
                                shape: const CircleBorder(),
                                elevation: 8,
                                shadowColor: Colors.black,
                                clipBehavior: Clip.antiAlias,
                                child: CircleAvatar(
                                  radius: 80,
                                  backgroundColor: Colors.white,
                                  backgroundImage: (p.photoUrl != null)
                                      ? NetworkImage(p.photoUrl!)
                                      : null,
                                  child: (p.photoUrl == null)
                                      ? const Icon(
                                          Icons.person,
                                          size: 85,
                                          color: Colors.black26,
                                        )
                                      : null,
                                ),
                              ),

                              // Placeholder action for profile photo change.
                              Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 8,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    // TODO: selezione/Upload foto profilo
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.photo_camera_outlined,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: sectionGap),

                          // Card with profile details (name/email/dob/city).
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [/* ... */],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ProfileRow(
                                  label: 'Name',
                                  value: p.displayName,
                                ),
                                divider,
                                _ProfileRow(label: 'Email', value: p.email),
                                divider,
                                _ProfileRow(
                                  label: 'Date of Birth',
                                  value: _fmtDob(p.dob),
                                ),
                                divider,
                                _ProfileRow(
                                  label: 'City of Birth',
                                  value: p.city.isEmpty ? '—' : p.city,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ----- Bottom pill navigation (fixed) -----
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _BottomPillNav(
                index: 3, // Profile tab selected.
                onChanged: (i) {
                  if (i == 0) context.go('/home');
                  if (i == 1) context.go('/favourites');
                  if (i == 3) return;
                  if (i == 2) context.go('/ar');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog for logout.
/// - Large title
/// - "Yes" button returns true
/// - Close icon (top-right) returns false
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);

    final double dlgTitle = (w * 0.09).clamp(24.0, 40.0) * ts;
    final double btnFont = (w * 0.05).clamp(16.0, 20.0) * ts;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Text(
                  'Logout?',
                  style: TextStyle(
                    fontSize: dlgTitle,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Yes',
                      style: TextStyle(
                        fontSize: btnFont,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Close icon (dismiss = false)
          Positioned(
            right: 6,
            top: 6,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single labeled value row for the profile info card.
/// - Left-aligned label, right-aligned value (ellipsized)
class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);

    final double labelFont = (w * 0.038).clamp(12.0, 16.0) * ts;
    final double valueFont = (w * 0.042).clamp(13.0, 17.0) * ts;

    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: labelFont,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );

    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: valueFont,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );

    return ListTile(
      dense: false,
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(label, style: labelStyle),
      trailing: Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
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
