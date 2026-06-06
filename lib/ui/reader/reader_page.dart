import 'package:flutter/material.dart';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../sections/html_content_renderer.dart';

class SurahHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int? surahId;
  const SurahHeader(
      {super.key, required this.title, required this.color, this.surahId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer 1: The Frame
          Image.asset(
            'assets/images/quran_surah_name_frame.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            colorBlendMode: BlendMode.srcIn,
          ),
          // Layer 2: The Surah Name
          if (surahId != null)
            Builder(
              builder: (context) {
                final id = surahId!;
                final color = Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black;
                // SurahHeader only receives `surahId` (which maps to db 'id').
                // Fatiha (id 2) -> 1
                // Baqarah (id 3) -> 2
                // Al-Ma'un (id 108) -> 107
                // Al-Kawthar (id 110) -> 108
                // Al-Kafirun (id 111) -> 109
                // An-Nas (id 116) -> 114
                int imageId = (id >= 110) ? id - 2 : (id == 108 ? 107 : id - 1);
                return Image.asset(
                  'assets/images/quran/quran_surah_names_$imageId.png',
                  height: 32,
                  fit: BoxFit.contain,
                  color: color,
                  colorBlendMode: BlendMode.srcIn,
                );
              },
            ),
        ],
      ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  final String title, content;
  final double fontSizeFactor;
  final bool isQuran;
  final bool isImamAli;
  final List<Map<String, dynamic>>? ayahs;
  final String? surahName;
  final String? titleColor;
  final int? surahId;
  const ReaderPage({
    super.key,
    required this.title,
    required this.content,
    this.titleColor,
    required this.fontSizeFactor,
    this.isQuran = false,
    this.isImamAli = false,
    this.surahName,
    this.ayahs,
    this.surahId,
  });
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with TickerProviderStateMixin {
  late double _factor;
  Color? _customBgColor;
  int? _bookmarkedLineIndex;
  static final _trailingNumbersRegex = RegExp(r'[\s\xa0]*[0-9٠-٩]+$');

  Color _parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      try {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      } catch (e) {
        return Colors.black;
      }
    }
    return Colors.black; // default
  }

  String _convertToArabicNumber(String number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String numStr = number;
    for (int i = 0; i < english.length; i++) {
      numStr = numStr.replaceAll(english[i], arabic[i]);
    }
    return numStr;
  }

  @override
  void initState() {
    super.initState();
    _factor = widget.fontSizeFactor;

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _bookmarkedLineIndex = prefs.getInt('bookmark_line_${widget.title}');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dynamicBgColor = _customBgColor ?? Theme.of(context).cardColor;
    final dynamicTextColor =
        dynamicBgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.content));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم نسخ النص')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(widget.content),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: primary, width: 1.0),
                  borderRadius: BorderRadius.circular(25),
                  color: _customBgColor ?? Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (widget.isQuran)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        child: SurahHeader(
                            title: widget.title,
                            color: primary,
                            surahId: widget.surahId),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 8.0),
                      child: Column(
                        children: [
                          if (widget.isQuran &&
                              widget.surahName != 'الفاتحة' &&
                              widget.surahName != 'التوبة') ...[
                            Text(
                              "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ",
                              style: TextStyle(
                                fontFamily: 'OmarNaskh',
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  Icons.star,
                                  size: 12,
                                  color: primary.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                          widget.isQuran &&
                                  widget.ayahs != null &&
                                  widget.ayahs!.isNotEmpty
                              ? Wrap(
                                  textDirection: TextDirection.rtl,
                                  alignment: WrapAlignment.center,
                                  children: widget.ayahs!.map((a) {
                                    String text =
                                        a['ar_text'].toString().trim();
                                    final index = a['anum']?.toString() ??
                                        a['ayah_surah_index'].toString();
                                    final arabicIndex =
                                        _convertToArabicNumber(index);

                                    text = text
                                        .replaceAll(_trailingNumbersRegex, '')
                                        .trim();

                                    final ayahIdxStr = a['anum']?.toString() ??
                                        a['ayah_surah_index'].toString();
                                    final int ayahIndex =
                                        int.tryParse(ayahIdxStr) ?? 0;

                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        setState(() {
                                          if (_bookmarkedLineIndex
                                                  ?.toString() ==
                                              ayahIndex.toString()) {
                                            _bookmarkedLineIndex = null;
                                            prefs.remove(
                                                'bookmark_line_${widget.title}');
                                          } else {
                                            _bookmarkedLineIndex = ayahIndex;
                                            prefs.setInt(
                                                'bookmark_line_${widget.title}',
                                                ayahIndex);
                                          }
                                        });
                                      },
                                      child: Text.rich(
                                        TextSpan(
                                          style: TextStyle(
                                            fontFamily: 'UthmanicHafs',
                                            fontSize: 32 * _factor,
                                            height: 1.8,
                                            color: dynamicTextColor,
                                          ),
                                          children: [
                                            TextSpan(text: '$text '),
                                            if (arabicIndex.isNotEmpty)
                                              WidgetSpan(
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Text(
                                                      '﴿$arabicIndex﴾',
                                                      style: TextStyle(
                                                        fontFamily: 'UthmanicHafs',
                                                        color: _bookmarkedLineIndex
                                                                    ?.toString() ==
                                                                ayahIndex
                                                                    .toString()
                                                            ? Colors
                                                                .green.shade900
                                                            : Colors.amber[700],
                                                        fontWeight:
                                                            _bookmarkedLineIndex
                                                                        ?.toString() ==
                                                                    ayahIndex
                                                                        .toString()
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                        fontSize: 24 * _factor,
                                                      ),
                                                    ),
                                                    if (_bookmarkedLineIndex
                                                            ?.toString() ==
                                                        ayahIndex.toString())
                                                      const Positioned(
                                                        top: -12,
                                                        child: Icon(Icons.star,
                                                            color: Colors.green,
                                                            size: 14),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            const TextSpan(text: ' '),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                      ),
                                    );
                                  }).toList(),
                                )
                              : Column(
                                  children: [
                                    if (widget.isImamAli) ...[
                                      Text(
                                        'قال أمير المؤمنين علي (عليه السلام)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'me_quran',
                                          fontSize: 26 * _factor,
                                          color: primary,
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                    ],
                                    if (widget.title.isNotEmpty &&
                                        !widget.isImamAli &&
                                        !widget.isQuran) ...[
                                      Text(
                                        widget.title,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'OmarNaskh',
                                          fontSize: 22 * _factor,
                                          height: 2.2,
                                          fontWeight: FontWeight.bold,
                                          color: widget.titleColor != null
                                              ? _parseColor(widget.titleColor!)
                                              : dynamicTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      Divider(
                                        color: primary.withValues(alpha: 0.3),
                                        thickness: 1,
                                      ),
                                      const SizedBox(height: 15),
                                    ],
                                    Builder(
                                      builder: (context) {
                                        final baseStyle =
                                            widget.isImamAli || widget.isQuran
                                                ? TextStyle(
                                                    fontFamily: widget.isQuran ? 'UthmanicHafs' : 'me_quran',
                                                    fontSize: 26 * _factor,
                                                    height: 1.8,
                                                    color: dynamicTextColor,
                                                  )
                                                : TextStyle(
                                                    fontFamily: 'OmarNaskh',
                                                    fontSize: 20 * _factor,
                                                    height: 2.2,
                                                    color: dynamicTextColor,
                                                  );

                                        String cleanContent = widget.content;
                                        cleanContent = cleanContent
                                            .replaceAll('### ', '');
                                        if (cleanContent
                                            .trim()
                                            .toLowerCase()
                                            .startsWith('html')) {
                                          cleanContent = cleanContent
                                              .trim()
                                              .substring(4)
                                              .trim();
                                        }
                                        cleanContent = cleanContent
                                            .replaceAll('\uFDFA',
                                                '(صلى الله عليه وآله)')
                                            .replaceAll(
                                                '\uFDFB', '(جل جلاله)')
                                            .replaceAll('!', '(عليه السلام)');
                                        cleanContent = cleanContent
                                            .replaceAll(
                                                RegExp(
                                                    r'<html>|<html|\bhtml\b',
                                                    caseSensitive: false),
                                                '')
                                            .trim();

                                        debugPrint(
                                            'HtmlContentRenderer built for section: ${widget.title} with bookmark: $_bookmarkedLineIndex');
                                        return HtmlContentRenderer(
                                          content: cleanContent,
                                          baseStyle: baseStyle,
                                          bookmarkedIndex: _bookmarkedLineIndex,
                                          onParagraphTapped: (index) async {
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            setState(() {
                                              if (_bookmarkedLineIndex
                                                      ?.toString() ==
                                                  index.toString()) {
                                                _bookmarkedLineIndex = null;
                                                prefs.remove(
                                                    'bookmark_line_${widget.title}');
                                              } else {
                                                _bookmarkedLineIndex = index;
                                                prefs.setInt(
                                                    'bookmark_line_${widget.title}',
                                                    index);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.star,
                                size: 12,
                                color: primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Text(
                      'لون البطاقة:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...[
                      null,
                      const Color(0xFFFDF5E6),
                      const Color(0xFFE0EEE0),
                      const Color(0xFFE6E6FA),
                      const Color(0xFF2C2C2C),
                    ].map(
                      (c) => GestureDetector(
                        onTap: () => setState(() => _customBgColor = c),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: c ?? Colors.grey[300],
                          child: _customBgColor == c
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.blue,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () =>
                          setState(() => _factor = max(0.5, _factor - 0.1)),
                    ),
                    const Text(
                      ' Aa ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          setState(() => _factor = min(3.0, _factor + 0.1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
