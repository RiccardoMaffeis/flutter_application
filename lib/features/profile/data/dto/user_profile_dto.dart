// features/profile/data/dto/user_profile_dto.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

class UserProfileDto {
  final String uid;
  final String? email;
  final String? displayName;
  final DateTime? dob;
  final String? city;
  final String? photoUrl;

  const UserProfileDto({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.dob,
    required this.city,
    required this.photoUrl,
  });

  // ---- parse helper (Timestamp | int epoch(ms/s) | String ISO o dd/MM/yyyy)
  static DateTime? _parseDob(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      // se arriva in millisecondi o secondi
      return v > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String && v.isNotEmpty) {
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
      final parts = v.split('/');
      if (parts.length == 3) {
        try {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          return DateTime(y, m, d);
        } catch (_) {}
      }
    }
    return null;
  }

  // ---- factories
  factory UserProfileDto.fromFirestore(
    Map<String, dynamic> data,
    User firebaseUser,
  ) {
    final rawDob =
        data['dob'] ??
        data['dateOfBirth'] ??
        data['birthDate'] ??
        data['birthday'];

    return UserProfileDto(
      uid: firebaseUser.uid,
      email: (data['email'] ?? firebaseUser.email) as String?,
      displayName:
          (data['displayName'] ?? data['name'] ?? firebaseUser.displayName)
              as String?,
      dob: _parseDob(rawDob),
      city: data['city'] as String?,
      photoUrl: (data['photoUrl'] ?? firebaseUser.photoURL) as String?,
    );
  }

  factory UserProfileDto.fromJson(
    Map<String, dynamic> json, {
    String? uidFallback,
  }) {
    final rawDob =
        json['dob'] ??
        json['dateOfBirth'] ??
        json['birthDate'] ??
        json['birthday'];

    return UserProfileDto(
      uid: (json['uid'] as String?) ?? uidFallback ?? '',
      email: json['email'] as String?,
      displayName: (json['displayName'] ?? json['name']) as String?,
      dob: _parseDob(rawDob),
      city: json['city'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'dob': dob,
      'dateOfBirth': dob,
      'city': city,
      'photoUrl': photoUrl,
    }..removeWhere((_, v) => v == null);
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'dob': dob?.toIso8601String(),
      'dateOfBirth': dob?.toIso8601String(),
      'city': city,
      'photoUrl': photoUrl,
    }..removeWhere((_, v) => v == null);
  }
}
