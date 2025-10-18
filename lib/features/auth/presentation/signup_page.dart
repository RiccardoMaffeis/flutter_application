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

    const divider = Divider(
      height: 1,
      thickness: 1.2,
      color: Color(0x44000000),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

            // ---- Responsive metrics ----
            final double maxContentW = (w - 32).clamp(300.0, 460.0);
            final double titleSize = (w * 0.11).clamp(28.0, 50.0);

            final double mainBtnW = (w * 0.60).clamp(180.0, 320.0);
            final double mainBtnH = (h * 0.055).clamp(40.0, 54.0);
            final double mainBtnFont = (w * 0.06).clamp(18.0, 24.0);

            final double footerFont = (w * 0.045).clamp(13.0, 16.0);
            final double footerBtnW = (w * 0.36).clamp(120.0, 200.0);
            final double footerBtnH = (h * 0.05).clamp(36.0, 48.0);
            final double footerBtnFont = (w * 0.05).clamp(16.0, 20.0);
            final double topPad = (h * 0.02).clamp(12.0, 24.0);
            final double betweenTitlePad = (h * 0.02).clamp(12.0, 20.0);
            final double afterFormPad = (h * 0.02).clamp(12.0, 24.0);

            // NEW: responsive fonts for fields/messages/errors
            final double labelFont = (w * 0.045).clamp(14.0, 18.0);
            final double fieldFont = (w * 0.05).clamp(15.0, 19.0);
            final double errorFont = (w * 0.04).clamp(12.0, 16.0);
            final double snackFont = (w * 0.04).clamp(12.0, 16.0);

            // ---- Main card (responsive) ----
            final card = Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: (h * 0.007).clamp(4.0, 10.0)),
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
                      const Divider(
                        height: 1,
                        thickness: 1.2,
                        color: Color(0x44000000),
                      ),

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

                      const SizedBox(height: 2),

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
                          radius: 24,
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
                      5,
                      topPad,
                      5,
                      (kbOpen ? topPad : 84.0),
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
                  left: 16,
                  right: 16,
                  bottom: kbOpen ? -200 : 20,
                  child: Offstage(
                    offstage: kbOpen,
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
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
                              radius: 24,
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
    final w = MediaQuery.of(context).size.width;
    final double rowFont = (w * 0.04).clamp(12.0, 16.0);
    final double iconSize = (w * 0.045).clamp(16.0, 20.0);

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
              const SizedBox(width: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(12),
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
