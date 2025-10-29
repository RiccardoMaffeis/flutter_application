// Mapper extension that converts a transport-layer DTO (UserProfileDto)
// into a domain-layer entity (UserProfile).
// Notes:
// - Optional string fields fall back to empty strings to keep domain model non-nullable.
// - Non-string optionals (e.g., dob, photoUrl) are passed through as-is (nullable).

import '../../domain/user_profile.dart';
import 'user_profile_dto.dart';

extension UserProfileDtoMapper on UserProfileDto {
  // Build a strongly-typed domain model from the DTO.
  UserProfile toDomain() => UserProfile(
    uid: uid, // Required unique identifier.
    email: email ?? '', // Default to '' if null.
    displayName: displayName ?? '', // Default to '' if null.
    dob: dob, // Nullable date of birth passed through.
    city: city ?? '', // Default to '' if null.
    photoUrl: photoUrl, // Nullable avatar URL passed through.
  );
}
