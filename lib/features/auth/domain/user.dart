/// Domain model representing an authenticated user's profile/state
/// as used throughout the app. This is intentionally decoupled from
/// any backend/SDK models (e.g., Firebase) so the rest of the codebase
/// depends only on this stable interface.
class AppUser {
  /// Stable unique identifier for the user (e.g., Firebase UID).
  final String uid;

  /// Primary email address associated with the account.
  final String email;

  /// Optional display name shown in the UI.
  final String? name;

  /// Optional city (or city of birth), part of the user's profile data.
  final String? city;

  /// Optional date of birth for the user. May be null if not provided.
  final DateTime? dateOfBirth;

  /// Creation timestamp for the profile record (not necessarily the auth user).
  /// Prefer storing this in UTC in the data layer.
  final DateTime createdAt;

  /// Last update timestamp for the profile record. Prefer UTC in the data layer.
  final DateTime updatedAt;

  /// Immutable value object; construct with all required fields.
  /// Use mappers/DTOs to convert to/from persistence (e.g., Firestore).
  const AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.city,
    this.dateOfBirth,
    required this.createdAt,
    required this.updatedAt,
  });
}
