import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../../../../core/theme/app_theme.dart';

/// Signup screen:
/// - Collects profile info (name, city, DOB) + email & password
/// - Validates fields locally
/// - Calls the auth controller to create the account
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});
  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  // Form & field controllers
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _dobText = TextEditingController();

  // In-memory selected date of birth (rendered into _dobText)
  DateTime? _dob;

  // Toggles for password visibility
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _dobText.dispose();
    super.dispose();
  }

  /// Opens a Material date picker, constrained to past dates.
  /// The chosen date is formatted into dd/MM/yyyy and shown in the read-only field.
  Future<void> _pickDobMaterial() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? today,
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
      currentDate: today,
      helpText: 'Select your date of birth',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: Colors.white,
              headerForegroundColor: Colors.black87,
            ),
            colorScheme: theme.colorScheme.copyWith(
              primary: AppTheme.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobText.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  /// Reusable rounded (pill) button with haptics and ripple feedback.
  Widget _pillButton({
    required String label,
    required VoidCallback onPressed,
    double width = 240,
    double height = 45,
    double radius = 24,
    double fontSize = 25,
  }) {
    final btn = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: EdgeInsets.zero,
        minimumSize: Size(width, height),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
      ),
      onPressed: () {
        Feedback.forTap(context);
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Text(label),
    );
    return SizedBox(width: width, height: height, child: btn);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

            // ---- Responsive scale & helpers ----
            final shortest = math.min(w, h);
            final s = (shortest / 375.0).clamp(0.85, 1.30);
            double sp(double v) => v * s;

            // ---- Responsive metrics ----
            final double maxContentW = (w - sp(32))
                .clamp(sp(300.0), sp(540.0))
                .toDouble();
            final double titleSize = (w * 0.11)
                .clamp(sp(28.0), sp(50.0))
                .toDouble();

            final double mainBtnW = (w * 0.60)
                .clamp(sp(180.0), sp(360.0))
                .toDouble();
            final double mainBtnH = (h * 0.055)
                .clamp(sp(40.0), sp(58.0))
                .toDouble();
            final double mainBtnFont = (w * 0.06)
                .clamp(sp(18.0), sp(24.0))
                .toDouble();

            final double footerFont = (w * 0.045)
                .clamp(sp(13.0), sp(16.0))
                .toDouble();
            final double footerBtnW = (w * 0.36)
                .clamp(sp(120.0), sp(220.0))
                .toDouble();
            final double footerBtnH = (h * 0.05)
                .clamp(sp(36.0), sp(54.0))
                .toDouble();
            final double footerBtnFont = (w * 0.05)
                .clamp(sp(16.0), sp(20.0))
                .toDouble();

            final double topPad = (h * 0.02)
                .clamp(sp(12.0), sp(24.0))
                .toDouble();
            final double betweenTitlePad = (h * 0.02)
                .clamp(sp(12.0), sp(20.0))
                .toDouble();
            final double afterFormPad = (h * 0.02)
                .clamp(sp(12.0), sp(24.0))
                .toDouble();

            // Responsive fonts for fields/messages/errors
            final double labelFont = (w * 0.045)
                .clamp(sp(14.0), sp(18.0))
                .toDouble();
            final double fieldFont = (w * 0.05)
                .clamp(sp(15.0), sp(19.0))
                .toDouble();
            final double errorFont = (w * 0.04)
                .clamp(sp(12.0), sp(16.0))
                .toDouble();
            final double snackFont = (w * 0.04)
                .clamp(sp(12.0), sp(16.0))
                .toDouble();

            // Scaled divider (instead of const)
            Divider divider = Divider(
              height: sp(1),
              thickness: sp(1.2),
              color: const Color(0x44000000),
            );

            // ---- Main card (responsive) ----
            final card = Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: sp(6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sp(24)),
              ),
              margin: EdgeInsets.all(sp(16)),
              child: Padding(
                padding: EdgeInsets.fromLTRB(sp(20), sp(24), sp(20), sp(20)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: (h * 0.007).clamp(sp(4.0), sp(10.0)).toDouble(),
                      ),
                      Text(
                        'Signup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: betweenTitlePad),

                      // Name
                      TextFormField(
                        controller: _name,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
                          border: InputBorder.none,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      divider,

                      // Date of Birth
                      TextFormField(
                        controller: _dobText,
                        readOnly: true,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            onPressed: _pickDobMaterial,
                            icon: const Icon(Icons.calendar_today_outlined),
                            tooltip: 'Select date',
                          ),
                        ),
                        onTap: _pickDobMaterial,
                        validator: (_) => _dob == null
                            ? 'Please select your date of birth'
                            : null,
                      ),
                      // (rimosso il doppio divider fisso)
                      divider,

                      // City
                      TextFormField(
                        controller: _city,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'City of Birth',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
                          border: InputBorder.none,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'City is required'
                            : null,
                      ),
                      divider,

                      // Email
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
                          border: InputBorder.none,
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      divider,

                      // Password
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePwd,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            tooltip: _obscurePwd
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscurePwd = !_obscurePwd),
                            icon: Icon(
                              _obscurePwd
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = v ?? '';
                          final ok =
                              s.length >= 8 &&
                              RegExp(r'[A-Z]').hasMatch(s) &&
                              RegExp(r'[a-z]').hasMatch(s) &&
                              RegExp(r'\d').hasMatch(s) &&
                              RegExp(r'[^A-Za-z0-9]').hasMatch(s);
                          return ok
                              ? null
                              : 'Password does not match the requirements';
                        },
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      divider,
                      _PasswordChecklist(controller: _password),

                      SizedBox(height: sp(2)),

                      // Confirm Password
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscureConfirm,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => v != _password.text
                            ? 'Passwords do not match'
                            : null,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      divider,

                      SizedBox(height: afterFormPad),

                      if (auth.isLoading)
                        const CircularProgressIndicator()
                      else
                        _pillButton(
                          label: 'Next',
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            try {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .signUp(
                                    _email.text.trim(),
                                    _password.text,
                                    name: _name.text.trim(),
                                    city: _city.text.trim(),
                                    dateOfBirth: _dob,
                                  );
                              if (!mounted) return;
                            } on fb.FirebaseAuthException catch (e) {
                              if (!mounted) return;
                              final msg = switch (e.code) {
                                'weak-password' =>
                                  'Password too weak (min 8 characters).',
                                'email-already-in-use' =>
                                  'Email already registered.',
                                'invalid-email' => 'Invalid email.',
                                _ => 'Sign up failed: ${e.code}',
                              };
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    msg,
                                    style: TextStyle(fontSize: snackFont),
                                  ),
                                ),
                              );
                            }
                          },
                          width: mainBtnW,
                          height: mainBtnH,
                          fontSize: mainBtnFont,
                          radius: sp(24),
                        ),
                    ],
                  ),
                ),
              ),
            );

            // ---- Page layout: scrollable center + bottom CTA ----
            return Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      sp(5),
                      topPad,
                      sp(5),
                      (kbOpen ? topPad : sp(84.0)),
                    ),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentW),
                        child: card,
                      ),
                    ),
                  ),
                ),

                // Bottom CTA to navigate to login (hidden when keyboard is open)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: sp(16),
                  right: sp(16),
                  bottom: kbOpen ? -sp(200) : sp(20),
                  child: Offstage(
                    offstage: kbOpen,
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: sp(8),
                        runSpacing: sp(8),
                        children: [
                          Text(
                            'Already have an account?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: footerFont,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(
                            width: footerBtnW,
                            child: _pillButton(
                              label: 'Login',
                              onPressed: () => context.go('/login'),
                              width: footerBtnW,
                              height: footerBtnH,
                              fontSize: footerBtnFont,
                              radius: sp(24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Visual, real-time password checklist (green/red rules) that listens to the
/// password field and animates state changes for each requirement line.
class _PasswordChecklist extends StatelessWidget {
  final TextEditingController controller;
  const _PasswordChecklist({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Responsive sizes
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final shortest = math.min(w, h);
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;

    final double rowFont = (w * 0.04).clamp(sp(12.0), sp(16.0)).toDouble();
    final double iconSize = (w * 0.045).clamp(sp(16.0), sp(20.0)).toDouble();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final pwd = value.text;

        final hasMin = pwd.length >= 8;
        final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
        final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
        final hasNumber = RegExp(r'\d').hasMatch(pwd);
        final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);

        if (pwd.isEmpty) return const SizedBox.shrink();

        Widget item(bool ok, String label) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Row(
            key: ValueKey('$label-$ok'),
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.cancel,
                size: iconSize,
                color: ok ? Colors.green : Colors.red,
              ),
              SizedBox(width: sp(8)),
              Text(
                label,
                style: TextStyle(
                  fontSize: rowFont,
                  color: ok ? Colors.black87 : Colors.black54,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: sp(12), vertical: sp(10)),
          margin: EdgeInsets.only(top: sp(6), bottom: sp(6)),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(sp(12)),
            border: Border.all(color: const Color(0x22000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(hasMin, 'At least 8 characters'),
              item(hasUpper, 'One uppercase letter'),
              item(hasLower, 'One lowercase letter'),
              item(hasNumber, 'One number'),
              item(hasSpecial, 'One special character'),
            ],
          ),
        );
      },
    );
  }
}
