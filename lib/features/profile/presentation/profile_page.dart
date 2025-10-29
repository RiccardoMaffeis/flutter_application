import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application/features/assistant/controllers/ai_chat_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:showcaseview/showcaseview.dart';               
import 'package:flutter_application/core/tour/coach_tour.dart'; 

import '../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';

/// Profile screen:
/// - Shows basic user info (name/email/DOB/city)
/// - Logout (dialog confirm, clears providers, go '/welcome')
/// - One-step coach mark on Logout + Help button to restart the tour
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _kLogout = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(coachTourServiceProvider).startOrQueue(
        context,
        TourSection.profile,
        [_kLogout],
      );
    });
  }

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
      ref.invalidate(aiChatControllerProvider);
      ref.invalidate(profileControllerProvider);
      if (!mounted) return;
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prof = ref.watch(profileControllerProvider);

    final media = MediaQuery.of(context);
    final size = media.size;
    final w = size.width;
    final shortest = size.shortestSide;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;

    final double headerTitle = (w * 0.09).clamp(sp(28.0), sp(40.0)) * ts;
    final double headerIcon  = (w * 0.085).clamp(sp(26.0), sp(35.0));
    final double sectionGap  = (w * 0.08).clamp(sp(28.0), sp(40.0));
    final double errorFont   = (w * 0.045).clamp(sp(14.0), sp(18.0)) * ts;

    final divider = Divider(
      height: sp(1),
      thickness: sp(1.2),
      color: const Color(0x44000000),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: sp(12), vertical: sp(6)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.help_outline, size: headerIcon),
                        onPressed: () => ref
                            .read(coachTourServiceProvider)
                            .startNow(context, [_kLogout]),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Profile',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: headerTitle,
                                ),
                          ),
                        ),
                      ),
                      Showcase(
                        key: _kLogout,
                        description:
                            'Log out of your account. You can sign in again later.',
                        overlayOpacity: 0.2,
                        targetPadding: const EdgeInsets.all(2),
                        child: IconButton(
                          onPressed: () => _onLogoutPressed(context, ref),
                          icon: Icon(Icons.logout, size: headerIcon),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: sp(4),
                  margin: EdgeInsets.symmetric(horizontal: sp(12)),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(sp(3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: sp(3),
                        spreadRadius: sp(0.4),
                        offset: Offset(0, sp(3)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),

                prof.when(
                  loading: () => const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Expanded(
                    child: Center(
                      child: Text(
                        'Login to view your profile',
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
                      padding: EdgeInsets.symmetric(horizontal: sp(16)),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Material(
                                shape: const CircleBorder(),
                                elevation: sp(8),
                                shadowColor: Colors.black,
                                clipBehavior: Clip.antiAlias,
                                child: CircleAvatar(
                                  radius: sp(80),
                                  backgroundColor: Colors.white,
                                  backgroundImage:
                                      (p.photoUrl != null) ? NetworkImage(p.photoUrl!) : null,
                                  child: (p.photoUrl == null)
                                      ? Icon(Icons.person, size: sp(85), color: Colors.black26)
                                      : null,
                                ),
                              ),
                              Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: sp(8),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(sp(6)),
                                    child: Icon(Icons.photo_camera_outlined, size: sp(32)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: sectionGap),

                          // Info card
                          Container(
                            constraints: BoxConstraints(maxWidth: sp(400)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(sp(18)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: sp(22),
                                  spreadRadius: sp(2),
                                  offset: Offset(0, sp(10)),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: sp(8),
                                  offset: Offset(0, sp(2)),
                                ),
                              ],
                              border: Border.all(color: const Color(0x11000000), width: sp(1)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ProfileRow(label: 'Name',         value: p.displayName),
                                divider,
                                _ProfileRow(label: 'Email',        value: p.email),
                                divider,
                                _ProfileRow(label: 'Date of Birth',value: _fmtDob(p.dob)),
                                divider,
                                _ProfileRow(label: 'City of Birth',value: p.city.isEmpty ? '—' : p.city),
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
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog for logout.
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final w = size.width;
    final shortest = size.shortestSide;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;

    final double dlgTitle = (w * 0.09).clamp(sp(24.0), sp(40.0)) * ts;
    final double btnFont  = (w * 0.05).clamp(sp(16.0), sp(20.0)) * ts;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: sp(28)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(sp(18))),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(sp(20), sp(26), sp(20), sp(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: sp(6)),
                Text('Logout?',
                  style: TextStyle(fontSize: dlgTitle, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: sp(18)),
                SizedBox(
                  width: sp(300),
                  height: sp(50),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: EdgeInsets.symmetric(vertical: sp(12)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(sp(22))),
                      elevation: 0,
                    ),
                    child: Text('Yes',
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
          Positioned(
            right: sp(6),
            top: sp(6),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
              splashRadius: sp(18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single labeled value row for the profile info card.
class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final w = size.width;
    final shortest = size.shortestSide;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;

    final double labelFont = (w * 0.038).clamp(sp(12.0), sp(16.0)) * ts;
    final double valueFont = (w * 0.042).clamp(sp(13.0), sp(17.0)) * ts;

    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: labelFont, fontWeight: FontWeight.w400, color: Colors.black,
    );

    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: valueFont, fontWeight: FontWeight.w600, color: Colors.black,
    );

    return ListTile(
      dense: false,
      minVerticalPadding: sp(10),
      contentPadding: EdgeInsets.symmetric(horizontal: sp(20), vertical: sp(6)),
      title: Text(label, style: labelStyle),
      trailing: Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
    );
  }
}
