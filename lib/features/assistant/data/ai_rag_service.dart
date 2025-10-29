// Minimal HTTP client for the RAG backend.
// - Sends a JSON POST to `endpoint` with {"query": "..."}.
// - Expects a JSON response containing `answer` (string) and optional `sources` (array).
// - Returns a typed AiReply with the text + parsed sources.
// - Throws HttpException for non-200 responses and respects a 30s timeout.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../domain/ai_source.dart';

// Immutable value object that encapsulates the assistant's reply and its sources.
// `text` is the final answer; `sources` contains attribution/metadata.
class AiReply {
  final String text;
  final List<AiSource> sources;
  const AiReply(this.text, this.sources);
}

// Simple service wrapper around a single RAG endpoint.
class AiRagService {
  final String endpoint;
  const AiRagService(this.endpoint);

  // Sends the user query to the backend and parses the response.
  // - Uses application/json Content-Type.
  // - Times out after 30 seconds (surface as TimeoutException).
  // - On non-200, throws an HttpException including status code and body.
  // - On success, decodes JSON and maps `sources` to a List<AiSource>.
  Future<AiReply> ask(String query) async {
    final uri = Uri.parse(endpoint);

    // POST the query payload; backend should accept: { "query": "<text>" }.
    final r = await http
        .post(
          uri,
          headers: const {"Content-Type": "application/json"},
          body: jsonEncode({"query": query}),
        )
        .timeout(const Duration(seconds: 30));

    // If the backend didn't return OK, bubble up a rich HttpException.
    if (r.statusCode != 200) {
      throw HttpException('HTTP ${r.statusCode}: ${r.body}', uri: uri);
    }

    // Parse the JSON body; expect "answer" (String) and "sources" (List?).
    final j = jsonDecode(r.body) as Map<String, dynamic>;

    // Defensive parsing: coerce absent or non-list `sources` to an empty list.
    final List<AiSource> src = (j['sources'] as List? ?? [])
        .map((e) => AiSource.fromJson(e as Map<String, dynamic>))
        .toList();

    // Trim the answer; if missing, return an empty string (caller can fallback).
    return AiReply((j['answer'] as String?)?.trim() ?? '', src);
  }
}
