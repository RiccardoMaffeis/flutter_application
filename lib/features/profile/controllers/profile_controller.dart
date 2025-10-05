import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/dto/user_profile_dto.dart';
import '../data/dto/user_profile_dto_mapper.dart';
import '../domain/user_profile.dart';

/// Stream auth: ricrea i consumer quando cambia l’utente
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Controller del profilo: si ricrea ad ogni cambio utente
final profileControllerProvider =
    StateNotifierProvider.autoDispose<
      ProfileController,
      AsyncValue<UserProfile>
    >((ref) {
      final user = ref.watch(authStateProvider).valueOrNull;
      final ctrl = ProfileController(user);
      // carica subito
      ctrl.load();
      return ctrl;
    });

class ProfileController extends StateNotifier<AsyncValue<UserProfile>> {
  ProfileController(this._user) : super(const AsyncLoading());

  User? _user;

  /// Se serve (es. da un listener) puoi forzare l’utente e ricaricare
  void setUser(User? u) {
    _user = u;
    load();
  }

  Future<void> load() async {
    final user = _user ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = AsyncError(
        StateError('Not authenticated'),
        StackTrace.empty,
      );
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final dto = UserProfileDto.fromFirestore(snap.data() ?? {}, user);
      state = AsyncData(dto.toDomain());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => load();
}
