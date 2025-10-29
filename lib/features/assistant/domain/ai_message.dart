// Simple immutable chat message model used in the AI assistant timeline.
// Each message has:
// - `role`: who sent it (e.g., 'user' or 'assistant').
// - `content`: the textual body of the message.
// - `sources`: optional list of attributions/links supporting the content.

import 'ai_source.dart';

class AiMessage {
  // Sender role identifier (e.g., 'user', 'assistant').
  final String role;

  // Plaintext message content as rendered in the UI.
  final String content;

  // Optional provenance/attribution entries attached to the message.
  final List<AiSource> sources;

  // Const constructor for immutability; defaults to an empty list of sources.
  const AiMessage(this.role, this.content, {this.sources = const []});

  // Serializes the message into a JSON-friendly map for persistence or transport.
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'sources': sources.map((s) => s.toJson()).toList(),
  };
}
