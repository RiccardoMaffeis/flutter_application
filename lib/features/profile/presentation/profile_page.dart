import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _fmtDob(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  Future<void> _onLogoutPressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LogoutDialog(),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();

      ref.invalidate(profileControllerProvider);
      if (context.mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prof = ref.watch(profileControllerProvider);

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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Profile',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 40,
                                ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _onLogoutPressed(context, ref),
                        icon: const Icon(Icons.logout, size: 35),
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 40),

                prof.when(
                  loading: () => const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const Expanded(
                    child: Center(child: Text('Accedi per vedere il profilo')),
                  ),
                  data: (p) => Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
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
                          const SizedBox(height: 40),

                          Container(
                            width: 400,
                            height: 275,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
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
                                  label: 'City',
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

            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _BottomPillNav(
                index: 3,
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

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Logout?',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
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
                    child: const Text(
                      'Yes',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );

    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 17,
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
