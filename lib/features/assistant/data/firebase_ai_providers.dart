import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_ai_service.dart';

final firebaseAiServiceProvider = FutureProvider<FirebaseAiService>((ref) async {
  return FirebaseAiService.create(auth: FirebaseAuth.instance);
});
