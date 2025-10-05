class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? dob;
  final String city;
  final String? photoUrl;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.dob,
    required this.city,
    required this.photoUrl,
  });

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
