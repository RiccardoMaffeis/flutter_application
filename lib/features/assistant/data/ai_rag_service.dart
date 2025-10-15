// features/assistant/data/ai_rag_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/ai_source.dart';

class AiReply {
  final String text;
  final List<AiSource> sources;
  AiReply(this.text, this.sources);
}

class AiRagService {
  final String endpoint;
  const AiRagService(this.endpoint);

  Future<AiReply> ask(String query) async {
    final r = await http.post(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"query": query}),
    );
    if (r.statusCode != 200) {
      throw Exception("HTTP ${r.statusCode}: ${r.body}");
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final List<AiSource> src = (j['sources'] as List? ?? [])
        .map((e) => AiSource.fromJson(e as Map<String, dynamic>))
        .toList();
    return AiReply(j['answer'] as String? ?? "", src);
  }
}
