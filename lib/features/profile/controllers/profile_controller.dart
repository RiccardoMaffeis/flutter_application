import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/dto/user_profile_dto.dart';
import '../data/dto/user_profile_dto_mapper.dart';
import '../domain/user_profile.dart';

/// Exposes a stream of the current Firebase user.
/// Emits `User?` (null when signed out).
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Auto-disposed provider that owns the ProfileController and exposes
/// `AsyncValue<UserProfile>`.
///
/// - Reads the current user from `authStateProvider` using `asData?.value`.
/// - If there is a user, triggers an initial `load()`.
/// - If there is no user, sets an unauthenticated state immediately.
/// - The controller is auto-disposed when no longer watched.
final profileControllerProvider =
    StateNotifierProvider.autoDispose<
      ProfileController,
      AsyncValue<UserProfile>
    >((ref) {
      // Read the current user only when authStateProvider has data.
      final user = ref.watch(authStateProvider).asData?.value;

      // Create the controller with the current user (can be null).
      final ctrl = ProfileController(user);

      if (user != null) {
        // Fire initial fetch when we have a logged-in user.
        ctrl.load();
      } else {
        // Immediately set an unauthenticated state to avoid pending/loading UI.
        ctrl.setUnauthenticated();
      }
      return ctrl;
    });

/// Holds the profile state as `AsyncValue<UserProfile>`.
/// Uses `StateNotifier` so we can imperatively assign `state`.
class ProfileController extends StateNotifier<AsyncValue<UserProfile>> {
  ProfileController(this._user) : super(const AsyncLoading());

  /// Cached reference to the current Firebase user (may be null).
  User? _user;

  /// Allows updating the current user and reloading the profile.
  /// Useful when you receive auth updates outside of this provider.
  void setUser(User? u) {
    _user = u;
    load();
  }

  /// Sets an unauthenticated error state (guarded by `mounted`).
  /// This avoids assigning state after the notifier is disposed.
  void setUnauthenticated() {
    if (!mounted) return;
    state = AsyncError(StateError('Not authenticated'), StackTrace.empty);
  }

  /// Loads the profile document for the current user from Firestore.
  /// Guards with `mounted` after awaited calls to prevent:
  /// "Bad state: Tried to use ProfileController after `dispose` was called."
  Future<void> load() async {
    final user = _user ?? FirebaseAuth.instance.currentUser;

    // If no user is available, report an auth error.
    if (user == null) {
      if (!mounted) return;
      state = AsyncError(StateError('Not authenticated'), StackTrace.empty);
      return;
    }

    try {
      // Fetch the user's document from Firestore.
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // If the notifier was disposed while awaiting, abort safely.
      if (!mounted) return; // avoids: writing `state` after dispose

      // Map Firestore data into our domain model via DTO.
      final dto = UserProfileDto.fromFirestore(snap.data() ?? {}, user);
      state = AsyncData(dto.toDomain());
    } catch (e, st) {
      // If disposed while awaiting, abort safely.
      if (!mounted) return;
      state = AsyncError(e, st);
    }
  }

  /// Convenience method to force a reload.
  Future<void> refresh() => load();
}
