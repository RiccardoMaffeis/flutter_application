import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/user.dart';

/// Data Transfer Object (DTO) for user records stored in Firestore.
/// - Mirrors the Firestore document structure.
/// - Provides conversions to/from Firestore maps and the domain [AppUser] model.
class UserDto {
  /// Firebase Authentication UID (document id in the `users` collection).
  final String uid;

  /// User email (stored redundantly both in Auth and Firestore for querying).
  final String email;

  /// Optional display name.
  final String? name;

  /// Optional city.
  final String? city;

  /// Optional date of birth.
  final DateTime? dateOfBirth;

  /// Creation timestamp (server-side persisted as Firestore `Timestamp`).
  final DateTime createdAt;

  /// Last update timestamp (server-side persisted as Firestore `Timestamp`).
  final DateTime updatedAt;

  const UserDto({
    required this.uid,
    required this.email,
    this.name,
    this.city,
    this.dateOfBirth,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [UserDto] from a Firestore document.
  /// `id` is the document id, `data` is the raw map from Firestore.
  factory UserDto.fromFirestore(String id, Map<String, dynamic> data) {
    return UserDto(
      uid: id,
      email: data['email'] as String,
      name: data['name'] as String?,
      city: data['city'] as String?,
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Serializes the DTO to a Firestore-compatible map.
  /// Note: `dateOfBirth` is nullable and omitted when not present.
  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'city': city,
    'dateOfBirth': dateOfBirth != null
        ? Timestamp.fromDate(dateOfBirth!)
        : null,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Converts this DTO to the domain entity [AppUser].
  /// Use this when passing data to the application/business layer.
  AppUser toDomain() => AppUser(
    uid: uid,
    email: email,
    name: name,
    city: city,
    dateOfBirth: dateOfBirth,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// Builds a DTO from the domain [AppUser].
  /// Useful before persisting the entity to Firestore.
  factory UserDto.fromDomain(AppUser u) => UserDto(
    uid: u.uid,
    email: u.email,
    name: u.name,
    city: u.city,
    dateOfBirth: u.dateOfBirth,
    createdAt: u.createdAt,
    updatedAt: u.updatedAt,
  );
}
