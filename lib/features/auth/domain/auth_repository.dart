import 'user.dart';

/// Abstraction of the authentication layer used by the application.
/// This repository exposes high-level operations and hides the concrete
/// implementation (e.g., Firebase) from the rest of the app.
abstract class AuthRepository {
  /// Emits the current authenticated user as a stream.
  /// - `null` means no user is signed in.
  Stream<AppUser?> authState();

  /// Signs in a user using email and password.
  /// Returns the authenticated [AppUser] on success.
  Future<AppUser> signIn(String email, String password);

  /// Creates a new account using email and password and optionally stores
  /// profile information (name, city, date of birth).
  /// Returns the created [AppUser] on success.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? name,
    String? city,
    DateTime? dateOfBirth,
  });

  /// Signs out the currently authenticated user.
  Future<void> signOut();

  /// Sends a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email);

  /// Sends an email verification message to the currently signed-in user.
  Future<void> sendEmailVerification();
}
