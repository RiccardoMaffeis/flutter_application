import 'user_profile.dart';

abstract class ProfileRepository {
  /// Profili dell’utente loggato (Auth obbligatoria).
  Future<UserProfile> fetchMyProfile();

  /// Facoltativo: aggiorna alcuni campi del profilo.
  Future<void> updateMyProfile({
    String? displayName,
    DateTime? dob,
    String? city,
    String? photoUrl,
  });
}
