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
    // Helper to encode query parameters according to URL encoding rules
    String _encodeQueryParams(Map<String, String> params) {
      return params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
    }

    // Build a mailto: URI with subject and body
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
      // Fallback: copy email to clipboard and inform the user
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
      // Small retry helps with transient 'invalid-credential' responses.
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
      // Treat all credential problems as the same UI error
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-disabled':
        _showGenericCredsError();
        break;

      // Show specific, non-sensitive errors for rate limits / network
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

      // Default fallback: generic credentials error
      default:
        _showGenericCredsError();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for loading indicator during sign-in
    final auth = ref.watch(authControllerProvider);

    // Shared link-styled button used for "Need support?" and "Forgot your password?"
    final ButtonStyle linkStyle =
        TextButton.styleFrom(
          foregroundColor: Colors.black87,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 16,
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

    /// Reusable rounded (pill) button for primary actions.
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
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
        ),
      );
      return SizedBox(width: width, height: height, child: btn);
    }

    // Thin underline used as a divider border color reference
    InputBorder underline() => const UnderlineInputBorder(
      borderSide: BorderSide(width: 1, color: Color(0x44000000)),
    );

    // Main login card with form fields and submit action
    final card = Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Login',
                style: TextStyle(fontSize: 50, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),

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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
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

              const SizedBox(height: 20),

              // Show loading indicator during auth operations, else show submit button
              if (auth.isLoading)
                const CircularProgressIndicator()
              else
                pillButton(
                  label: 'Next',
                  onPressed: () async {
                    // Clear previous inline errors
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
                ),
            ],
          ),
        ),
      ),
    );

    // Support links under the form: contact support and reset password
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

        const SizedBox(height: 3),
        TextButton(
          onPressed: () async {
            Feedback.forTap(context);
            HapticFeedback.selectionClick();

            // Open reset password dialog (prefill with current email field text)
            final result = await showDialog<bool>(
              context: context,
              barrierDismissible: true,
              builder: (_) =>
                  ResetPasswordDialog(initialEmail: _email.text.trim()),
            );

            // On success, show a confirmation bottom sheet
            if (result == true && mounted) {
              await showResetSentSheet(context);
            }
          },
          style: linkStyle,
          child: const Text('Forgot your password?'),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Centered card + support links wrapper (constrained width)
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    card,
                    const SizedBox(height: 1),
                    supportLinks,
                  ],
                ),
              ),
            ),

            // Bottom CTA to navigate to signup (hidden when keyboard is open)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: 16,
              right: 16,
              bottom: 20 - MediaQuery.of(context).viewInsets.bottom,
              child: Offstage(
                offstage: MediaQuery.of(context).viewInsets.bottom > 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Need an account?',
                      style: TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    pillButton(
                      label: 'Sign up',
                      onPressed: () => context.go('/signup'),
                      width: 140,
                      height: 40,
                      fontSize: 20,
                      radius: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        // Close without action
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        // Submit action (shows a small progress indicator while sending)
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
