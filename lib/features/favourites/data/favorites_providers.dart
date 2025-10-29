import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'favorites_repository_firebase.dart';

// Repository provider: injects Firestore into the Firebase implementation.
// Consumers can read this to access CRUD/watch methods for favorites.
final favoritesRepoProvider = Provider<FavoritesRepositoryFirebase>(
  (ref) => FavoritesRepositoryFirebase(ref.watch(firestoreProvider)),
);

// Stream provider (family): subscribe to the favorites of a specific user.
// Usage: ref.watch(favouritesStreamProvider(uid)) → AsyncValue<Set<String>>
// The stream emits updates whenever Firestore data changes.
final favouritesStreamProvider = StreamProvider.family<Set<String>, String>((
  ref,
  uid,
) {
  return ref.watch(favoritesRepoProvider).watchFavorites(uid);
});
