import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'datasources/auth_remote_data_source.dart';
import 'dto/user_dto.dart';

/// Concrete implementation of the domain-level [AuthRepository].
/// Bridges the domain with the remote data source and handles
/// mapping between transport DTOs and domain entities.
class AuthRepositoryImpl implements AuthRepository {
  /// Low-level API to Firebase Auth/Firestore operations.
  final AuthRemoteDataSource remote;

  /// Inject the remote data source (facilitates testing and separation of concerns).
  AuthRepositoryImpl(this.remote);

  @override
  /// Stream the authenticated user state from the remote source,
  /// mapping each [UserDto] into a domain [AppUser].
  Stream<AppUser?> authState() =>
      remote.authState().map((UserDto? d) => d?.toDomain());

  @override
  /// Sign in with email/password and map the returned DTO to a domain entity.
  Future<AppUser> signIn(String email, String password) async =>
      (await remote.signIn(email, password)).toDomain();

  @override
  /// Create a new user and persist its profile, returning the domain entity.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? name,
    String? city,
    DateTime? dateOfBirth,
  }) async => (await remote.signUp(
    email: email,
    password: password,
    name: name,
    city: city,
    dateOfBirth: dateOfBirth,
  )).toDomain();

  @override
  /// Sign out the current user.
  Future<void> signOut() => remote.signOut();

  @override
  /// Dispatch a password reset email via the remote source.
  Future<void> sendPasswordResetEmail(String email) =>
      remote.sendPasswordResetEmail(email);

  @override
  /// Send a verification email to the currently authenticated user.
  Future<void> sendEmailVerification() => remote.sendEmailVerification();
}
