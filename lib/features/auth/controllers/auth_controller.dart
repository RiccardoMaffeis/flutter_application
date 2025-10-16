import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../application/auth_service.dart';
import '../domain/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Controls authentication state for the UI using Riverpod's StateNotifier.
/// Holds an AsyncValue<AppUser?> that reflects: loading / data(user or null) / error.
class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthService _service;
  late final StreamSubscription _sub;

  /// Subscribes to the auth state stream and mirrors updates into [state].
  AuthController(this._service) : super(const AsyncData(null)) {
    _sub = _service.authState().listen(
      (u) => state = AsyncData(u), // push latest user (or null)
      onError: (e, st) => state = AsyncError(e, st), // surface stream errors
    );
  }

  /// Make sure to cancel the auth-state subscription to avoid leaks.
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /// Signs in with email/password.
  /// Sets loading before the call and restores state afterward.
  /// Rethrows FirebaseAuthException so the UI can show specific messages.
  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final u = await _service.signIn(email, password);
      state = AsyncData(u);
    } on fb.FirebaseAuthException {
      state = const AsyncData(null); // back to "no user" state on auth failure
      rethrow;
    } catch (_) {
      state = const AsyncData(null); // non-auth errors also reset to null
      rethrow;
    }
  }

  /// Creates a new account and returns the created user.
  /// Optional profile fields are forwarded to the service.
  /// Errors are rethrown for the UI to handle contextually.
  Future<void> signUp(
    String email,
    String password, {
    String? name,
    String? city,
    DateTime? dateOfBirth,
  }) async {
    state = const AsyncLoading();
    try {
      final u = await _service.signUp(
        email: email,
        password: password,
        name: name,
        city: city,
        dateOfBirth: dateOfBirth,
      );
      state = AsyncData(u);
    } on fb.FirebaseAuthException {
      state = const AsyncData(null);
      rethrow;
    } catch (e) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  /// Triggers a password reset email for the given address.
  /// The controller doesn't change [state] here; UI remains as-is.
  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordResetEmail(email);
}

/// Public provider exposing the controller's state and methods to the widget tree.
/// Widgets can `watch` to react to changes or `read(...notifier)` to invoke actions.
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
      return AuthController(ref.watch(authServiceProvider));
    });
