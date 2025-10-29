// Data Transfer Object (DTO) representing a user's profile as stored/transferred.
// - Can be constructed from Firestore maps (plus FirebaseAuth User fallback fields).
// - Can be constructed from generic JSON (e.g., API/local storage).
// - Supports multiple DOB formats and normalizes to DateTime.
// - Serializers produce Firestore/JSON maps, stripping nulls for cleanliness.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

class UserProfileDto {
  // Stable user identifier (from FirebaseAuth).
  final String uid;
  // Optional email (may be absent in profile document).
  final String? email;
  // Optional display name (can come from doc or FirebaseAuth).
  final String? displayName;
  // Optional date of birth (normalized DateTime).
  final DateTime? dob;
  // Optional city.
  final String? city;
  // Optional avatar/photo URL.
  final String? photoUrl;

  const UserProfileDto({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.dob,
    required this.city,
    required this.photoUrl,
  });

  // Best-effort coercion of various DOB representations to DateTime:
  // - Firestore Timestamp
  // - DateTime
  // - int (seconds or milliseconds since epoch, heuristic via threshold)
  // - ISO 8601 string
  // - "dd/MM/yyyy" string
  static DateTime? _parseDob(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
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

  // Factory that merges Firestore document data with FirebaseAuth's User fields
  // as fallbacks (e.g., email/displayName/photoUrl) when missing in the doc.
  // Also recognizes several possible keys for DOB in the stored document.
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

  // Factory that builds the DTO from a generic JSON map.
  // - Accepts an optional uidFallback when JSON doesn't include 'uid'.
  // - Accepts multiple key variants for DOB, then parses them.
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

  // Serializer for Firestore write:
  // - Includes both 'dob' and 'dateOfBirth' for compatibility.
  // - Removes nulls to avoid storing empty fields.
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

  // Serializer for JSON (e.g., network/local storage):
  // - Uses ISO8601 string for DateTime.
  // - Duplicates DOB under 'dob' and 'dateOfBirth' for consumers using either key.
  // - Removes nulls.
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
