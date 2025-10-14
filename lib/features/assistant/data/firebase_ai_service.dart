import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../domain/ai_message.dart';
import '../domain/ai_pick.dart';

class FirebaseAiService {
  FirebaseAiService._(this._auth, this._ai, this._model);

  final FirebaseAuth _auth;
  final FirebaseAI _ai;
  final GenerativeModel _model;

  static Future<FirebaseAiService> create({FirebaseAuth? auth}) async {
    final a = auth ?? FirebaseAuth.instance;
    if (a.currentUser == null) {
      await a.signInAnonymously();
    }

    const loc = String.fromEnvironment('VERTEX_LOCATION', defaultValue: 'europe-west1');
    final ai = FirebaseAI.vertexAI(auth: a, location: loc);

    const modelName = String.fromEnvironment(
      'FIREBASE_AI_MODEL',
      defaultValue: 'gemini-2.0-flash',
    );

    final model = ai.generativeModel(
      model: modelName,
      systemInstruction: Content.text(
        'You are a concise shopping assistant for an ABB-themed store. '
        'Only suggest devices from a provided list of candidates. '
        'Prefer exact code/label matches when possible.',
      ),
    );

    return FirebaseAiService._(a, ai, model);
  }

  Future<String> chat(List<AiMessage> history) async {
    if (history.isEmpty) return 'Say hi 👋';
    final lastUser = history.lastWhere((m) => m.role == 'user', orElse: () => history.last);

    final resp = await _model.generateContent([Content.text(lastUser.content)]);
    final txt = resp.text?.trim();
    return (txt == null || txt.isEmpty) ? 'Sorry, no reply.' : txt;
  }

  Stream<String> chatStream(List<AiMessage> history) async* {
    if (history.isEmpty) {
      yield 'Say hi 👋';
      return;
    }
    final lastUser = history.lastWhere((m) => m.role == 'user', orElse: () => history.last);
    final stream = _model.generateContentStream([Content.text(lastUser.content)]);
    final buf = StringBuffer();
    await for (final chunk in stream) {
      buf.write(chunk.text ?? '');
      yield buf.toString();
    }
  }

  Future<AiPickResult> pickDevices({
    required String userQuery,
    required List<DeviceCandidate> candidates,
    int topK = 10,
  }) async {
    final lines = candidates.take(topK).map((c) => c.toString()).join('\n');

    final prompt = '''
You must select devices ONLY from the following CANDIDATES list.
Return a STRICT JSON object with exactly this schema:
{"picks": ["<ID>", ...], "reason": "<short explanation>"}

Rules:
- picks must be a subset of the IDs shown in CANDIDATES.
- Prefer exact code/label matches; otherwise, best tag/semantic match.
- If nothing fits, return {"picks": [], "reason":"not found"}.

USER QUERY:
$userQuery

CANDIDATES:
$lines

Return ONLY the JSON, no extra text.
''';

    final resp = await _model.generateContent([Content.text(prompt)]);
    final raw = (resp.text ?? '').trim();

    final jsonStr = _firstJsonObject(raw);
    if (jsonStr == null) {
      return const AiPickResult(picks: [], reason: 'parse error');
    }

    try {
      final obj = json.decode(jsonStr) as Map<String, dynamic>;
      final picks = (obj['picks'] as List?)?.cast<String>() ?? const <String>[];
      final reason = (obj['reason'] as String?) ?? '';
      final allowed = candidates.map((c) => c.id).toSet();
      final filtered = picks.where(allowed.contains).toList();
      return AiPickResult(picks: filtered, reason: reason);
    } catch (_) {
      return const AiPickResult(picks: [], reason: 'parse error');
    }
  }

  String? _firstJsonObject(String s) {
    final fence = RegExp(r'```json\s*([\s\S]*?)```', multiLine: true);
    final m = fence.firstMatch(s);
    if (m != null) return m.group(1)?.trim();

    int depth = 0, start = -1;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (s[i] == '}') {
        depth--;
        if (depth == 0 && start != -1) {
          return s.substring(start, i + 1);
        }
      }
    }
    return null;
    }
}
