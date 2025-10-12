import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../assistant/controllers/ai_chat_controller.dart';
import '../../assistant/domain/ai_message.dart';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final msgs =
        ref.watch(aiChatControllerProvider).value ?? const <AiMessage>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 520),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[50] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.content),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _c,
                      decoration: const InputDecoration(
                        hintText: 'Ask about products, AR, orders...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _onSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _onSend(_c.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSend(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final ctrl = ref.read(aiChatControllerProvider.notifier);

    // Esempio: se contiene "ar" o "modello", cerca tra modelli AR,
    // altrimenti tra catalogo prodotti
    if (RegExp(
      r'\bar\b|\bmodello\b|\b3 poli\b|\b4 poli\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      ctrl.suggestFromAR(t);
    } else {
      ctrl.suggestFromCatalog(t);
    }
    _c.clear();
  }
}
