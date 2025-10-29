// Riverpod provider that exposes a singleton AiRagService.
// The base URL is resolved at compile time using `String.fromEnvironment`.
// To override the default at build/run, pass:
//   flutter run --dart-define=ASK_ASSISTANT_URL=https://your-endpoint
// or when building:
//   flutter build apk --dart-define=ASK_ASSISTANT_URL=https://your-endpoint
// If not provided, it falls back to the default Cloud Function URL below.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_rag_service.dart';

final aiRagServiceProvider = Provider<AiRagService>((ref) {
  // Compile-time environment lookup with a default value.
  const url = String.fromEnvironment(
    'ASK_ASSISTANT_URL',
    defaultValue:
        'https://us-central1-tesi-2025-a0d0c.cloudfunctions.net/askAssistant',
  );
  // Construct the service with the resolved endpoint.
  return AiRagService(url);
});
