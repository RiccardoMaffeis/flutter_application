import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_rag_service.dart';

final aiRagServiceProvider = Provider<AiRagService>((ref) {
  const url = String.fromEnvironment(
    'ASK_ASSISTANT_URL',
    defaultValue:
        'https://us-central1-tesi-2025-a0d0c.cloudfunctions.net/askAssistant',
  );
  return AiRagService(url);
});
