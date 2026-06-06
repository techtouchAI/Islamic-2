import 'package:flutter/material.dart';


import 'package:intl/intl.dart' as intl;

import 'dart:async';
import 'dart:ui';
import 'dart:math';



import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';




import '../../data/data_manager.dart';
import '../../data/daily_duas.dart';
import '../../utils/string_extensions.dart';
import '../../services/prayer_times_service.dart';
import '../../services/quran_service.dart';




import '../reader/reader_page.dart';

import '../../presentation/screens/istikhara_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/app_standard_card.dart';
import '../../theme/app_card_theme.dart';


class HomeSection extends StatefulWidget {
  final VoidCallback? onPrayerCardTap;
  const HomeSection({
    super.key,
    this.onPrayerCardTap,
  });

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> {
  String getExactWatermark(String tag) {
    if (tag.contains('إلهام')) return 'assets/images/Mscreen/إلهام اليوم.png';
    if (tag.contains('دعاء اليوم'))
      return 'assets/images/Mscreen/دعاء اليوم 2.png';
    if (tag.contains('قرآن') || tag.contains('قرأن'))
      return 'assets/images/Mscreen/القرأن الكريم.png';
    if (tag.contains('زيار')) return 'assets/images/Mscreen/الزيارات.png';
    if (tag.contains('سجادي') || tag.contains('صحيفة'))
      return 'assets/images/Mscreen/الصحيفة السجادية.png';
    if (tag.contains('حج')) return 'assets/images/Mscreen/بطاقة الحج.png';
    if (tag.contains('احلام') || tag.contains('أحلام'))
      return 'assets/images/Mscreen/تفسير الاحلام.png';
    if (tag.contains('علي') || tag.contains('موسوعة'))
      return 'assets/images/Mscreen/موسوعة الامام علي.png';
    return 'assets/images/Mscreen/جميع البطاقات التي ليس لها بطاقة.png';
  }

  static String? _cachedDuaKey;
  static Map<String, dynamic>? _cachedInspirationDua;
  static Map<String, dynamic>? _cachedDayDua;

  Map<String, dynamic> items = {};
  Map<String, dynamic>? _inspirationDua;
  Map<String, dynamic>? _dayDua;
  Map<String, DateTime>? _prayerTimes;
  final ValueNotifier<String> _currentPrayerNotifier = ValueNotifier<String>("");
  Timer? _prayerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshItems(context.read<SettingsProvider>());
      if (mounted) setState(() {});
    });
    _initPrayerTimes();
    _prayerTimer = Timer.periodic(
      const Duration(minutes: 1),
      (t) => _updateCurrentPrayer(),
    );
  }

  @override
  void dispose() {
    _prayerTimer?.cancel();
    _currentPrayerNotifier.dispose();
    super.dispose();
  }

  Future<void> _initPrayerTimes() async {
    final service = PrayerTimesService();
    final pos = await service.getCurrentLocation();
    if (pos != null) {
      _prayerTimes = service.calculatePrayerTimes(pos);
    } else {
      // Fallback to Baghdad if location is null
      final fallbackPos = Position(
        latitude: 33.3128,
        longitude: 44.3615,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _prayerTimes = service.calculatePrayerTimes(fallbackPos);
    }
    _updateCurrentPrayer();
  }

  void _updateCurrentPrayer() {
    if (_prayerTimes == null) return;
    final now = DateTime.now();
    String next = "الفجر";
    final sorted = _prayerTimes!.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (var e in sorted) {
      if (now.isBefore(e.value)) {
        next = _getArName(e.key);
        break;
      }
    }
    if (mounted) _currentPrayerNotifier.value = next;
  }

  String _getArName(String key) {
    const map = {
      'fajr': 'الفجر',
      'sunrise': 'الشروق',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
      'midnight': 'منتصف الليل',
    };
    return map[key] ?? key;
  }

  void _refreshItems(SettingsProvider settingsProvider) {
    final random = Random();
    final sections = DataManager.getSections();
    items = {};
    sections.forEach((key, value) {
      if (key == 'mafatih' || key == 'Mafatih_alJinan') return; // Hide Mafatih from Home Screen
      if (settingsProvider.homeVisibility[key] ?? true) {
        String fetchKey = key;
        if (key == 'visits') fetchKey = 'visits_general';
        if (key == 'duas') fetchKey = 'duas_general';

        List<dynamic> listToPickFrom = DataManager.getItems(fetchKey);

        if (key == 'dreams' && listToPickFrom.isNotEmpty) {
          final randomCat = _safeGet(listToPickFrom, random);
          final catId = randomCat['id']?.toString();
          if (catId != null) {
            listToPickFrom = DataManager.getItems('dreams_cat_$catId');
          }
        } else if (key == 'imam_ali' && listToPickFrom.isNotEmpty) {
          final randomCat = _safeGet(listToPickFrom, random);
          final catId = randomCat['id'];
          if (catId != null) {
            listToPickFrom = DataManager.getItems('imam_ali_cat_$catId');
          }
        } else if (key == 'fatawa' && listToPickFrom.isNotEmpty) {
          final randomCat = _safeGet(listToPickFrom, random);
          if (randomCat['items'] != null && randomCat['items'] is List) {
            listToPickFrom = randomCat['items'];
          }
        }

        final safeItem = Map<String, dynamic>.from(
          _safeGet(listToPickFrom, random),
        );

        // removed UI hack

        safeItem['sectionKey'] = key;
        items[value['title']] = safeItem;
      }
    });
  }

  void _loadDailyDua() {
    final now = DateTime.now();
    final dateKey = intl.DateFormat('yyyy-MM-dd').format(now);
    final cacheKey = "${dateKey}_${DataManager.dbNotifier.value}";

    if (_cachedDuaKey == cacheKey) {
      _inspirationDua = _cachedInspirationDua;
      _dayDua = _cachedDayDua;
      return;
    }

    final dayOfYear = int.parse(intl.DateFormat('D').format(now));
    _inspirationDua =
        DailyDuas.shortDuas[dayOfYear % DailyDuas.shortDuas.length];

    final dayNameAr = intl.DateFormat('EEEE', 'ar_SA').format(now);
    final allDaysDuas = DataManager.getItems('duas_days');

    final normalizedDay = dayNameAr.normalizeArabic();

    final itemsForToday = allDaysDuas.where((it) {
      if (it['_normalized_title'] == null) {
        it['_normalized_title'] = it['title'].toString().normalizeArabic();
      }
      final title = it['_normalized_title'] as String;
      return title.contains(normalizedDay);
    }).toList();

    if (itemsForToday.isNotEmpty) {
      String combinedTitle = "أعمال يوم $dayNameAr";
      StringBuffer combinedContent = StringBuffer();
      for (var it in itemsForToday) {
        combinedContent.writeln("✨ ${it['title']} ✨");
        combinedContent.writeln("${it['content']}");
        combinedContent.writeln("");
      }
      _dayDua = {
        "title": combinedTitle,
        "content": combinedContent.toString().trim(),
      };
    } else {
      _dayDua = null;
    }

    _cachedDuaKey = cacheKey;
    _cachedInspirationDua = _inspirationDua;
    _cachedDayDua = _dayDua;
  }

  dynamic _safeGet(List list, Random r) {
    if (list.isEmpty) return {'title': 'قريباً', 'content': ''};
    return list[r.nextInt(list.length)];
  }

  Widget _buildSpecialCard(SettingsProvider settingsProvider,
    BuildContext context,
    String tag,
    Map<String, dynamic> data,
    Color textColor,
    IconData icon,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => ReaderPage(
            title: data['title'].toString(),
            content: data['content'].toString(),
            fontSizeFactor: settingsProvider.fontSizeFactor,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: settingsProvider.cardColor.withValues(
                        alpha: settingsProvider.uiOpacity * 0.8,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (tag == 'دعاء اليوم'
                    ? -40
                    : (tag == 'إلهام اليوم' ? 10 : -20)),
                bottom: tag == 'دعاء اليوم'
                    ? null
                    : (tag == 'إلهام اليوم' ? 10 : -20),
                top: tag == 'دعاء اليوم' ? -20 : null,
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    getExactWatermark(tag),
                    width: (tag == 'إلهام اليوم' ? 120 : 150),
                    height: (tag == 'إلهام اليوم' ? 120 : 150),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(tag == 'إلهام اليوم' ? 16 : 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: tag == 'دعاء اليوم' ? 6 : 12),
                        Text(
                          tag,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['content'].toString(),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'OmarNaskh',
                        fontSize: 17,
                        height: 1.9,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        data["title"].toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    _loadDailyDua();
    final nowTime = DateTime.now();
    bool isDayTime = false;
    if (_prayerTimes != null &&
        _prayerTimes!.containsKey('sunrise') &&
        _prayerTimes!.containsKey('maghrib')) {
      final sunrise = _prayerTimes!['sunrise']!;
      final maghrib = _prayerTimes!['maghrib']!;
      isDayTime = nowTime.isAfter(sunrise) && nowTime.isBefore(maghrib);
    } else {
      isDayTime = nowTime.hour >= 6 && nowTime.hour < 18;
    }

    final now = DateTime.now();
    final hijri = HijriCalendar.fromDate(
        DateTime.now().add(Duration(days: settingsProvider.hijriAdjustment)));
    final bool isDarkCard = settingsProvider.cardColor.computeLuminance() < 0.5;
    final Color textColor = isDarkCard ? Colors.white : Colors.black87;
    // Process items into rows for lazy loading
    List<List<MapEntry<String, dynamic>>> groupedRows = [];
    List<MapEntry<String, dynamic>> currentRow = [];

    for (var e in items.entries) {
      bool isFullWidth = e.key.contains('علي') ||
          e.key.contains('موسوعة') ||
          e.key.contains('istikhara');
      if (isFullWidth) {
        if (currentRow.isNotEmpty) {
          groupedRows.add(List.from(currentRow));
          currentRow.clear();
        }
        groupedRows.add([e]);
      } else {
        currentRow.add(e);
        if (currentRow.length == 2) {
          groupedRows.add(List.from(currentRow));
          currentRow.clear();
        }
      }
    }
    if (currentRow.isNotEmpty) {
      groupedRows.add(List.from(currentRow));
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                InkWell(
                  onTap: widget.onPrayerCardTap,
                  borderRadius: BorderRadius.circular(25),
                  child: Card(
                    elevation: 10,
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: settingsProvider.uiOpacity)
                        : Colors.black.withValues(alpha: settingsProvider.uiOpacity),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: -20,
                          bottom: -20,
                          child: Opacity(
                            opacity: 0.5,
                            child: Image.asset(
                              isDayTime
                                  ? 'assets/images/Mscreen/بطاقة الساعة والتقويم النهاري.png'
                                  : 'assets/images/Mscreen/بطاقة الساعة والتقويم الليلي.png',
                              width: 150,
                              height: 150,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 15,
                          ),
                          child: Column(
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: _currentPrayerNotifier,
                                builder: (context, currentPrayerName, child) {
                                  if (currentPrayerName.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          "الصلاة القادمة: $currentPrayerName",
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  );
                                },
                              ),
                              _ClockWidget(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} هـ'
                                    .toEasternArabic(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                intl.DateFormat(
                                  'EEEE, d MMMM yyyy',
                                  'ar_SA',
                                ).format(now).toEasternArabic(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_dayDua != null && (settingsProvider.homeVisibility['day_dua'] ?? true))
                  _buildSpecialCard(
                    settingsProvider,
                    context,
                    'دعاء اليوم',
                    _dayDua!,
                    textColor,
                    Icons.calendar_today,
                  ),
                if (_dayDua != null && (settingsProvider.homeVisibility['day_dua'] ?? true))
                  const SizedBox(height: 15),
                if (_inspirationDua != null &&
                    (settingsProvider.homeVisibility['inspiration'] ?? true))
                  _buildSpecialCard(
                    settingsProvider,
                    context,
                    'إلهام اليوم',
                    _inspirationDua!,
                    textColor,
                    Icons.auto_awesome,
                  ),
                const SizedBox(height: 25),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'مقتطفات إيمانية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              ]),
            ),
          ),
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 20),
            sliver: SliverList.builder(
              itemCount: groupedRows.length,
              itemBuilder: (context, index) {
                final rowItems = groupedRows[index];

                Widget buildCard(MapEntry<String, dynamic> e) {
                  return RepaintBoundary(
                    child: _HomeSmallCard(
                      tag: e.key,
                      title: e.value['sectionKey']
                                  ?.toString()
                                  .contains('imam_ali') ==
                              true
                          ? 'قال أمير المؤمنين علي (عليه السلام)'
                          : e.value['title'].toString(),
                      uiOpacity: settingsProvider.uiOpacity,
                      cardColor: settingsProvider.cardColor,
                      watermarkPath: getExactWatermark(e.key),
                      isFullWidth: e.key.contains('علي') ||
                          e.key.contains('موسوعة') ||
                          e.key.contains('istikhara'),
                      onTap: () async {
                        final sectionKey = e.value['sectionKey'];
                        if (sectionKey == 'istikhara') {
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const IstikharaScreen(),
                            ),
                          );
                          return;
                        }
                        final isQuran = sectionKey == 'quran';
                        List<Map<String, dynamic>>? ayahs;
                        String contentStr = e.value['content'].toString();

                        if (isQuran) {
                          final surahId = e.value['id'];
                          if (surahId != null) {
                            ayahs = await QuranService.getAyahs(surahId);
                            contentStr = QuranService.getFormattedContent(
                              surahId,
                              ayahs,
                            );
                          }
                        }

                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => ReaderPage(
                              title: e.value['title'].toString(),
                              content: contentStr,
                              fontSizeFactor: settingsProvider.fontSizeFactor,
                              isQuran: isQuran,
                              isImamAli: sectionKey.contains('imam_ali'),
                              surahName: isQuran
                                  ? e.value['title'].toString().replaceAll(
                                        'سورة ',
                                        '',
                                      )
                                  : null,
                              ayahs: ayahs,
                              surahId: isQuran ? e.value['id'] : null,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                if (rowItems.length == 1 &&
                    (rowItems[0].key.contains('علي') ||
                        rowItems[0].key.contains('موسوعة') ||
                        rowItems[0].key.contains('istikhara'))) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: buildCard(rowItems[0]),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: buildCard(rowItems[0]),
                      ),
                      const SizedBox(width: 12.0),
                      if (rowItems.length > 1)
                        Expanded(
                          child: buildCard(rowItems[1]),
                        )
                      else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSmallCard extends StatelessWidget {
  final String tag, title;
  final double uiOpacity;
  final Color cardColor;
  final String watermarkPath;
  final bool isFullWidth;
  final VoidCallback onTap;
  const _HomeSmallCard({
    required this.tag,
    required this.title,
    required this.uiOpacity,
    required this.cardColor,
    required this.watermarkPath,
    this.isFullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = cardColor.contrastTextColor;
    return SizedBox(
      width: isFullWidth
          ? double.infinity
          : (MediaQuery.of(context).size.width - 48) / 2,
      height: 100,
      child: AppStandardCard(
        uiOpacity: uiOpacity,
        onTap: onTap,
        customMargins: EdgeInsets.zero,
        customPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              left: -10,
              top: 10,
              bottom: 10,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  watermarkPath,
                  width: (tag.contains('قرآن') ||
                          tag.contains('قرأن') ||
                          tag.contains('سجادي') ||
                          tag.contains('صحيفة') ||
                          tag.contains('احلام') ||
                          tag.contains('أحلام'))
                      ? 60
                      : 80,
                  height: (tag.contains('قرآن') ||
                          tag.contains('قرأن') ||
                          tag.contains('سجادي') ||
                          tag.contains('صحيفة') ||
                          tag.contains('احلام') ||
                          tag.contains('أحلام'))
                      ? 60
                      : 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockWidget extends StatefulWidget {
  final Color color;
  const _ClockWidget({required this.color});
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  final ValueNotifier<String> _timeNotifier = ValueNotifier<String>("");
  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _timeNotifier.dispose();
    super.dispose();
  }

  void _updateTime() {
    final String formattedTime = intl.DateFormat(
      'hh:mm:ss a',
      'en_US',
    ).format(DateTime.now());
    _timeNotifier.value = formattedTime
        .replaceFirst('AM', 'ص')
        .replaceFirst('PM', 'م')
        .toEasternArabic();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<String>(
        valueListenable: _timeNotifier,
        builder: (context, value, child) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: widget.color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
