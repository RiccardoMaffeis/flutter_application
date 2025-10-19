import 'dart:math' as math;
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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showGenericCredsError() {
    setState(() {
      _emailError = null;
      _passwordError = 'Incorrect email and/or password.';
    });
    _formKey.currentState?.validate();
  }

  Future<void> _openSupportEmail() async {
    String _enc(Map<String, String> p) => p.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final uri = Uri(
      scheme: 'mailto',
      path: 'r.maffeis4@studenti.unibg.it',
      query: _enc({
        'subject': 'App support',
        'body': 'Hi, I need help with ...\nThanks!',
      }),
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'cannot launch';
    } catch (_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final s =
          (math.min(size.width, size.height) / 375.0).clamp(0.85, 1.30);
      double sp(double v) => v * s;
      final snackFont = (size.width * 0.04).clamp(sp(12), sp(16)).toDouble();
      await Clipboard.setData(
        const ClipboardData(text: 'r.maffeis4@studenti.unibg.it'),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "I couldn't open your email app. Address copied to clipboard.",
            style: TextStyle(fontSize: snackFont),
          ),
        ),
      );
    }
  }

  Future<void> showResetSentSheet(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        final size = MediaQuery.of(context).size;
        final w = size.width, h = size.height;
        final s = (math.min(w, h) / 375.0).clamp(0.85, 1.30);
        double sp(double v) => v * s;

        final sheetTitle = (w * 0.055).clamp(sp(18), sp(22)).toDouble();
        final sheetBody = (w * 0.045).clamp(sp(14), sp(18)).toDouble();
        final sheetBtn = (w * 0.05).clamp(sp(16), sp(20)).toDouble();

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(sp(24))),
            ),
            padding: EdgeInsets.fromLTRB(sp(20), sp(24), sp(20), sp(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: sp(64),
                  height: sp(64),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: AppTheme.accent,
                    size: sp(36),
                  ),
                ),
                SizedBox(height: sp(16)),
                Text(
                  'Check your email',
                  style: TextStyle(
                    fontSize: sheetTitle,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: sp(8)),
                Text(
                  "If the address is registered, we've sent you a link to reset your password (check spam).",
                  style: TextStyle(fontSize: sheetBody),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: sp(16)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(sp(14)),
                      ),
                      minimumSize: Size.fromHeight(sp(48)),
                      textStyle: TextStyle(fontSize: sheetBtn),
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

  void _handleAuthException(fb.FirebaseAuthException e) {
    final size = MediaQuery.of(context).size;
    final s =
        (math.min(size.width, size.height) / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;
    final snackFont = (size.width * 0.04).clamp(sp(12), sp(16)).toDouble();

    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-disabled':
        _showGenericCredsError();
        break;
      case 'too-many-requests':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Try again later.',
              style: TextStyle(fontSize: snackFont),
            ),
          ),
        );
        break;
      case 'network-request-failed':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No connection. Please check your network.',
              style: TextStyle(fontSize: snackFont),
            ),
          ),
        );
        break;
      default:
        _showGenericCredsError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final mq = MediaQuery.of(context);
    final kbOpen = mq.viewInsets.bottom > 0;

    return Scaffold(
      // comportamento allineato al Signup: il body NON viene ridimensionato dalla tastiera
      resizeToAvoidBottomInset: false,

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            final s = (math.min(w, h) / 375.0).clamp(0.85, 1.30);
            double sp(double v) => v * s;

            // ---- Metrics ----
            final maxContentW = (w - sp(32)).clamp(sp(300), sp(540)).toDouble();
            final titleSize = (w * 0.11).clamp(sp(28), sp(50)).toDouble();
            final mainBtnW = (w * 0.60).clamp(sp(180), sp(360)).toDouble();
            final mainBtnH = (h * 0.055).clamp(sp(40), sp(58)).toDouble();
            final mainBtnFont = (w * 0.06).clamp(sp(18), sp(24)).toDouble();
            final linkFont = (w * 0.045).clamp(sp(14), sp(18)).toDouble();
            final footerFont = (w * 0.045).clamp(sp(13), sp(16)).toDouble();
            final footerBtnW = (w * 0.36).clamp(sp(120), sp(220)).toDouble();
            final footerBtnH = (h * 0.05).clamp(sp(36), sp(54)).toDouble();
            final footerBtnFont = (w * 0.05).clamp(sp(16), sp(20)).toDouble();
            final labelFont = (w * 0.045).clamp(sp(14), sp(18)).toDouble();
            final fieldFont = (w * 0.05).clamp(sp(15), sp(19)).toDouble();
            final errorFont = (w * 0.04).clamp(sp(12), sp(16)).toDouble();

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
                    if (states.contains(MaterialState.pressed))
                      return Colors.black.withOpacity(0.06);
                    if (states.contains(MaterialState.hovered) ||
                        states.contains(MaterialState.focused)) {
                      return Colors.black.withOpacity(0.04);
                    }
                    return null;
                  }),
                  splashFactory: InkRipple.splashFactory,
                );

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
                  elevation: sp(3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: Size(width, height),
                  textStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w400,
                  ),
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

            InputBorder underline() => UnderlineInputBorder(
              borderSide: BorderSide(
                width: sp(1),
                color: const Color(0x44000000),
              ),
            );

            // ---- Card ----
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
                        height: (h * 0.007).clamp(sp(4), sp(10)).toDouble(),
                      ),
                      Text(
                        'Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(
                        height: (h * 0.02).clamp(sp(12), sp(22)).toDouble(),
                      ),

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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Enter your email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return _emailError;
                        },
                      ),
                      Divider(
                        height: sp(1),
                        thickness: sp(1),
                        color: underline().borderSide.color,
                      ),

                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: TextStyle(fontSize: fieldFont),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(fontSize: labelFont),
                          errorStyle: TextStyle(fontSize: errorFont),
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
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : _passwordError,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      Divider(
                        height: sp(1),
                        thickness: sp(1.2),
                        color: underline().borderSide.color,
                      ),

                      SizedBox(
                        height: (h * 0.025).clamp(sp(14), sp(24)).toDouble(),
                      ),

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

                            try {
                              await _signInWithRetry(
                                _email.text.trim(),
                                _password.text,
                              );
                            } catch (e) {
                              final sLoc =
                                  (math.min(w, h) / 375.0).clamp(0.85, 1.30);
                              double spLocal(double v) => v * sLoc;
                              final snackFont = (w * 0.04)
                                  .clamp(spLocal(12), spLocal(16))
                                  .toDouble();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Unexpected error: $e',
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

            // ---- Support links ----
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
                SizedBox(height: (h * 0.004).clamp(sp(2), sp(6)).toDouble()),
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

            // ---- Page layout ----
            return Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: (h * 0.02).clamp(sp(12), sp(24)).toDouble(),
                      bottom: kbOpen
                          ? (h * 0.02).clamp(sp(12), sp(24)).toDouble()
                          : sp(84),
                    ),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentW),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            card,
                            SizedBox(
                              height: (h * 0.006)
                                  .clamp(sp(4), sp(10))
                                  .toDouble(),
                            ),
                            supportLinks,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer: presente solo a tastiera chiusa
                if (!kbOpen)
                  Positioned(
                    left: sp(16),
                    right: sp(16),
                    bottom: sp(20),
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: sp(8),
                        runSpacing: sp(8),
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
                              radius: sp(24),
                            ),
                          ),
                        ],
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

