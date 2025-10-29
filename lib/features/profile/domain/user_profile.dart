// Domain entity representing an immutable user profile used by the app.
// Fields are non-nullable where possible; optional ones (dob/photoUrl) can be absent.

class UserProfile {
  // Stable user identifier (Firebase UID).
  final String uid;
  // Primary email address (non-null in domain).
  final String email;
  // Display name shown in the UI.
  final String displayName;
  // Optional date of birth (nullable).
  final DateTime? dob;
  // City or locality (defaults to '' at mapping time if unknown).
  final String city;
  // Optional avatar/photo URL.
  final String? photoUrl;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.dob,
    required this.city,
    required this.photoUrl,
  });

  // Returns a new instance with selected fields overridden.
  // Unspecified parameters fall back to the current values.
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? dob,
    String? city,
    String? photoUrl,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      dob: dob ?? this.dob,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
