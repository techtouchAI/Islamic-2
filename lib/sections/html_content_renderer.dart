import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class HtmlContentRenderer extends StatefulWidget {
  final String content;
  final TextStyle baseStyle;
  final TextAlign textAlign;
  final int? bookmarkedIndex;
  final ValueChanged<int>? onParagraphTapped;
  final Widget? blinkingStar;

  const HtmlContentRenderer({
    super.key,
    required this.content,
    required this.baseStyle,
    this.textAlign = TextAlign.center,
    this.bookmarkedIndex,
    this.onParagraphTapped,
    this.blinkingStar,
  });

  @override
  State<HtmlContentRenderer> createState() => _HtmlContentRendererState();
}

class _HtmlContentRendererState extends State<HtmlContentRenderer> {
  Color? _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
            int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}
    return null;
  }

  List<Widget> _parseContentRobust(
      String content, TextStyle baseStyle, TextAlign textAlign) {
    String processed = content.replaceAll('<html>', '').replaceAll('//', '');
    processed = processed
        .replaceAll(RegExp(r'<\/?p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<br>', caseSensitive: false), '\n');
    processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // Insert a newline after Ayah markers so they can be parsed as independent paragraphs
    processed = processed.replaceAllMapped(
      RegExp(r'(﴿[0-9٠-٩]+﴾|۝)'),
      (match) => '${match.group(1)}\n',
    );

    // Pad tags as well to avoid merging
    processed = processed.replaceAllMapped(
      RegExp(r'(<[^>]+>)'),
      (match) => ' ${match.group(1)} ',
    );

    final List<Widget> paragraphWidgets = [];
    final paragraphs = processed.split('\n');

    final RegExp tagRegex =
        RegExp(r'(<b>|</b>|<c=(#[a-zA-Z0-9]{6})>|</c>)', caseSensitive: false);

    bool isBold = false;
    Color? currentColor;
    int wordIndex = 0;

    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        paragraphWidgets.add(const SizedBox(height: 8.0));
        continue;
      }

      final words = paragraph.split(RegExp(r'\s+'));
      final List<InlineSpan> spans = [];

      for (int i = 0; i < words.length; i++) {
        final word = words[i];
        if (word.isEmpty) continue;

        // Parse styles inside the word
        String displayText = word;
        for (final match in tagRegex.allMatches(word)) {
          final String tag = match.group(1)!.toLowerCase();
          if (tag == '<b>') {
            isBold = true;
          } else if (tag == '</b>') {
            isBold = false;
          } else if (tag.startsWith('<c=')) {
            currentColor = _parseColor(match.group(2)!);
          } else if (tag == '</c>') {
            currentColor = null;
          }
        }
        displayText = displayText.replaceAll(tagRegex, '');

        if (displayText.isEmpty) continue;

        final currentHtmlStyle = TextStyle(
          fontWeight: isBold ? FontWeight.bold : baseStyle.fontWeight,
          color: currentColor ?? baseStyle.color,
          fontFamily: baseStyle.fontFamily,
          fontSize: baseStyle.fontSize,
          height: baseStyle.height,
        );

        final currentWordIndex = wordIndex++;
        final isBookmarked =
            widget.bookmarkedIndex?.toString() == currentWordIndex.toString();

        if (i < words.length - 1) {
          displayText += " ";
        }

        spans.add(
          TextSpan(
            text: displayText,
            style: currentHtmlStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => widget.onParagraphTapped?.call(currentWordIndex),
          ),
        );

        if (isBookmarked) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const SizedBox(width: 12, height: 12),
                  Positioned(
                    top: -10,
                    right: 0,
                    child: const Icon(Icons.star, color: Colors.green, size: 12),
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (spans.isNotEmpty) {
        paragraphWidgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RichText(
              textDirection: TextDirection.rtl,
              textAlign: textAlign,
              text: TextSpan(
                style: baseStyle,
                children: spans,
              ),
            ),
          ),
        );
      }
    }

    return paragraphWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _parseContentRobust(
            widget.content, widget.baseStyle, widget.textAlign));
  }
}
