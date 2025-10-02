import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import '../data/auth_repository_impl.dart';
import '../data/datasources/auth_remote_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides the remote data source that talks to Firebase services.
/// Kept as a separate layer to isolate SDK calls from the rest of the app.
final _remoteDsProvider = Provider<AuthRemoteDataSource>((ref) {
  // Inject concrete Firebase dependencies here (Auth + Firestore).
  return AuthRemoteDataSource(
    fb.FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});

/// Exposes the domain-level repository implementation.
/// This converts raw data-source results into domain models and abstracts persistence.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(_remoteDsProvider));
});

/// Application-facing service used by controllers/UI.
/// Thin wrapper around the repository to keep the UI unaware of infrastructure details.
class AuthService {
  final AuthRepository _repo;
  AuthService(this._repo);

  /// Emits the current authenticated user (or null) and updates on state changes.
  Stream<AppUser?> authState() => _repo.authState();

  /// Attempts to sign in with email/password, returning the domain user on success.
  Future<AppUser> signIn(String email, String password) =>
      _repo.signIn(email, password);

  /// Creates a new account and persists any optional profile fields.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? name,
    String? city,
    DateTime? dateOfBirth,
  }) =>
      _repo.signUp(
        email: email,
        password: password,
        name: name,
        city: city,
        dateOfBirth: dateOfBirth,
      );

  /// Clears local session and signs out from the backend.
  Future<void> signOut() => _repo.signOut();

  /// Triggers a password reset email for the given address.
  Future<void> sendPasswordResetEmail(String email) =>
      _repo.sendPasswordResetEmail(email);

  /// Sends a verification email to the currently signed-in user.
  Future<void> sendEmailVerification() => _repo.sendEmailVerification();
}

/// Top-level provider exposing the AuthService to the widget tree.
/// Other layers depend on this rather than the repository directly.
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(authRepositoryProvider)),
);
