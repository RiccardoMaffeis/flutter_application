import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'cart_repository_firebase.dart';

final cartRepoFirebaseProvider = Provider<CartRepositoryFirebase>(
  (ref) => CartRepositoryFirebase(ref.watch(firestoreProvider)),
);

// Stream conteggio pezzi (family su uid)
final cartCountStreamProvider =
    StreamProvider.family<int, String>((ref, uid) {
  return ref.watch(cartRepoFirebaseProvider).watchCount(uid);
});
