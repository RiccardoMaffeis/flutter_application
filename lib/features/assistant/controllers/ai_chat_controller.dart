import 'package:flutter_application/features/assistant/data/ai_rag_providers.dart';
import 'package:flutter_application/features/assistant/data/ar_candidates.dart';
import 'package:flutter_application/features/assistant/data/product_candidates.dart';
import 'package:flutter_application/features/shop/controllers/shop_controller.dart';
import 'package:flutter_application/features/shop/domain/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../domain/ai_message.dart';
import '../data/firebase_ai_providers.dart';

final aiChatControllerProvider =
    StateNotifierProvider<AiChatController, AsyncValue<List<AiMessage>>>(
      (ref) => AiChatController(ref)..reset(),
    );

class AiChatController extends StateNotifier<AsyncValue<List<AiMessage>>> {
  AiChatController(this._ref) : super(const AsyncValue.loading());
  final Ref _ref;

  void reset() {
    state = const AsyncValue.data([
      AiMessage(
        'assistant',
        'Hi! I’m your shopping assistant. How can I help?',
      ),
    ]);
  }

  Future<void> send(String userText) async {
    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];
    state = AsyncValue.data(updated);

    try {
      final svc = await _ref.read(firebaseAiServiceProvider.future);

      final reply = await svc.chat(updated);
      state = AsyncValue.data([...updated, AiMessage('assistant', reply)]);
    } catch (e) {
      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', 'AI error: $e'),
      ]);
    }
  }

  Future<void> sendStreaming(String userText) async {
    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];
    state = AsyncValue.data(updated);

    try {
      final svc = await _ref.read(firebaseAiServiceProvider.future);
      final stream = svc.chatStream(updated);

      var partial = '';
      state = AsyncValue.data([...updated, AiMessage('assistant', '')]);

      await for (final acc in stream) {
        partial = acc;
        final msgs = [...updated, AiMessage('assistant', partial)];
        state = AsyncValue.data(msgs);
      }
    } catch (e) {
      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', 'AI error: $e'),
      ]);
    }
  }

  Future<void> suggestFromCatalog(String userText, {int topK = 10}) async {
    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];
    state = AsyncValue.data(updated);

    try {
      final repo = _ref.read(productsRepositoryProvider);
      final all = await repo.fetchProducts();

      final prelim = _preFilter(all, userText, limit: 30);
      final candidates = candidatesFromProducts(prelim);

      final svc = await _ref.read(firebaseAiServiceProvider.future);
      final pick = await svc.pickDevices(
        userQuery: userText,
        candidates: candidates,
        topK: topK,
      );

      final picked = prelim.where((p) => pick.picks.contains(p.id)).toList();
      String msg;
      if (picked.isEmpty) {
        await askFromDocs(userText);
        return;
      } else {
        final bullet = picked
            .map((p) => '• ${p.displayName} (${p.code})')
            .join('\n');
        msg = 'Based on your request, I suggest:\n$bullet';
      }
      if (pick.reason.isNotEmpty) {
        msg += '\n\nReason: ${pick.reason}';
      }

      state = AsyncValue.data([...updated, AiMessage('assistant', msg)]);
    } catch (e) {
      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', 'AI error: $e'),
      ]);
    }
  }

  Future<void> suggestFromAR(String userText, {int topK = 10}) async {
    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];
    state = AsyncValue.data(updated);

    try {
      final candidates = allArCandidates();
      final svc = await _ref.read(firebaseAiServiceProvider.future);
      final pick = await svc.pickDevices(
        userQuery: userText,
        candidates: candidates,
        topK: topK,
      );

      String msg;
      if (pick.picks.isEmpty) {
        msg = 'I did not find a matching AR device among your models.';
      } else {
        final map = {for (final c in candidates) c.id: c};
        final chosen = pick.picks.map((id) => map[id]!).toList();
        final bullet = chosen.map((c) => '• ${c.label} (${c.code})').join('\n');
        msg =
            'AR models I can place now:\n$bullet\n\nSay "open in AR" to place one.';
      }
      if (pick.reason.isNotEmpty) {
        msg += '\n\nReason: ${pick.reason}';
      }

      state = AsyncValue.data([...updated, AiMessage('assistant', msg)]);
    } catch (e) {
      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', 'AI error: $e'),
      ]);
    }
  }

  List<Product> _preFilter(List<Product> all, String q, {int limit = 30}) {
    final Q = q.toLowerCase();
    int score(Product p) {
      int s = 0;
      final n = p.displayName.toLowerCase();
      final c = p.code.toLowerCase();
      if (n.contains(Q)) s += 5;
      if (c.contains(Q)) s += 6;
      final tokens = Q.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty);
      for (final t in tokens) {
        if (n.contains(t)) s += 1;
        if (c.contains(t)) s += 2;
      }
      return s;
    }

    final sorted = [...all]..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.take(limit).toList();
  }

  Future<void> askFromDocs(String userText) async {
    final history = state.value ?? const <AiMessage>[];
    final updated = [...history, AiMessage('user', userText)];
    state = AsyncValue.data(updated);

    try {
      final rag = _ref.read(aiRagServiceProvider);
      final reply = await rag.ask(userText);

      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', reply.text, sources: reply.sources),
      ]);
    } catch (e) {
      state = AsyncValue.data([
        ...updated,
        AiMessage('assistant', 'AI error: $e'),
      ]);
    }
  }
}
