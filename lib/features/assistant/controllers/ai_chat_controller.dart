import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/ai_rag_providers.dart';
import '../domain/ai_message.dart';

final aiChatControllerProvider =
    StateNotifierProvider<AiChatController, AsyncValue<List<AiMessage>>>(
      (ref) => AiChatController(ref)..reset(),
    );

class _Err {
  final String code;
  final String userMsg;
  final String? devMsg;
  const _Err(this.code, this.userMsg, [this.devMsg]);
}

class AiChatController extends StateNotifier<AsyncValue<List<AiMessage>>> {
  AiChatController(this._ref) : super(const AsyncValue.loading());
  final Ref _ref;

  String _fallbackMessage([String? _]) =>
      "I couldn't find relevant results. Please try to be more specific.";

  void reset() {
    state = const AsyncValue.data([
      AiMessage(
        'assistant',
        'Hi! I’m your shopping assistant. How can I help?',
      ),
    ]);
  }

  _Err _classifyError(Object e) {
    final s = e.toString();
    final ls = s.toLowerCase();

    if (e is SocketException) {
      return _Err(
        'E_NET',
        'Network error. Please check your internet connection and try again.',
        s,
      );
    }
    if (e is TimeoutException || ls.contains('timeout')) {
      return _Err(
        'E_TIMEOUT',
        'The request took too long. Please try again.',
        s,
      );
    }

    final httpMatch = RegExp(r'\b(\d{3})\b').firstMatch(s);
    final http = httpMatch != null ? int.tryParse(httpMatch.group(1)!) : null;

    if (ls.contains('rate limit') || ls.contains('quota') || http == 429) {
      return _Err(
        'E_RATE_LIMIT',
        'Too many requests or quota reached. Please wait and try again.',
        s,
      );
    }
    if (ls.contains('permission-denied') ||
        ls.contains('unauthorized') ||
        ls.contains('invalid api key') ||
        http == 401 ||
        http == 403) {
      return _Err(
        'E_AUTH',
        'Authentication or permissions issue. Please sign in again or contact support.',
        s,
      );
    }
    if (ls.contains('not found') || http == 404) {
      return _Err('E_NOT_FOUND', 'Requested resource is not available.', s);
    }
    if (http == 413 || ls.contains('payload too large')) {
      return _Err(
        'E_TOO_LARGE',
        'Your request is too large. Try shortening the message.',
        s,
      );
    }
    if (ls.contains('invalid argument') ||
        ls.contains('bad request') ||
        http == 400 ||
        http == 422) {
      return _Err(
        'E_INPUT',
        'The request seems invalid. Please rephrase and try again.',
        s,
      );
    }
    if ((ls.contains('safety') && ls.contains('block')) ||
        ls.contains('content policy')) {
      return _Err(
        'E_SAFETY',
        'The request was blocked by safety rules. Please rephrase your question.',
        s,
      );
    }
    if (http == 500 ||
        http == 502 ||
        http == 503 ||
        http == 504 ||
        ls.contains('internal error')) {
      return _Err(
        'E_UPSTREAM',
        'The AI service is temporarily unavailable. Please try again shortly.',
        s,
      );
    }
    return _Err('E_UNKNOWN', 'Something went wrong. Please try again.', s);
  }

  void _emitError(Object e, List<AiMessage> base) {
    final err = _classifyError(e);
    var text = '${err.userMsg} (code: ${err.code})';
    if (kDebugMode && (err.devMsg?.isNotEmpty ?? false)) {
      text += '\n\n[debug] ${err.devMsg}';
    }
    state = AsyncValue.data([...base, AiMessage('assistant', text)]);
  }

  Future<void> send(String userText) async {
    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];
    state = AsyncValue.data(updated);

    try {
      final rag = _ref.read(aiRagServiceProvider);
      final reply = await rag.ask(userText);
      final text = reply.text.trim();
      final out = text.isEmpty ? _fallbackMessage(userText) : text;

      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', out, sources: reply.sources),
      ]);
    } catch (e) {
      _emitError(e, updated);
    }
  }

  Future<void> sendStreaming(String userText) => send(userText);
}
