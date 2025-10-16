import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../domain/ai_source.dart';

class AiReply {
  final String text;
  final List<AiSource> sources;
  const AiReply(this.text, this.sources);
}

class AiRagService {
  final String endpoint;
  const AiRagService(this.endpoint);

  Future<AiReply> ask(String query) async {
    final uri = Uri.parse(endpoint);
    final r = await http
        .post(
          uri,
          headers: const {"Content-Type": "application/json"},
          body: jsonEncode({"query": query}),
        )
        .timeout(const Duration(seconds: 30));

    if (r.statusCode != 200) {
      throw HttpException('HTTP ${r.statusCode}: ${r.body}', uri: uri);
    }

    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final List<AiSource> src = (j['sources'] as List? ?? [])
        .map((e) => AiSource.fromJson(e as Map<String, dynamic>))
        .toList();
    return AiReply((j['answer'] as String?)?.trim() ?? '', src);
  }
}
