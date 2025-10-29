import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/ai_rag_providers.dart';
import '../domain/ai_message.dart';

// Public provider exposing the controller and its state (list of AiMessage).
// The controller is created and immediately initialized with a greeting via reset().
final aiChatControllerProvider =
    StateNotifierProvider<AiChatController, AsyncValue<List<AiMessage>>>(
      (ref) => AiChatController(ref)..reset(),
    );

// Lightweight error DTO used to map exceptions into user-friendly messages.
class _Err {
  final String code; // Short machine-readable code (e.g., E_NET).
  final String userMsg; // End-user facing explanation.
  final String? devMsg; // Optional developer/raw error details (debug only).
  const _Err(this.code, this.userMsg, [this.devMsg]);
}

// StateNotifier manages an AsyncValue<List<AiMessage>> timeline.
// Each action produces a new immutable list representing the chat history.
class AiChatController extends StateNotifier<AsyncValue<List<AiMessage>>> {
  AiChatController(this._ref) : super(const AsyncValue.loading());
  final Ref _ref;

  // Generic fallback when the backend returns an empty reply.
  String _fallbackMessage([String? _]) =>
      "I couldn't find relevant results. Please try to be more specific.";

  // Resets the conversation with a single assistant greeting.
  void reset() {
    state = const AsyncValue.data([
      AiMessage(
        'assistant',
        'Hi! I’m your shopping assistant. How can I help?',
      ),
    ]);
  }

  // Heuristically classify an arbitrary exception/stack trace into a typed error.
  // Looks at specific Dart exceptions, HTTP-like codes present in the message,
  // and common keywords to decide the appropriate user-facing error.
  _Err _classifyError(Object e) {
    final s = e.toString();
    final ls = s.toLowerCase();

    // Typical connectivity issue.
    if (e is SocketException) {
      return _Err(
        'E_NET',
        'Network error. Please check your internet connection and try again.',
        s,
      );
    }
    // Explicit timeout or timeout keyword.
    if (e is TimeoutException || ls.contains('timeout')) {
      return _Err(
        'E_TIMEOUT',
        'The request took too long. Please try again.',
        s,
      );
    }

    // Try extract a 3-digit number that might represent an HTTP status code.
    final httpMatch = RegExp(r'\b(\d{3})\b').firstMatch(s);
    final http = httpMatch != null ? int.tryParse(httpMatch.group(1)!) : null;

    // Rate limiting / quota exhaustion.
    if (ls.contains('rate limit') || ls.contains('quota') || http == 429) {
      return _Err(
        'E_RATE_LIMIT',
        'Too many requests or quota reached. Please wait and try again.',
        s,
      );
    }
    // Authentication / authorization issues.
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
    // Not found (resource missing).
    if (ls.contains('not found') || http == 404) {
      return _Err('E_NOT_FOUND', 'Requested resource is not available.', s);
    }
    // Payload too large.
    if (http == 413 || ls.contains('payload too large')) {
      return _Err(
        'E_TOO_LARGE',
        'Your request is too large. Try shortening the message.',
        s,
      );
    }
    // Input/validation errors.
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
    // Safety / policy blocks.
    if ((ls.contains('safety') && ls.contains('block')) ||
        ls.contains('content policy')) {
      return _Err(
        'E_SAFETY',
        'The request was blocked by safety rules. Please rephrase your question.',
        s,
      );
    }
    // Upstream/server errors and transient failures.
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
    // Fallback for unknown scenarios.
    return _Err('E_UNKNOWN', 'Something went wrong. Please try again.', s);
  }

  // Pushes an assistant error message into the chat timeline, preserving base history.
  // In debug mode, it also includes the raw developer message for troubleshooting.
  void _emitError(Object e, List<AiMessage> base) {
    final err = _classifyError(e);
    var text = '${err.userMsg} (code: ${err.code})';
    if (kDebugMode && (err.devMsg?.isNotEmpty ?? false)) {
      text += '\n\n[debug] ${err.devMsg}';
    }
    state = AsyncValue.data([...base, AiMessage('assistant', text)]);
  }

  // Sends a user message and waits for a full (non-streaming) response.
  // - Appends the user message to history.
  // - Emits an AsyncLoading that preserves previous value (for UI spinners).
  // - Invokes the RAG service and appends the assistant reply (or fallback).
  // - On failure, maps the error and emits a friendly assistant message.
  Future<void> send(String userText) async {
    if (state.isLoading) return;

    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];

    // Preserve previous value while signaling a loading state to the UI.
    // copyWithPrevious is an internal API (hence the ignore).
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<List<AiMessage>>().copyWithPrevious(
      AsyncValue.data(updated),
    );

    try {
      final rag = _ref.read(
        aiRagServiceProvider,
      ); // Get the RAG client/service.
      final reply = await rag.ask(userText); // Perform the query.
      final text = reply.text.trim();
      final out = text.isEmpty ? _fallbackMessage(userText) : text;

      // Append assistant message with optional source attributions.
      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', out, sources: reply.sources),
      ]);
    } catch (e) {
      // Convert any thrown error into a user-visible assistant message.
      _emitError(e, updated);
    }
  }

  // Streaming facade — currently defers to the non-streaming path.
  // Replace with incremental token handling to enable live streaming in the UI.
  Future<void> sendStreaming(String userText) => send(userText);
}
