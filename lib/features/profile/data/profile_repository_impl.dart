// Firebase-backed implementation of ProfileRepository.
// - Uses FirebaseAuth to identify the current user.
// - Stores profile documents under: `users/{uid}` in Cloud Firestore.
// - Reads/writes profile fields with merge semantics to avoid clobbering data.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';
import 'dto/user_profile_dto.dart';
import 'dto/user_profile_dto_mapper.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  // Lazy singletons from the default Firebase app.
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Convenience accessor for the top-level users collection.
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<UserProfile> fetchMyProfile() async {
    // Guard: require an authenticated user.
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    // Fetch the user's profile doc.
    final docRef = _users.doc(user.uid);
    final snap = await docRef.get();

    // If the document does not exist yet, initialize it with minimal fields.
    if (!snap.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
      }, SetOptions(merge: true)); // merge keeps future fields intact
    }

    // Read the (possibly just-created) document and map to domain model.
    final data = (await docRef.get()).data() ?? {};
    final dto = UserProfileDto.fromJson(data, uidFallback: user.uid);
    return dto.toDomain();
  }

  @override
  Future<void> updateMyProfile({
    String? displayName,
    DateTime? dob,
    String? city,
    String? photoUrl,
  }) async {
    // Guard: require an authenticated user.
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    // Build partial update map only with provided fields.
    // DOB is written under both 'dateOfBirth' and 'dob' for compatibility.
    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (dob != null) ...{'dateOfBirth': dob, 'dob': dob},
      if (city != null) 'city': city,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (user.email != null) 'email': user.email,
    };

    // Merge update into the profile document (non-destructive for other fields).
    await _users.doc(user.uid).set(data, SetOptions(merge: true));
  }
}
