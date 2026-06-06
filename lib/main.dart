import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'services/analytics_service.dart';
import 'sections/html_content_renderer.dart';

import 'sections/tasbih_section.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:hijri/hijri_calendar.dart';

import 'data/data_manager.dart';
import 'services/quran_service.dart';
import 'services/favorites_service.dart';
import 'services/prayer_alarm_service.dart';
import 'sections/favorites_section.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/search_engine.dart';
import 'search/screens/search_screen.dart';
import 'ui/calendar/hijri_calendar_screen.dart';
import 'ui/qibla/qibla_screen.dart';

import 'ui/widgets/app_drawer.dart';
import 'ui/splash_screen.dart';
import 'ui/home/home_section.dart';
import 'ui/about/about_section.dart';
import 'ui/tabs/tabbed_section.dart';
import 'ui/dynamic_list/dynamic_list_section.dart';
import 'ui/reader/reader_page.dart';
import 'ui/settings/settings_section.dart';
import 'ui/prayer_times/prayer_times_section.dart';
import 'ui/mafatih/mafatih_section.dart';

import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/screens/istikhara_screen.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'providers/settings_provider.dart';
import 'services/ota_service.dart';

class IslamicPatternPainter extends CustomPainter {
  final Color color;
  IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double step = 60;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        final center = Offset(x, y);
        _drawStar(canvas, center, step * 0.4, paint);
        canvas.drawCircle(center, step * 0.1, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      double angle = (i * 45) * pi / 180;
      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      double nextAngle = (i * 45 + 22.5) * pi / 180;
      double nextX = center.dx + (radius * 0.7) * cos(nextAngle);
      double nextY = center.dy + (radius * 0.7) * sin(nextAngle);
      path.lineTo(nextX, nextY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

IconData getMaterialIcon(String? name) {
  const iconMap = {
    'menu_book': Icons.menu_book,
    'auto_stories': Icons.auto_stories,
    'place': Icons.place,
    'translate': Icons.translate,
    'bedtime': Icons.bedtime,
    'history_edu': Icons.history_edu,
    'shield': Icons.shield,
    'favorite': Icons.favorite,
    'home': Icons.home,
    'settings': Icons.settings,
    'person': Icons.person,
    'notes': Icons.notes,
    'notifications': Icons.notifications,
    'search': Icons.search,
    'mosque': Icons.mosque,
    'book': Icons.book,
    'event': Icons.event,
    'info': Icons.info,
    'group': Icons.group,
    'verified': Icons.verified,
    'code': Icons.code,
  };
  return iconMap[name] ?? Icons.star;
}

Widget buildImage(String? path, {double? height, BoxFit fit = BoxFit.contain}) {
  if (path == null || path.isEmpty) {
    return const SizedBox();
  }
  if (path.startsWith('/')) {
    // Check for local file path
    final file = File(path);
    if (file.existsSync()) return Image.file(file, height: height, fit: fit);
  }
  if (path.startsWith('data:image')) {
    try {
      final bytes = Uri.parse(path).data!.contentAsBytes();
      return Image.memory(
        Uint8List.fromList(bytes),
        height: height,
        fit: fit,
        errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
      );
    } catch (e) {
      return const Icon(Icons.broken_image);
    }
  }
  if (path.startsWith('https://')) {
    return Image.network(
      path,
      height: height,
      fit: fit,
      errorBuilder: (c, e, s) => const Icon(Icons.error),
    );
  }
  return Image.asset(
    path,
    height: height,
    fit: fit,
    errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قواعد البيانات المحلية السريعة أولاً ليتمكن التطبيق من الإقلاع فوراً
  await Hive.initFlutter();
  await FavoritesService.instance.init();

  // تشغيل الواجهة فوراً لإنهاء شاشة الانتظار
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const AlDhakereenApp(),
    ),
  );

  // تهيئة الخدمات الثقيلة في الخلفية لتجنب تجميد الشاشة
  _initializeHeavyServices();
}

Future<void> _initializeHeavyServices() async {
  try {
    await Firebase.initializeApp();
    AnalyticsService().checkAndRegisterDevice();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  try {
    await PrayerAlarmService.init();
  } catch (e) {
    debugPrint("PrayerAlarmService initialization error: $e");
  }
}

class AlDhakereenApp extends StatefulWidget {
  const AlDhakereenApp({super.key});
  @override
  State<AlDhakereenApp> createState() => _AlDhakereenAppState();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _AlDhakereenAppState extends State<AlDhakereenApp> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    if (!settingsProvider.isLoaded)
      return const Center(child: CircularProgressIndicator());

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'الذاكرين',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.of(
            context,
          ).textScaler, // Respects system font scaling
        ),
        child: child!,
      ),
      navigatorObservers: [routeObserver],
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Cairo'),
        colorScheme: ColorScheme.fromSeed(
          seedColor: settingsProvider.primaryColor,
          brightness: Brightness.light,
          primary: settingsProvider.primaryColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Cairo'),
        colorScheme: ColorScheme.fromSeed(
          seedColor: settingsProvider.primaryColor,
          brightness: Brightness.dark,
          primary: settingsProvider.primaryColor,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      themeMode: settingsProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDeferredTasks();
    });
  }

