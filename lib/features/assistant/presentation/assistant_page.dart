import 'package:flutter/material.dart';
import 'package:flutter_application/features/assistant/controllers/ai_chat_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../assistant/domain/ai_message.dart';

/// Chat UI for the in-app Assistant.
/// - Uses Riverpod to read messages from `aiChatControllerProvider`.
/// - Responsive layout with a centered card panel.
/// - Simple input row with send button; pressing Enter submits as well.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  // Text controller for the message input field.
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Current list of messages (falls back to empty list if provider has no value yet).
    final msgs =
        ref.watch(aiChatControllerProvider).value ?? const <AiMessage>[];

    // --- Responsive metrics ---
    // Sizes derived from MediaQuery to adapt spacing/typography on phones/tablets.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double pageHPad = (w * 0.04).clamp(16.0, 28.0);
    final double pageVPad = (h * 0.02).clamp(14.0, 24.0);

    final double cardRadius = (w * 0.04).clamp(14.0, 22.0);
    final double cardHPad = (w * 0.05).clamp(16.0, 24.0);
    final double cardVPad = (h * 0.02).clamp(14.0, 22.0);
    final double panelMaxW = (w * 0.92).clamp(360.0, 820.0);

    final double titleSize = (w * 0.095).clamp(28.0, 44.0) * ts;
    final double dividerHeight = (h * 0.005).clamp(3.0, 6.0);
    final double dividerHMargin = (w * 0.03).clamp(10.0, 20.0);

    final double listMaxH = (h * 0.52).clamp(220.0, 540.0);
    final double listMinH = (h * 0.26).clamp(160.0, 260.0);

    final double avatarR = (w * 0.06).clamp(18.0, 26.0);
    final double avatarIcon = (avatarR * 0.95).clamp(18.0, 26.0);

    final double msgFont = (w * 0.04).clamp(14.0, 18.0) * ts;
    final double msgLineH = 1.25;

    final double tfHPad = (w * 0.035).clamp(12.0, 18.0);
    final double tfVPad = (h * 0.015).clamp(10.0, 14.0);
    final double tfRadius = (w * 0.045).clamp(14.0, 20.0);
    final double hintFont = (w * 0.038).clamp(13.0, 16.0) * ts;

    final double sendBtnH = (h * 0.06).clamp(42.0, 50.0);
    final double sendBtnW = (sendBtnH * 1.15).clamp(48.0, 60.0);
    final double sendIcon = (sendBtnH * 0.5).clamp(18.0, 24.0);
    final double sendRadius = (w * 0.035).clamp(12.0, 16.0);

    final double cancelMinH = (h * 0.055).clamp(40.0, 48.0);
    final double cancelFont = (w * 0.04).clamp(14.0, 16.0) * ts;

    // Global background for the page.
    const bg = Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Outer padding for the page content.
            padding: EdgeInsets.fromLTRB(
              pageHPad,
              pageVPad,
              pageHPad,
              pageVPad,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: panelMaxW),
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: Padding(
                    // Inner card padding.
                    padding: EdgeInsets.fromLTRB(
                      cardHPad,
                      cardVPad,
                      cardHPad,
                      cardVPad,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: (h * 0.006).clamp(4.0, 8.0)),
                        // Title
                        Text(
                          'Assistant',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: (h * 0.008).clamp(6.0, 10.0)),
                        // Accent divider (brand color)
                        Container(
                          height: dividerHeight,
                          margin: EdgeInsets.symmetric(
                            horizontal: dividerHMargin,
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
                        SizedBox(height: (h * 0.015).clamp(10.0, 16.0)),

                        // -------- Messages panel --------
                        // Shows a placeholder if empty, otherwise a separated ListView of messages.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: listMaxH,
                            minHeight: listMinH,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              (w * 0.03).clamp(10.0, 16.0),
                            ),
                            child: Material(
                              color: Colors.white,
                              child: msgs.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          (w * 0.04).clamp(12.0, 20.0),
                                        ),
                                        child: Text(
                                          'Type a message below…',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize:
                                                (w * 0.038).clamp(13.0, 16.0) *
                                                ts,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.symmetric(
                                        vertical: (h * 0.008).clamp(4.0, 10.0),
                                      ),
                                      itemCount: msgs.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (_, i) {
                                        final m = msgs[i];
                                        final isUser = m.role == 'user';
                                        return ListTile(
                                          // Per-item padding for better density.
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: (w * 0.02).clamp(
                                              8.0,
                                              16.0,
                                            ),
                                            vertical: (h * 0.008).clamp(
                                              6.0,
                                              10.0,
                                            ),
                                          ),
                                          // Avatar reflects user vs assistant.
                                          leading: CircleAvatar(
                                            radius: avatarR,
                                            backgroundColor: isUser
                                                ? Colors.blue[50]
                                                : Colors.grey[200],
                                            child: Icon(
                                              isUser
                                                  ? Icons.person
                                                  : Icons.smart_toy_outlined,
                                              color: Colors.black87,
                                              size: avatarIcon,
                                            ),
                                          ),
                                          // Message body (supports simple list parsing).
                                          title: _MessageContent(
                                            text: m.content,
                                            textStyle: TextStyle(
                                              fontSize: msgFont,
                                              fontWeight: FontWeight.w600,
                                              height: msgLineH,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),

                        SizedBox(height: (h * 0.016).clamp(10.0, 16.0)),

                        // -------- Input row (TextField + Send button) --------
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _c,
                                decoration: InputDecoration(
                                  hintText:
                                      'Ask about datasheets, manuals, specs…',
                                  hintStyle: TextStyle(fontSize: hintFont),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: tfHPad,
                                    vertical: tfVPad,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      tfRadius,
                                    ),
                                  ),
                                ),
                                // Allow sending with the keyboard enter key.
                                onSubmitted: _onSend,
                              ),
                            ),
                            SizedBox(width: (w * 0.02).clamp(6.0, 12.0)),
                            SizedBox(
                              height: sendBtnH,
                              width: sendBtnW,
                              child: ElevatedButton(
                                onPressed: () => _onSend(_c.text),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      sendRadius,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 2,
                                ),
                                child: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: sendIcon,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: (h * 0.016).clamp(10.0, 16.0)),

                        // -------- Bottom actions (Cancel) --------
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(0, cancelMinH),
                                  padding: EdgeInsets.symmetric(
                                    vertical: (h * 0.012).clamp(8.0, 12.0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      (w * 0.045).clamp(14.0, 20.0),
                                    ),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0x22000000),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(fontSize: cancelFont),
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
          ),
        ),
      ),
    );
  }

  /// Sends the trimmed text through the chat controller (RAG-only),
  /// then clears the input field. Empty strings are ignored.
  void _onSend(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final ctrl = ref.read(aiChatControllerProvider.notifier);
    ctrl.send(t); // RAG-only
    _c.clear();
  }
}

