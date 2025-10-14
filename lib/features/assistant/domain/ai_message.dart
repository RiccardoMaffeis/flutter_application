// features/assistant/domain/ai_message.dart
import 'ai_source.dart';

class AiMessage {
  final String role;
  final String content;
  final List<AiSource> sources; // <-- NEW (opzionale)

  const AiMessage(this.role, this.content, {this.sources = const []});

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'sources': sources.map((s) => s.toJson()).toList(),
  };
}