  Future<void> _runDeferredTasks() async {
    // 1. Initialize Search Engine in background
    SearchEngine.instance.init();

    // 2. Trigger async data sync and set up a reactive listener for updates.
    _setupUpdateListener();
  }

  void _setupUpdateListener() {
    bool hasCheckedForUpdates = false;

    void triggerUpdateCheck() {
      if (!hasCheckedForUpdates) {
        hasCheckedForUpdates = true;
        _checkForUpdatesSafe();
      }
    }

    // Sync cloud data asynchronously
    DataManager.syncCloudData()
        .then((didUpdate) {
          // Whether sync was successful, identical to local cache, or failed internally,
          // trigger the update check once it concludes.
          triggerUpdateCheck();
        })
        .catchError((e) {
          debugPrint("Cloud sync failed during deferred tasks: $e");
          // Even if the outer future throws (unlikely due to internal try/catch), attempt update check on the local cache just in case.
          triggerUpdateCheck();
          return false;
        });
  }

  Future<void> _checkForUpdatesSafe() async {
    if (!mounted) return;

    try {
      final response = await Dio().get(
        'https://api.github.com/repos/techtouchAI/Islamic/releases/latest',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data;
        final String tagName = data['tag_name']?.toString() ?? '';
        int? latestVersionCode;

        if (tagName.contains('-')) {
          latestVersionCode = int.tryParse(tagName.split('-').last);
        } else if (tagName.contains('+')) {
          latestVersionCode = int.tryParse(tagName.split('+').last);
        }

        if (latestVersionCode == null) {
          throw Exception("لم أتمكن من قراءة رقم الإصدار من: '$tagName'");
        }

        final PackageInfo info = await PackageInfo.fromPlatform();
        final currentVersionCode = int.tryParse(info.buildNumber) ?? 1;

        final String releaseNotes = '✨ يتوفر الآن تحديث جديد للتطبيق!\n\nقمنا بإضافة تحسينات وإصلاحات جديدة لضمان أفضل تجربة لك. يرجى التحديث الآن.';
        String updateUrl = '';
        final assets = data['assets'];
        if (assets != null && assets is List && assets.isNotEmpty) {
          updateUrl = assets[0]['browser_download_url']?.toString() ?? '';
        }

        if (updateUrl.isEmpty) {
          throw Exception("رابط التحميل (APK) غير موجود في جيت هاب");
        }

        // التحقق من الشرط الرياضي وإظهار النافذة
        if (currentVersionCode < latestVersionCode) {
          _showUpdateDialog(false, updateUrl, releaseNotes, null);
        }
      } else {
        throw Exception("فشل الاتصال، رمز الخطأ: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;

      // Silent fail on network errors
      if (e is DioException && e.type == DioExceptionType.connectionError) {
        return;
      }
      if (e is SocketException) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التحديث: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showUpdateDialog(bool forceUpdate, String updateUrl, String releaseNotes, String? checksum) {
    final rootContext = navigatorKey.currentContext;
    if (rootContext == null) return;

    showDialog(
      context: rootContext,
      barrierDismissible: !forceUpdate,
      builder: (contextBuilder) {
        return ValueListenableBuilder<double>(
          valueListenable: OTAService.instance.downloadProgress,
          builder: (context, downloadProgress, child) {
            final isDownloading = downloadProgress >= 0;
            return PopScope(
              canPop: !forceUpdate && !isDownloading,
              child: AlertDialog(
                title: const Text('تحديث متوفر', textAlign: TextAlign.right),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(releaseNotes, textAlign: TextAlign.right),
                    if (isDownloading) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(value: downloadProgress),
                      const SizedBox(height: 10),
                      Text('${(downloadProgress * 100).toStringAsFixed(0)}%'),
                    ],
                  ],
                ),
                actions: [
                  if (!forceUpdate && !isDownloading)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('تخطي'),
                    ),
                  if (!isDownloading)
                    ElevatedButton(
                      onPressed: () {
                        OTAService.instance.downloadAndInstallApk(
                          updateUrl,
                          checksum,
                          onError: (errorMessage) {
                            ScaffoldMessenger.of(contextBuilder).showSnackBar(
                              SnackBar(content: Text(errorMessage, textAlign: TextAlign.center)),
                            );
                          },
                        );
                      },
                      child: const Text('تحديث الآن'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _currentSection = 'home';
  final List<String> _history = ['home'];

  void _navigateTo(String section) {
    if (_currentSection == section) return;
    setState(() {
      _history.add(section);
      _currentSection = section;
    });
  }

  void _onBack() {
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _currentSection = _history.last;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSubPage = _history.length > 1;
    return ValueListenableBuilder<int>(
      valueListenable: DataManager.dbNotifier,
      builder: (context, _, __) {
        final settingsProvider = context.watch<SettingsProvider>();
        return PopScope(
          canPop: !isSubPage,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _onBack();
          },
          child: Scaffold(
            drawer: AppDrawer(
              currentSection: _currentSection,
              onNavigate: (section) {
                Navigator.pop(context);
                _navigateTo(section);
              },
            ),
            appBar: AppBar(
              title: Text(
                _getAppBarTitle(_currentSection),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor
                  ?.withValues(alpha: settingsProvider.uiOpacity),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.notes),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'القائمة',
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchScreen(
                          fontSizeFactor: settingsProvider.fontSizeFactor,
                        ),
                      ),
                    );
                  },
                  tooltip: 'بحث شامل',
                ),
                if (isSubPage)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _onBack,
                    tooltip: 'رجوع',
                  ),
                if (!isSubPage) const SizedBox(width: 4),
              ],
            ),
            body: Stack(
              children: [
                if (_currentSection == 'home') ...[
                  if (settingsProvider.backgroundImagePath != null)
                    Positioned.fill(
                      child: Image.file(
                        File(settingsProvider.backgroundImagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (settingsProvider.backgroundImagePath == null)
                    Positioned.fill(
                      child: buildImage(
                        settingsProvider.selectedBase64Bg ??
                            DataManager.getSettings()['custom_bg_base64']
                                ?.toString() ??
                            DataManager.getSettings()['bg_image']?.toString(),
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: CustomPaint(
                      painter: IslamicPatternPainter(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    switch (_currentSection) {
      case 'mafatih':
        return MafatihSection(
          key: const ValueKey('mafatih'),
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'home':
        return HomeSection(
          key: const ValueKey('home'),
          onPrayerCardTap: () => _navigateTo('prayer_times'),
        );
      case 'settings':
        return const SettingsSection(key: ValueKey('settings'));

      case 'favorites':
        return FavoritesSection(
          key: const ValueKey('favorites'),
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'about':
        return const AboutSection(key: ValueKey('about'));
      case 'tasbih':
        return const TasbihSection(key: ValueKey('tasbih'));
      case 'prayer_times':
        return const PrayerTimesSection(key: ValueKey('prayer_times'));
      case 'qibla':
        return QiblaScreen();
      case 'calendar':
        return HijriCalendarScreen();
      case 'duas':
        return TabbedSection(
          key: const ValueKey('duas'),
          tabs: const [
            'أدعية الأيام',
            'تعقيبات الصلاة',
            'الأدعية العامة',
            'الصلوات',
          ],
          sectionKeys: const [
            'duas_days',
            'duas_taqeebat',
            'duas_general',
            'duas_salawat',
          ],
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'visits':
        return TabbedSection(
          key: const ValueKey('visits'),
          tabs: const ['زيارات الأيام', 'الزيارات العامة'],
          sectionKeys: const ['visits_days', 'visits_general'],
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'adhkar':
        return TabbedSection(
          key: const ValueKey('adhkar'),
          tabs: const ['المناجاة', 'التسبيحات'],
          sectionKeys: const ['adhkar_munajat', 'adhkar_tasbihs'],
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'imam_ali':
        final imamAliCats = DataManager.getItems('imam_ali');
        if (imamAliCats.isEmpty) {
          return const Center(child: Text('لا يوجد محتوى متوفر حالياً'));
        }
        return TabbedSection(
          key: const ValueKey('imam_ali'),
          tabs: imamAliCats.map((c) => c['title'].toString()).toList(),
          sectionKeys: imamAliCats
              .map((c) => 'imam_ali_cat_${c['id']}')
              .toList(),
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'dreams':
        final dreamsCats = DataManager.getItems('dreams');
        if (dreamsCats.isEmpty) {
          return const Center(child: Text('لا يوجد محتوى متوفر حالياً'));
        }
        return TabbedSection(
          key: const ValueKey('dreams'),
          tabs: dreamsCats.map((c) => c['title'].toString()).toList(),
          sectionKeys: dreamsCats.map((c) => 'dreams_cat_${c['id']}').toList(),
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'fatawa':
        final fatawaCats = DataManager.getItems('fatawa');
        if (fatawaCats.isEmpty) {
          return const Center(child: Text('لا يوجد محتوى متوفر حالياً'));
        }
        return TabbedSection(
          key: const ValueKey('fatawa'),
          tabs: fatawaCats.map((c) => c['title'].toString()).toList(),
          sectionKeys: fatawaCats.map((c) => 'fatawa_cat_${c['id']}').toList(),
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'prophets_stories':
        return DynamicListSection(
          key: const ValueKey('prophets_stories'),
          title: _getSectionTitle('prophets_stories'),
          sectionKey: 'prophets_stories',
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
      case 'istikhara':
        return IstikharaScreen(key: const ValueKey('istikhara'));
      default:
        return DynamicListSection(
          key: ValueKey(_currentSection),
          title: _getSectionTitle(_currentSection),
          sectionKey: _currentSection,
          fontSizeFactor: settingsProvider.fontSizeFactor,
          uiOpacity: settingsProvider.uiOpacity,
        );
    }
  }

  String _getSectionTitle(String key) {
    final sections = DataManager.getSections();
    if (sections.containsKey(key)) return sections[key]['title'].toString();
    return 'المحتوى';
  }

  String _getAppBarTitle(String section) {
    if (section == 'home') return 'الذاكرين';
    if (section == 'settings') return 'الإعدادات';
    if (section == 'about') return 'حول المطور';
    if (section == 'universal_batch') return 'استيراد بالدفعة';
    return _getSectionTitle(section);
  }
}