class ResetPasswordDialog extends ConsumerStatefulWidget {
  final String initialEmail;
  const ResetPasswordDialog({super.key, required this.initialEmail});

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  late final TextEditingController _emailCtrl;
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
    final size = MediaQuery.of(context).size;
    final s =
        (math.min(size.width, size.height) / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;

    final dialogTitleFont = (size.width * 0.06)
        .clamp(sp(18), sp(22))
        .toDouble();
    final dialogBodyFont = (size.width * 0.045)
        .clamp(sp(14), sp(18))
        .toDouble();
    final dialogActionFont = (size.width * 0.05)
        .clamp(sp(15), sp(19))
        .toDouble();
    final labelFont = (size.width * 0.045).clamp(sp(14), sp(18)).toDouble();
    final fieldFont = (size.width * 0.05).clamp(sp(15), sp(19)).toDouble();
    final errorFont = (size.width * 0.04).clamp(sp(12), sp(16)).toDouble();

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Reset password',
        style: TextStyle(
          fontSize: dialogTitleFont,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Enter your email: we'll send you a link to reset your password.",
            style: TextStyle(fontSize: dialogBodyFont),
          ),
          SizedBox(height: sp(12)),
          TextField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: fieldFont),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(fontSize: labelFont),
              errorText: _errorText,
              errorStyle: TextStyle(fontSize: errorFont),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            textStyle: TextStyle(fontSize: dialogActionFont),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(
            textStyle: TextStyle(fontSize: dialogActionFont),
          ),
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
