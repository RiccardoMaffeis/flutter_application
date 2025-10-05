import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';
import 'dto/user_profile_dto.dart';
import 'dto/user_profile_dto_mapper.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<UserProfile> fetchMyProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final docRef = _users.doc(user.uid);
    final snap = await docRef.get();

    // Se non esiste, crea base
    if (!snap.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
      }, SetOptions(merge: true));
    }

    final data = (await docRef.get()).data() ?? {};
    // Passa l'uid come fallback così il DTO è completo
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
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not authenticated');

    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (dob != null) ...{
        'dateOfBirth': dob,
        'dob': dob,
      },
      if (city != null) 'city': city,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (user.email != null) 'email': user.email,
    };

    await _users.doc(user.uid).set(data, SetOptions(merge: true));
  }
}
