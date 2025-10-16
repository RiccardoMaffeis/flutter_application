import 'package:flutter/material.dart';
import 'package:flutter_application/core/theme/app_theme.dart';
import 'package:flutter_application/features/shop/presentation/pdf/pdf_viewer_page.dart';
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

    const bg = Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                                maxHeight: 480,
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
                                              'Type a message below…',
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
                                              title: _MessageContent(
                                                text: m.content,
                                                textStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.25,
                                                ),
                                              ),
                                              subtitle:
                                                  (m.role != 'user' &&
                                                      m.sources.isNotEmpty)
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 6,
                                                          ),
                                                      child: Wrap(
                                                        spacing: 6,
                                                        runSpacing: -6,
                                                        children: [
                                                          for (final s
                                                              in m.sources)
                                                            ActionChip(
                                                              label: Text(
                                                                '[${s.idx}] ${s.title} · p.${s.page}',
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                              ),
                                                              onPressed: () {
                                                                Navigator.of(
                                                                  context,
                                                                ).push(
                                                                  MaterialPageRoute(
                                                                    builder: (_) => PdfViewerPage(
                                                                      title: s
                                                                          .title,
                                                                      pdfUrl:
                                                                          s.url,
                                                                      initialPage:
                                                                          s.page,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                        ],
                                                      ),
                                                    )
                                                  : null,
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

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

    final wantsDocs = RegExp(
      r'\b(compare|comparison|differences?|pdf|page|sheet|datasheet|manual|'
      r'weight|mass|dimensions?|size|width|height|depth|'
      r'icu|ics|current|voltage|breaking|power|curve|range|adjust(ment)?)\b',
      caseSensitive: false,
    ).hasMatch(t);

    if (wantsDocs) {
      ctrl.askFromDocs(t);
      _c.clear();
      return;
    }

    if (RegExp(
      r'\bar\b|\bmodel\b|\b3[-\s]?pole(s)?\b|\b4[-\s]?pole(s)?\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      ctrl.suggestFromAR(t);
    } else {
      ctrl.suggestFromCatalog(t);
    }
    _c.clear();
  }
}

/// UI-only: renderizza testo con elenchi in ordine “pulito”
/// - elenchi con "-", "*", "•", "–" => ordinati alfabeticamente (case-insensitive)
/// - elenchi "1.", "2)", ecc. => ordinati numericamente
/// Il resto del testo resta identico. Nessun cambio alla logica del controller.
class _MessageContent extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  const _MessageContent({required this.text, this.textStyle});

  @override
  Widget build(BuildContext context) {
    final style =
        textStyle ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
        );

    final lines = text.split(RegExp(r'\r?\n'));
    final children = <Widget>[];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      final u = _matchUnordered(line);
      final o = _matchOrdered(line);

      if (u != null || o != null) {
        final items = <_ListItem>[];
        final isUnordered = u != null;

        // raccoglie il blocco contiguo dello stesso tipo (unordered/ordered)
        while (i < lines.length) {
          final lu = _matchUnordered(lines[i]);
          final lo = _matchOrdered(lines[i]);
          if (isUnordered && lu == null) break;
          if (!isUnordered && lo == null) break;

          if (isUnordered) {
            items.add(_ListItem(null, lu!.item));
          } else {
            items.add(_ListItem(lo!.number, lo.item));
          }
          i++;
        }

        // ordina
        if (isUnordered) {
          items.sort(
            (a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()),
          );
        } else {
          items.sort((a, b) => (a.number ?? 1).compareTo(b.number ?? 1));
        }

        // render list
        children.add(
          _ListBlock(
            items: items,
            ordered: !isUnordered,
            textStyle: style.copyWith(fontWeight: FontWeight.w500),
          ),
        );
        // non incrementare i qui: già avanzato nel while interno
        continue;
      }

      // paragrafo normale (finché non trova un elenco)
      final buf = <String>[];
      while (i < lines.length &&
          _matchUnordered(lines[i]) == null &&
          _matchOrdered(lines[i]) == null) {
        buf.add(lines[i]);
        i++;
      }
      final paragraph = buf.join('\n').trimRight();
      if (paragraph.isNotEmpty) {
        children.add(SelectableText(paragraph, style: style));
      }
    }

    // spaziatura verticale morbida tra blocchi
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int j = 0; j < children.length; j++) ...[
          if (j > 0) const SizedBox(height: 6),
          children[j],
        ],
      ],
    );
  }

  // match "-" "*" "•" "–" + testo
  _U? _matchUnordered(String line) {
    final m = RegExp(r'^\s*([\-*\u2022\u2013])\s+(.*\S)\s*$').firstMatch(line);
    if (m == null) return null;
    return _U(m.group(2)!.trim());
  }

  // match "1." "2)" ecc. + testo
  _O? _matchOrdered(String line) {
    final m = RegExp(r'^\s*(\d+)[\.\)]\s+(.*\S)\s*$').firstMatch(line);
    if (m == null) return null;
    return _O(int.tryParse(m.group(1)!) ?? 0, m.group(2)!.trim());
  }
}

class _ListItem {
  final int? number;
  final String text;
  _ListItem(this.number, this.text);
}

class _ListBlock extends StatelessWidget {
  final List<_ListItem> items;
  final bool ordered;
  final TextStyle textStyle;
  const _ListBlock({
    required this.items,
    required this.ordered,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final bulletStyle = textStyle.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((it) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ordered ? '${it.number ?? 1}.' : '•', style: bulletStyle),
              const SizedBox(width: 8),
              Expanded(child: SelectableText(it.text, style: textStyle)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _U {
  final String item;
  _U(this.item);
}

class _O {
  final int number;
  final String item;
  _O(this.number, this.item);
}
