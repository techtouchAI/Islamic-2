import 'package:flutter/material.dart';
import '../models/search_models.dart';
import '../../services/search_engine.dart'; // for normalization

class SearchResultTile extends StatelessWidget {
  final ContentItem item;
  final String? highlightQuery;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.item,
    this.highlightQuery,
    required this.onTap,
  });

  Widget _buildHighlightedText(String originalText, BuildContext context, {TextStyle? baseStyle}) {
    if (highlightQuery == null || highlightQuery!.isEmpty) return Text(originalText, style: baseStyle);

    final normalizedQuery = SearchEngine.normalizeArabic(highlightQuery!);
    final theme = Theme.of(context);
    final highlightStyle = (baseStyle ?? const TextStyle()).copyWith(
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.3),
    );

    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return Text(originalText, style: baseStyle);

    List<TextSpan> spans = [];
    final originalWords = originalText.split(' ');

    for (int i = 0; i < originalWords.length; i++) {
      final word = originalWords[i];
      final normWord = SearchEngine.normalizeArabic(word);

      bool isHighlighted = false;
      for (var qWord in queryWords) {
        if (normWord.contains(qWord) || SearchEngine.fuzzyMatch(qWord, normWord, isFuzzy: qWord.length >= 4)) {
          isHighlighted = true;
          break;
        }
      }

      spans.add(TextSpan(
        text: word + (i < originalWords.length - 1 ? ' ' : ''),
        style: isHighlighted ? highlightStyle : baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.merge(baseStyle),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          alignment: Alignment.centerRight,
          child: _buildHighlightedText(
            item.title,
            context,
            baseStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
