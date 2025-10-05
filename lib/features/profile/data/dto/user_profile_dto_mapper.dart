import '../../domain/user_profile.dart';
import 'user_profile_dto.dart';

extension UserProfileDtoMapper on UserProfileDto {
  UserProfile toDomain() => UserProfile(
    uid: uid,
    email: email ?? '',
    displayName: displayName ?? '',
    dob: dob,
    city: city ?? '',
    photoUrl: photoUrl,
  );
}
