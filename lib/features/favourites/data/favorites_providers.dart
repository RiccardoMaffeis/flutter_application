import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'favorites_repository_firebase.dart';

final favoritesRepoProvider = Provider<FavoritesRepositoryFirebase>(
  (ref) => FavoritesRepositoryFirebase(ref.watch(firestoreProvider)),
);

final favouritesStreamProvider =
    StreamProvider.family<Set<String>, String>((ref, uid) {
  return ref.watch(favoritesRepoProvider).watchFavorites(uid);
});
