class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const AiMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
