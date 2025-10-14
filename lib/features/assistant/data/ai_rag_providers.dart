// features/assistant/data/ai_rag_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_rag_service.dart';

final aiRagServiceProvider = Provider<AiRagService>((ref) {
  const url = String.fromEnvironment(
    'ASK_ASSISTANT_URL',
    defaultValue: 'https://<region>-<project>.cloudfunctions.net/askAssistant',
  );
  return AiRagService(url);
});
