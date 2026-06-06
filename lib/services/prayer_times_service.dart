import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pray_times.dart';
import 'prayer_alarm_service.dart';

/// خدمة أوقات الصلاة - تتبع معايير هندسة الكود النظيف (Clean Architecture)
/// تقوم بحساب الأوقات ديناميكياً بناءً على الموقع الجغرافي للمستخدم.
class PrayerTimesService with WidgetsBindingObserver {
  static final PrayerTimesService _instance = PrayerTimesService._internal();
  factory PrayerTimesService() => _instance;

  late PrayerTimesEngine _engine;

  PrayerTimesService._internal() {
    _engine = PrayTimes(PrayerCalculationParameters.jafari);
    _initLifecycleObserver();
  }

  void _initLifecycleObserver() {
    WidgetsFlutterBinding.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      forceReschedule().catchError((e) {
        debugPrint("Silent refresh failed on resume: $e");
      });
    }
  }

  void setEngine(PrayerTimesEngine engine) {
    _engine = engine;
  }

  /// طلب الصلاحيات وجلب الموقع الجغرافي الحالي مع التخزين المؤقت
  Future<Position?> getCurrentLocation() async {
    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }

      if (status.isGranted) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('cached_lat', pos.latitude);
          await prefs.setDouble('cached_lon', pos.longitude);

          return pos;
        } catch (timeoutOrError) {
          debugPrint("Location timeout or error, falling back: $timeoutOrError");
        }
      }
    } catch (e) {
      debugPrint("خطأ في جلب الموقع: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('cached_lat');
    final lon = prefs.getDouble('cached_lon');
    if (lat != null && lon != null) {
      return Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    return Position(
      latitude: 32.4682,
      longitude: 44.4361,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  /// حساب أوقات الصلاة - تستخدم UTC لضمان الثبات عبر المناطق الزمنية
  Map<String, DateTime> calculatePrayerTimes(
    Position position, {
    DateTime? date,
  }) {
    final calculationDate = date ?? DateTime.now();
    // نستخدم 0 كفارق زمني للحصول على التوقيت العالمي الموحد (UTC)
    const timeZoneOffset = 0.0;

    final times = _engine.getTimes(
      calculationDate,
      position.latitude,
      position.longitude,
      timeZoneOffset,
      elevation: 0.0,
    );

    // الأوقات المستلمة من المحرك هي بالفعل UTC
    return {
      'fajr': times['fajr']!,
      'sunrise': times['sunrise']!,
      'dhuhr': times['dhuhr']!,
      'asr': times['asr']!,
      'maghrib': times['maghrib']!,
      'isha': times['isha']!,
      'midnight': times['midnight']!,
    };
  }

  /// طبقة التحقق لمنع تداخل أوقات الصلاة عند التعديل اليدوي
  int validateOffset(String prayerKey, int requestedOffsetMinutes, Map<String, DateTime> baseTimes) {
    // تم إلغاء القيود بناءً على طلب المستخدم ليكون التعديل حراً بالكامل
    return requestedOffsetMinutes;
  }

  /// الجدولة الذكية (Smart Rescheduling) لصلاة محددة
  Future<void> rescheduleSinglePrayer(String prayerKey, Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final int offset = prefs.getInt('adj_$prayerKey') ?? 0;
    final bool isEnabled = prefs.getBool('adhan_$prayerKey') ?? true;

    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final baseTimes = calculatePrayerTimes(position, date: date);

      final int validatedOffset = validateOffset(prayerKey, offset, baseTimes);
      final DateTime time = baseTimes[prayerKey]!.add(Duration(minutes: validatedOffset));
      final String name = _getPrayerNameAr(prayerKey);

      final int id = i * 10 + _getPrayerId(prayerKey);

      // إلغاء التنبيه القديم قبل حجز الجديد
      await PrayerAlarmService.cancelPrayer(id);

      if (isEnabled && time.isAfter(DateTime.now())) {
        await _scheduleSingleNotification(id, name, time, isEnabled, prayerKey);
      }
    }
  }

  Future<void> scheduleAdhanNotificationsBackground() async {
    try {
      final pos = await getCurrentLocation();
      if (pos == null) return;
      await forceReschedule();
    } catch (e) {
      debugPrint("Background scheduling failed: $e");
    }
  }

  Future<void> forceReschedule() async {
    final pos = await getCurrentLocation();
    if (pos == null) return;

    final prefs = await SharedPreferences.getInstance();
    final enabledPrayers = {
      'fajr': prefs.getBool('adhan_fajr') ?? true,
      'dhuhr': prefs.getBool('adhan_dhuhr') ?? true,
      'asr': prefs.getBool('adhan_asr') ?? true,
      'maghrib': prefs.getBool('adhan_maghrib') ?? true,
      'isha': prefs.getBool('adhan_isha') ?? true,
    };

    final offsets = {
      'fajr': prefs.getInt('adj_fajr') ?? 0,
      'dhuhr': prefs.getInt('adj_dhuhr') ?? 0,
      'asr': prefs.getInt('adj_asr') ?? 0,
      'maghrib': prefs.getInt('adj_maghrib') ?? 0,
      'isha': prefs.getInt('adj_isha') ?? 0,
    };

    await scheduleAdhanNotifications(pos, enabledPrayers, offsets);
    await prefs.setString('last_bg_sync', DateTime.now().toIso8601String());
  }

  Future<void> scheduleAdhanNotifications(
    Position position,
    Map<String, bool> enabledPrayers,
    Map<String, int> offsets,
  ) async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final baseTimes = calculatePrayerTimes(position, date: date);

      baseTimes.forEach((key, time) {
        if (_getPrayerId(key) == 0) return; // تخطي الأوقات غير المخصصة للأذان مثل الشروق

        final int validatedOffset = validateOffset(key, offsets[key] ?? 0, baseTimes);
        final adjustedTime = time.add(Duration(minutes: validatedOffset));
        final name = _getPrayerNameAr(key);

        _scheduleSingleNotification(
          i * 10 + _getPrayerId(key),
          name,
          adjustedTime,
          enabledPrayers[key] ?? true,
          key,
        );
      });
    }
  }

  String _getPrayerNameAr(String key) {
    switch (key) {
      case 'fajr': return "الفجر";
      case 'dhuhr': return "الظهر";
      case 'asr': return "العصر";
      case 'maghrib': return "المغرب";
      case 'isha': return "العشاء";
      default: return "";
    }
  }

  int _getPrayerId(String key) {
    switch (key) {
      case 'fajr': return 1;
      case 'dhuhr': return 2;
      case 'asr': return 3;
      case 'maghrib': return 4;
      case 'isha': return 5;
      default: return 0;
    }
  }

  Future<void> _scheduleSingleNotification(
    int id,
    String name,
    DateTime time,
    bool isEnabled,
    String key,
  ) async {
    if (!isEnabled || time.isBefore(DateTime.now())) return;
    final prefs = await SharedPreferences.getInstance();
    final bool isFullScreen = prefs.getBool('fullscreen_$key') ?? false;
    final double volume = prefs.getDouble('adhan_volume') ?? 1.0;
    final int preAlert = prefs.getInt('adhan_pre_alert') ?? 0;

    await PrayerAlarmService.schedulePrayer(
      id,
      time,
      name,
      fullScreen: isFullScreen,
      volume: volume,
      preAlertMinutes: preAlert
    );
  }
}
