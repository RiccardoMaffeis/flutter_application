import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'cart_repository_firebase.dart';

/// Provides a concrete CartRepositoryFirebase instance wired to Firestore.
/// - Reads the shared Firestore instance from `firestoreProvider`.
/// - Keep this as a plain `Provider` since the repository itself is stateless
///   and exposes streams for reactivity.
final cartRepoFirebaseProvider = Provider<CartRepositoryFirebase>(
  (ref) => CartRepositoryFirebase(ref.watch(firestoreProvider)),
);

/// Exposes a real-time stream of the cart item count for a given user.
/// - `family<int, String>` lets you pass the user's UID to create a
///   parameterized provider instance per user.
/// - Downstream widgets can `ref.watch(cartCountStreamProvider(uid))` to get:
///     - `AsyncLoading` while waiting,
///     - `AsyncData<int>` with the current count,
///     - `AsyncError` on failures.
/// - The repository handles the Firestore query and emits updates on changes.
final cartCountStreamProvider = StreamProvider.family<int, String>((ref, uid) {
  return ref.watch(cartRepoFirebaseProvider).watchCount(uid);
});
