import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../data/data_manager.dart';
import '../../utils/string_extensions.dart';
import '../../services/prayer_times_service.dart';
import '../../services/quran_service.dart';
import '../../services/favorites_service.dart';
import '../../models/favorite_item.dart';
import '../../sections/html_content_renderer.dart';
import '../../ui/calendar/hijri_calendar_screen.dart';
import '../reader/reader_page.dart';
import '../../ui/qibla/qibla_screen.dart';
import '../../presentation/screens/istikhara_screen.dart';
import '../../main.dart'; // For AlDhakereenApp globals
import '../widgets/app_standard_card.dart';
import '../../theme/app_card_theme.dart';

class DynamicListSection extends StatefulWidget {
  final String title;
  final String sectionKey;
  final double fontSizeFactor;
  final double uiOpacity;
  const DynamicListSection({
    super.key,
    required this.title,
    required this.sectionKey,
    required this.fontSizeFactor,
    required this.uiOpacity,
  });

  @override
  State<DynamicListSection> createState() => _DynamicListSectionState();
}

class _DynamicListSectionState extends State<DynamicListSection> {
  Future<List<Map<String, dynamic>>>? _quranFuture;

  @override
  void initState() {
    super.initState();
    if (widget.sectionKey == 'quran') {
      _quranFuture = QuranService.getSurahs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQuran = widget.sectionKey == 'quran';
    if (isQuran) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _quranFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Text(
                "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ",
                style: TextStyle(
                  fontFamily: 'me_quran',
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء تحميل القرآن:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('لا توجد بيانات، يرجى التأكد من مساحة التخزين.'),
            );
          }
          final data = snapshot.data!;
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: data.length,
            padding: const EdgeInsets.only(bottom: 20),
            itemBuilder: (context, index) {
              final surah = data[index];
              return Card(
                color: Theme.of(context)
                    .cardColor
                    .withValues(alpha: widget.uiOpacity),
                margin:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.0,
                  ),
                ),
                child: InkWell(
                  onTap: () async {
                    final ayahs = await QuranService.getAyahs(surah['id']);
                    final content = QuranService.getFormattedContent(
                      surah['id'],
                      ayahs,
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => ReaderPage(
                          title: "سورة ${surah['name']}",
                          content: content,
                          fontSizeFactor: widget.fontSizeFactor,
                          isQuran: true,
                          surahName: surah['name'].toString(),
                          ayahs: ayahs,
                          surahId: surah['id'],
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Builder(
                              builder: (context) {
                                final surahId = surah['id'] as int;
                                final color = Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black;
                                // surah['surah_index'] usually contains the correct 1..114 index
                                // From the SQL dump we saw:
                                // Fatiha: id=2, surah_index=1
                                // Al-Ma'un: id=108, surah_index=107
                                // Kawthar: id=110, surah_index=108
                                // Kafirun: id=111, surah_index=109
                                // Nas: id=116, surah_index=114
                                // So surah_index perfectly maps to 1..114 matching the images.
                                int imageId = (surah['surah_index'] as int?) ??
                                    (surahId >= 110 ? surahId - 2 : (surahId == 108 ? 107 : surahId - 1));
                                return Image.asset(
                                  'assets/images/quran/quran_surah_names_$imageId.png',
                                  height: 50,
                                  fit: BoxFit.contain,
                                  color: color,
                                  colorBlendMode: BlendMode.srcIn,
                                );
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "آياتها ${surah['total_ayahs']}",
                            style: TextStyle(
                              fontFamily: 'OmarNaskh',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    final data = DataManager.getItems(widget.sectionKey);
    if (widget.sectionKey == 'names_allah') {
      return data.isEmpty
          ? const Center(child: Text('لا يوجد محتوى متوفر حالياً'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: data.length,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).cardColor.withValues(alpha: widget.uiOpacity * 0.8),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  data[index]['name']?.toString() ??
                      data[index]['title']?.toString() ??
                      '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20 * widget.fontSizeFactor,
                    fontFamily: 'me_quran',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
    }

    return Column(
      children: [
        Expanded(
          child: data.isEmpty
              ? const Center(child: Text('لا يوجد محتوى متوفر حالياً'))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: data.length,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemBuilder: (context, index) {
                    return AppStandardCard(
                      uiOpacity: widget.uiOpacity,
                      customPadding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Builder(builder: (context) {
                            String rawText = data[index]['content']
                                .toString()
                                .trim()
                                .replaceAll(
                                    RegExp(r'<html>|<html|^html\b',
                                        caseSensitive: false),
                                    ' ')
                                .trim();
                            String cleanSubtitle = rawText.cleanSnippet();

                            String displayTitle;
                            TextStyle titleStyle;
                            Color dynamicTextColor = Theme.of(context).cardColor.contrastTextColor;

                            if (widget.sectionKey == 'prophets_stories') {
                              String rawTitle = data[index]['title'].toString();
                              String cleanName = rawTitle
                                  .replaceAll(
                                      RegExp(r'قصة\s*|\s*\(?عليه السلام\)?',
                                          caseSensitive: false),
                                      '')
                                  .trim();
                              displayTitle = '$cleanName ﴿عليه السلام﴾';
                            } else if (widget.sectionKey.contains('imam_ali')) {
                              displayTitle =
                                  'قال أمير المؤمنين علي (عليه السلام)';
                            } else {
                              displayTitle = data[index]['title'].toString();
                            }

                            titleStyle = TextStyle(
                              fontFamily: AppCardTheme.fontFamily,
                              fontSize: 18 * widget.fontSizeFactor,
                              fontWeight: FontWeight.bold,
                              color: dynamicTextColor,
                            );

                            return ListTile(
                              contentPadding: AppCardTheme.padding,
                              title: Text(
                                displayTitle,
                                style: titleStyle,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => ReaderPage(
                                    title: data[index]['title'].toString(),
                                    content: data[index]['content'].toString(),
                                    fontSizeFactor: widget.fontSizeFactor,
                                    isQuran: false,
                                    isImamAli:
                                        widget.sectionKey.contains('imam_ali'),
                                    titleColor:
                                        data[index]['color']?.toString(),
                                  ),
                                ),
                              ),
                            );
                          }),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Builder(builder: (context) {
                              final itemId = data[index]['title'].toString();
                              return ValueListenableBuilder<List<FavoriteItem>>(
                                valueListenable:
                                    FavoritesService.instance.favoritesNotifier,
                                builder: (context, favorites, _) {
                                  final isFav = FavoritesService.instance
                                      .isFavorite(itemId);
                                  return IconButton(
                                    icon: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFav
                                          ? Colors.red
                                          : Theme.of(context).cardColor.contrastTextColor,
                                    ),
                                    onPressed: () {
                                      final item = FavoriteItem(
                                        id: itemId,
                                        title: data[index]['title'].toString(),
                                        content:
                                            data[index]['content'].toString(),
                                        sourceSection: widget.sectionKey,
                                        timestamp: DateTime.now(),
                                        isCustom: false,
                                      );
                                      FavoritesService.instance
                                          .toggleFavorite(item);
                                    },
                                  );
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
