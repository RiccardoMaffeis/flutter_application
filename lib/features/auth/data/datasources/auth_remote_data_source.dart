import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../dto/user_dto.dart';

/// Remote data source that talks to Firebase Auth and Cloud Firestore.
/// It is responsible for low-level I/O: creating users, signing in/out,
/// listening to the auth state, and reading/writing the user document.
class AuthRemoteDataSource {
  final fb.FirebaseAuth auth;
  final FirebaseFirestore db;

  AuthRemoteDataSource(this.auth, this.db);

  /// Firestore collection that stores user profiles.
  CollectionReference<Map<String, dynamic>> get _col => db.collection('users');

  /// Emits the current authenticated user as a [UserDto] (or `null` if signed out).
  /// - Listens to FirebaseAuth's auth state changes.
  /// - For a logged-in user, it ensures a corresponding Firestore document exists.
  ///   If missing, it creates a minimal profile on the fly.
  Stream<UserDto?> authState() async* {
    await for (final fb.User? u in auth.authStateChanges()) {
      if (u == null) {
        // No authenticated user.
        yield null;
      } else {
        // Look up the Firestore profile for the authenticated user.
        final snap = await _col.doc(u.uid).get();
        if (snap.exists) {
          // Map Firestore document to DTO and emit it.
          yield UserDto.fromFirestore(snap.id, snap.data()!);
        } else {
          // If the profile document does not exist yet, create a minimal one.
          final now = DateTime.now();
          final dto = UserDto(
            uid: u.uid,
            email: u.email ?? '',
            name: u.displayName,
            city: null,
            dateOfBirth: null,
            createdAt: now,
            updatedAt: now,
          );
          await _col.doc(u.uid).set(dto.toMap());
          yield dto;
        }
      }
    }
  }

  /// Creates a new user with Firebase Auth and persists a profile in Firestore.
  /// Returns the newly created [UserDto].
  Future<UserDto> signUp({
    required String email,
    required String password,
    String? name,
    String? city,
    DateTime? dateOfBirth,
  }) async {
    // Create the auth account.
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    // Optionally set the display name in Firebase Auth.
    if (name != null && name.isNotEmpty) {
      await cred.user!.updateDisplayName(name);
    }

    // Create and store the Firestore profile document.
    final now = DateTime.now();
    final dto = UserDto(
      uid: uid,
      email: email,
      name: name,
      city: city,
      dateOfBirth: dateOfBirth,
      createdAt: now,
      updatedAt: now,
    );
    await _col.doc(uid).set(dto.toMap());
    return dto;
  }

  /// Signs in using email/password and returns the user's [UserDto].
  /// Ensures there is a Firestore profile document; creates one if missing.
  Future<UserDto> signIn(String email, String password) async {
    // Authenticate with Firebase Auth.
    final cred = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Fetch (or create) the corresponding Firestore profile.
    final uid = cred.user!.uid;
    final snap = await _col.doc(uid).get();
    if (snap.exists) return UserDto.fromFirestore(snap.id, snap.data()!);

    // If the document doesn't exist, create a minimal one.
    final now = DateTime.now();
    final dto = UserDto(
      uid: uid,
      email: cred.user!.email ?? email,
      name: cred.user!.displayName,
      city: null,
      dateOfBirth: null,
      createdAt: now,
      updatedAt: now,
    );
    await _col.doc(uid).set(dto.toMap());
    return dto;
  }

  /// Signs out the current user from Firebase Auth.
  Future<void> signOut() => auth.signOut();

  /// Sends a password reset email for the given address using Firebase Auth.
  Future<void> sendPasswordResetEmail(String email) =>
      auth.sendPasswordResetEmail(email: email);

  /// Sends an email verification to the current user if needed.
  Future<void> sendEmailVerification() async {
    final u = auth.currentUser;
    if (u != null && !u.emailVerified) {
      await u.sendEmailVerification();
    }
  }
}
