import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // Form key and text controllers for email/password fields
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Toggles password visibility
  bool _obscurePassword = true;

  // Inline error holders for form fields (driven by validators)
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Displays a single generic credential error under the password field.
  /// This keeps error messaging consistent without revealing which field is wrong.
  void _showGenericCredsError() {
    setState(() {
      _emailError = null;
      _passwordError = 'Incorrect email and/or password.';
    });
    _formKey.currentState?.validate();
  }

  /// Opens the default mail app with a pre-filled email (subject/body).
  /// Falls back to copying the address to the clipboard if launching fails.
  Future<void> _openSupportEmail() async {
    String _encodeQueryParams(Map<String, String> params) {
      return params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
    }

    final uri = Uri(
      scheme: 'mailto',
      path: 'r.maffeis4@studenti.unibg.it',
      query: _encodeQueryParams({
        'subject': 'App support',
        'body': 'Hi, I need help with ...\nThanks!',
      }),
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'cannot launch';
    } catch (_) {
      await Clipboard.setData(
        const ClipboardData(text: 'r.maffeis4@studenti.unibg.it'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "I couldn't open your email app. Address copied to clipboard.",
          ),
        ),
      );
    }
  }

  /// Shows a bottom sheet confirming a reset email was (potentially) sent.
  /// Uses neutral wording to avoid leaking whether an email exists.
  Future<void> showResetSentSheet(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: AppTheme.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check your email',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "If the address is registered, we've sent you a link to reset your password (check spam).",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Attempts to sign in and performs a lightweight retry if Firebase returns
  /// `invalid-credential`, which can happen due to anti-abuse checks.
  Future<void> _signInWithRetry(String email, String pwd) async {
    try {
      await ref.read(authControllerProvider.notifier).signIn(email, pwd);
      return;
    } on fb.FirebaseAuthException catch (e1) {
      if (e1.code == 'invalid-credential') {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          await ref.read(authControllerProvider.notifier).signIn(email, pwd);
          return;
        } on fb.FirebaseAuthException catch (e2) {
          _handleAuthException(e2);
          return;
        }
      }
      _handleAuthException(e1);
    }
  }

  /// Maps Firebase auth errors to user feedback.
  /// Credential-related errors show the same generic message.
  void _handleAuthException(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-disabled':
        _showGenericCredsError();
        break;
      case 'too-many-requests':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Too many attempts. Try again later.')),
        );
        break;
      case 'network-request-failed':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No connection. Please check your network.'),
          ),
        );
        break;
      default:
        _showGenericCredsError();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for loading indicator during sign-in
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Viewport sizes
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;

            // ---- Responsive metrics ----
            final double maxContentW = (w - 32).clamp(300.0, 460.0);
            final double titleSize = (w * 0.11).clamp(28.0, 50.0);
            final double mainBtnW = (w * 0.60).clamp(180.0, 320.0);
            final double mainBtnH = (h * 0.055).clamp(40.0, 54.0);
            final double mainBtnFont = (w * 0.06).clamp(18.0, 24.0);

            final double linkFont = (w * 0.045).clamp(14.0, 18.0);
            final double footerFont = (w * 0.045).clamp(13.0, 16.0);
            final double footerBtnW = (w * 0.36).clamp(120.0, 200.0);
            final double footerBtnH = (h * 0.05).clamp(36.0, 48.0);
            final double footerBtnFont = (w * 0.05).clamp(16.0, 20.0);

            // Shared link-styled button used for "Need support?" and "Forgot your password?"
            final ButtonStyle linkStyle =
                TextButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: TextStyle(
                    fontSize: linkFont,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w900,
                  ),
                ).copyWith(
                  overlayColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return Colors.black.withOpacity(0.06);
                    }
                    if (states.contains(MaterialState.hovered) ||
                        states.contains(MaterialState.focused)) {
                      return Colors.black.withOpacity(0.04);
                    }
                    return null;
                  }),
                  splashFactory: InkRipple.splashFactory,
                );

            // Reusable rounded (pill) button for primary actions.
            Widget pillButton({
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
                ),
                onPressed: () {
                  Feedback.forTap(context);
                  HapticFeedback.selectionClick();
                  onPressed();
                },
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
              return SizedBox(width: width, height: height, child: btn);
            }

            InputBorder underline() => const UnderlineInputBorder(
              borderSide: BorderSide(width: 1, color: Color(0x44000000)),
            );

            // Main login card with form fields and submit action
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
                        'Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: (h * 0.02).clamp(12.0, 20.0)),

                      // Email
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: InputBorder.none,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return _emailError;
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: underline().borderSide.color,
                      ),

                      // Password
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Enter your password';
                          return _passwordError; // shows "Incorrect email and/or password."
                        },
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      Divider(
                        height: 1,
                        thickness: 1.2,
                        color: underline().borderSide.color,
                      ),

                      SizedBox(height: (h * 0.025).clamp(14.0, 24.0)),

                      // Show loading indicator during auth operations, else show submit button
                      if (auth.isLoading)
                        const CircularProgressIndicator()
                      else
                        pillButton(
                          label: 'Next',
                          onPressed: () async {
                            setState(() {
                              _emailError = null;
                              _passwordError = null;
                            });
                            if (!_formKey.currentState!.validate()) return;

                            final email = _email.text.trim();
                            final pwd = _password.text;

                            try {
                              await _signInWithRetry(email, pwd);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unexpected error: $e')),
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

            // Support links under the form
            final supportLinks = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    Feedback.forTap(context);
                    HapticFeedback.selectionClick();
                    await _openSupportEmail();
                  },
                  style: linkStyle,
                  child: const Text('Need support?'),
                ),
                SizedBox(height: (h * 0.004).clamp(2.0, 6.0)),
                TextButton(
                  onPressed: () async {
                    Feedback.forTap(context);
                    HapticFeedback.selectionClick();

                    final result = await showDialog<bool>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) =>
                          ResetPasswordDialog(initialEmail: _email.text.trim()),
                    );

                    if (result == true && mounted) {
                      await showResetSentSheet(context);
                    }
                  },
                  style: linkStyle,
                  child: const Text('Forgot your password?'),
                ),
              ],
            );

            return Stack(
              children: [
                // Centered, scrollable content to avoid overflow on small screens / with keyboard
                Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: (h * 0.02).clamp(12.0, 24.0),
                      bottom: (kbOpen ? (h * 0.02).clamp(12.0, 24.0) : 84.0),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentW),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            card,
                            SizedBox(height: (h * 0.006).clamp(4.0, 10.0)),
                            supportLinks,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom CTA to navigate to signup (hidden when keyboard is open)
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
                            'Need an account?',
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
                            child: pillButton(
                              label: 'Sign up',
                              onPressed: () => context.go('/signup'),
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

/// Dialog for requesting a password reset email.
/// Shows validation errors inline and disables actions while sending.
class ResetPasswordDialog extends ConsumerStatefulWidget {
  final String initialEmail;
  const ResetPasswordDialog({super.key, required this.initialEmail});

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  // Local controller for the email field inside the dialog
  late final TextEditingController _emailCtrl;

  // Inline error text and sending state
  String? _errorText;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Validates and submits a password reset request via the auth controller.
  /// On success, closes the dialog returning `true`.
  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email');
      return;
    }

    setState(() {
      _sending = true;
      _errorText = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on fb.FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-email' => 'Invalid email.',
        'user-not-found' => 'No account found for this email.',
        _ => "Couldn't send email: ${e.code}",
      };
      if (!mounted) return;
      setState(() {
        _errorText = msg;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Unexpected error: $e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Enter your email: we'll send you a link to reset your password.",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: _errorText,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}
