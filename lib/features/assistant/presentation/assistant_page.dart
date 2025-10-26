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
    // Stato del provider (AsyncValue)
    final chatAV = ref.watch(aiChatControllerProvider);
    final bool isGenerating = chatAV.isLoading;
    // Current list of messages (falls back to empty list if provider has no value yet).
    final msgs = chatAV.value ?? const <AiMessage>[];

    // --- Responsive metrics ---
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final shortest = w < h ? w : h;
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final double pageHPad = (w * 0.04).clamp(sp(16.0), sp(28.0));
    final double pageVPad = (h * 0.02).clamp(sp(14.0), sp(24.0));

    final double cardRadius = (w * 0.04).clamp(sp(14.0), sp(22.0));
    final double cardHPad = (w * 0.05).clamp(sp(16.0), sp(24.0));
    final double cardVPad = (h * 0.02).clamp(sp(14.0), sp(22.0));
    final double panelMaxW = (w * 0.92).clamp(sp(360.0), sp(820.0));

    final double titleSize = (w * 0.095).clamp(sp(28.0), sp(44.0)) * ts;
    final double dividerHeight = (h * 0.005).clamp(sp(3.0), sp(6.0));
    final double dividerHMargin = (w * 0.03).clamp(sp(10.0), sp(20.0));

    final double listMaxH = (h * 0.52).clamp(sp(220.0), sp(540.0));
    final double listMinH = (h * 0.26).clamp(sp(160.0), sp(260.0));

    final double avatarR = (w * 0.06).clamp(sp(18.0), sp(26.0));
    final double avatarIcon = (avatarR * 0.95).clamp(sp(18.0), sp(26.0));

    final double msgFont = (w * 0.04).clamp(sp(14.0), sp(18.0)) * ts;
    final double msgLineH = 1.25;

    final double tfHPad = (w * 0.035).clamp(sp(12.0), sp(18.0));
    final double tfVPad = (h * 0.015).clamp(sp(10.0), sp(14.0));
    final double tfRadius = (w * 0.045).clamp(sp(14.0), sp(20.0));
    final double hintFont = (w * 0.038).clamp(sp(13.0), sp(16.0)) * ts;

    final double sendBtnH = (h * 0.06).clamp(sp(42.0), sp(50.0));
    final double sendBtnW = (sendBtnH * 1.15).clamp(sp(48.0), sp(60.0));
    final double sendIcon = (sendBtnH * 0.5).clamp(sp(18.0), sp(24.0));
    final double sendRadius = (w * 0.035).clamp(sp(12.0), sp(16.0));

    final double cancelMinH = (h * 0.055).clamp(sp(40.0), sp(48.0));
    final double cancelFont = (w * 0.04).clamp(sp(14.0), sp(16.0)) * ts;

    // Global background for the page.
    const bg = Color(0xFFF5F5F7);

    // List separator (no const: fully responsive)
    final listSeparator = Divider(
      height: sp(1.0),
      thickness: sp(1.0),
      color: const Color(0x22000000),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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
                  elevation: sp(3.0),
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
                        SizedBox(height: (h * 0.006).clamp(sp(4.0), sp(8.0))),
                        // Title
                        Text(
                          'Assistant',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: (h * 0.008).clamp(sp(6.0), sp(10.0))),
                        // Accent divider (brand color)
                        Container(
                          height: dividerHeight,
                          margin: EdgeInsets.symmetric(
                            horizontal: dividerHMargin,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(sp(3.0)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.45),
                                blurRadius: sp(3.0),
                                spreadRadius: sp(0.4),
                                offset: Offset(0, sp(3.0)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: (h * 0.015).clamp(sp(10.0), sp(16.0))),

                        // -------- Messages panel --------
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: listMaxH,
                            minHeight: listMinH,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              (w * 0.03).clamp(sp(10.0), sp(16.0)),
                            ),
                            child: Material(
                              color: Colors.white,
                              child: msgs.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          (w * 0.04).clamp(sp(12.0), sp(20.0)),
                                        ),
                                        child: Text(
                                          'Type a message below…',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize:
                                                (w * 0.038).clamp(
                                                  sp(13.0),
                                                  sp(16.0),
                                                ) *
                                                ts,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.symmetric(
                                        vertical: (h * 0.008).clamp(
                                          sp(4.0),
                                          sp(10.0),
                                        ),
                                      ),
                                      itemCount: msgs.length,
                                      separatorBuilder: (_, __) =>
                                          listSeparator,
                                      itemBuilder: (_, i) {
                                        final m = msgs[i];
                                        final isUser = m.role == 'user';
                                        return ListTile(
                                          // Per-item padding for better density.
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: (w * 0.02).clamp(
                                              sp(8.0),
                                              sp(16.0),
                                            ),
                                            vertical: (h * 0.008).clamp(
                                              sp(6.0),
                                              sp(10.0),
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

                        SizedBox(height: (h * 0.016).clamp(sp(10.0), sp(16.0))),

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
                                onSubmitted: (v) {
                                  if (!isGenerating) _onSend(v);
                                },
                              ),
                            ),
                            SizedBox(
                              width: (w * 0.02).clamp(sp(6.0), sp(12.0)),
                            ),
                            SizedBox(
                              height: sendBtnH,
                              width: sendBtnW,
                              child: ElevatedButton(
                                onPressed: isGenerating
                                    ? null
                                    : () => _onSend(_c.text),
                                style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.resolveWith<Color>(
                                        (states) => AppTheme.accent,
                                      ),
                                  foregroundColor:
                                      const MaterialStatePropertyAll<Color>(
                                        Colors.white,
                                      ),
                                  shape: MaterialStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        sendRadius,
                                      ),
                                    ),
                                  ),
                                  padding: const MaterialStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                  elevation: MaterialStatePropertyAll(sp(2.0)),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                      ),
                                  child: isGenerating
                                      ? SizedBox(
                                          key: const ValueKey('spinner'),
                                          width: sendIcon,
                                          height: sendIcon,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                        )
                                      : Icon(
                                          key: const ValueKey('send'),
                                          Icons.send,
                                          color: Colors.white,
                                          size: sendIcon,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: (h * 0.016).clamp(sp(10.0), sp(16.0))),

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
                                    vertical: (h * 0.012).clamp(
                                      sp(8.0),
                                      sp(12.0),
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      (w * 0.045).clamp(sp(14.0), sp(20.0)),
                                    ),
                                  ),
                                  side: BorderSide(
                                    color: const Color(0x22000000),
                                    width: sp(1.0),
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

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Sends the trimmed text through the chat controller (RAG-only),
  /// then clears the input field. Empty strings are ignored.
  void _onSend(String text) {
    // Blocca se sta già generando
    final isGenerating = ref.read(aiChatControllerProvider).isLoading;
    if (isGenerating) return;

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
    // Responsive fallback if no style provided.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final shortest = w < h ? w : h;
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    final fallback = TextStyle(
      fontSize: (w * 0.04).clamp(sp(14.0), sp(18.0)) * ts,
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

        // List block with slightly lighter weight than the base style.
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

    // Render collected blocks with a small responsive vertical gap.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int j = 0; j < children.length; j++) ...[
          if (j > 0) SizedBox(height: sp(6.0)),
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
    // Local responsive spacing for bullets.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final shortest = w < h ? w : h;
    final s = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * s;

    final bulletStyle = textStyle.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((it) {
        return Padding(
          padding: EdgeInsets.only(bottom: sp(2.0)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bullet or number prefix.
              Text(ordered ? '${it.number ?? 1}.' : '•', style: bulletStyle),
              SizedBox(width: sp(8.0)),
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
