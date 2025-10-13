import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
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

    // Colore di sfondo "grigio" come il dialog
    const bg = Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Larghezza massima della card: simile a un dialog centrato
              final maxW = constraints.maxWidth < 640
                  ? constraints.maxWidth - 24
                  : 640.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Material(
                      color: Colors.white,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),
                            const Text(
                              'Assistant',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // --- Sottolineatura rossa in stile app ---
                            Container(
                              height: 4,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withOpacity(0.45),
                                    blurRadius: 3,
                                    spreadRadius: 0.4,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            const SizedBox(height: 12),

                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight:
                                    480, 
                                minHeight: 220,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Material(
                                  color: Colors.white,
                                  child: msgs.isEmpty
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Text(
                                              'Scrivi un messaggio qui sotto…',
                                              style: TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          itemCount: msgs.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (_, i) {
                                            final m = msgs[i];
                                            final isUser = m.role == 'user';
                                            return ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                              leading: CircleAvatar(
                                                radius: 22,
                                                backgroundColor: isUser
                                                    ? Colors.blue[50]
                                                    : Colors.grey[200],
                                                child: Icon(
                                                  isUser
                                                      ? Icons.person
                                                      : Icons
                                                            .smart_toy_outlined,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              title: Text(
                                                m.content,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.25,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Input + Send (integrati nella card)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _c,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Ask about products, AR, orders...',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    onSubmitted: _onSend,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Bottone Send rosso, stile "primary"
                                SizedBox(
                                  height: 44,
                                  width: 52,
                                  child: ElevatedButton(
                                    onPressed: () => _onSend(_c.text),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: EdgeInsets.zero,
                                      elevation: 2,
                                    ),
                                    child: const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Pulsante Cancel come nel dialog
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      side: const BorderSide(
                                        color: Color(0x22000000),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onSend(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final ctrl = ref.read(aiChatControllerProvider.notifier);

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