/// UI-only: renders message text with light markdown-like list support.
/// - Splits input into lines and groups them into paragraphs and lists
/// - Supports unordered lists (-, *, •, –) and ordered lists (1., 2), etc.)
class _MessageContent extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  const _MessageContent({required this.text, this.textStyle});

  @override
  Widget build(BuildContext context) {
    // Se non viene passato uno style, calcolane uno responsivo qui
    // If no style is provided, compute a responsive fallback here.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);
    final fallback = TextStyle(
      fontSize: (w * 0.04).clamp(14.0, 18.0) * ts,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );

    final baseStyle = textStyle ?? fallback;

    // Split by lines and build a list of widgets (paragraphs + list blocks).
    final lines = text.split(RegExp(r'\r?\n'));
    final children = <Widget>[];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // Try to match unordered or ordered list markers on the current line.
      final u = _matchUnordered(line);
      final o = _matchOrdered(line);

      if (u != null || o != null) {
        final items = <_ListItem>[];
        final isUnordered = u != null;

        // Consume consecutive lines that belong to the same list type.
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

        // Add a list block with slightly lighter weight than the message base style.
        children.add(
          _ListBlock(
            items: items,
            ordered: !isUnordered,
            textStyle: baseStyle.copyWith(fontWeight: FontWeight.w500),
          ),
        );
        continue;
      }

      // Collect plain text lines (non-list) into a paragraph until a list starts or lines end.
      final buf = <String>[];
      while (i < lines.length &&
          _matchUnordered(lines[i]) == null &&
          _matchOrdered(lines[i]) == null) {
        buf.add(lines[i]);
        i++;
      }
      final paragraph = buf.join('\n').trimRight();
      if (paragraph.isNotEmpty) {
        children.add(SelectableText(paragraph, style: baseStyle));
      }
    }

    // Render collected blocks with a small vertical gap between them.
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

  /// Matches an unordered list marker at the beginning of a line:
  /// '-', '*', '•' (U+2022), '–' (en dash U+2013).
  _U? _matchUnordered(String line) {
    final m = RegExp(r'^\s*([\-*\u2022\u2013])\s+(.*\S)\s*$').firstMatch(line);
    if (m == null) return null;
    return _U(m.group(2)!.trim());
  }

  /// Matches an ordered list marker like "1. " or "2) " at the beginning of a line.
  _O? _matchOrdered(String line) {
    final m = RegExp(r'^\s*(\d+)[\.\)]\s+(.*\S)\s*$').firstMatch(line);
    if (m == null) return null;
    return _O(int.tryParse(m.group(1)!) ?? 0, m.group(2)!.trim());
  }
}

// Simple struct for a list item (optional number + text).
class _ListItem {
  final int? number;
  final String text;
  _ListItem(this.number, this.text);
}

/// Renders a vertical list of items with either bullets or ordinal numbers.
/// Uses SelectableText for easy copy/paste of content.
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
              // Bullet or number prefix.
              Text(ordered ? '${it.number ?? 1}.' : '•', style: bulletStyle),
              const SizedBox(width: 8),
              // Item text expands to available width, supports selection.
              Expanded(child: SelectableText(it.text, style: textStyle)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Unordered list line match result (stores the item text only).
class _U {
  final String item;
  _U(this.item);
}

// Ordered list line match result (stores leading number and item text).
class _O {
  final int number;
  final String item;
  _O(this.number, this.item);
}
