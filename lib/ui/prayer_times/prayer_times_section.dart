import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../data/data_manager.dart';
import '../../data/iraq_provinces.dart';
import '../../utils/string_extensions.dart';
import '../../services/prayer_times_service.dart';
import '../../services/quran_service.dart';
import '../../services/favorites_service.dart';
import '../../models/favorite_item.dart';
import '../../sections/html_content_renderer.dart';
import '../../ui/calendar/hijri_calendar_screen.dart';
import '../../ui/qibla/qibla_screen.dart';
import '../../presentation/screens/istikhara_screen.dart';
import '../../main.dart'; // For AlDhakereenApp globals


class PrayerTimesSection extends StatefulWidget {
  const PrayerTimesSection({super.key});
  @override
  State<PrayerTimesSection> createState() => _PrayerTimesSectionState();
}

class _PrayerTimesSectionState extends State<PrayerTimesSection> {
  Map<String, DateTime>? _prayerTimes;
  Position? _currentPosition;
  bool _loading = true;
  final PrayerTimesService _prayerService = PrayerTimesService();
  final Map<String, bool> _enabledPrayers = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  };
  final Map<String, bool> _fullScreenPrayers = {
    'fajr': false,
    'dhuhr': false,
    'asr': false,
    'maghrib': false,
    'isha': false,
  };
  bool _ignoreBatteryOptimizations = false;
  double _adhanVolume = 1.0;
  int _adhanPreAlert = 0;

  final Map<String, int> _manualAdjustments = {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  String _selectedProvince = "بغداد";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getLocationAndPrayers();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabledPrayers['fajr'] = prefs.getBool('adhan_fajr') ?? true;
      _enabledPrayers['dhuhr'] = prefs.getBool('adhan_dhuhr') ?? true;
      _enabledPrayers['asr'] = prefs.getBool('adhan_asr') ?? true;
      _enabledPrayers['maghrib'] = prefs.getBool('adhan_maghrib') ?? true;
      _enabledPrayers['isha'] = prefs.getBool('adhan_isha') ?? true;
      _fullScreenPrayers['fajr'] = prefs.getBool('fullscreen_fajr') ?? false;
      _fullScreenPrayers['dhuhr'] = prefs.getBool('fullscreen_dhuhr') ?? false;
      _fullScreenPrayers['asr'] = prefs.getBool('fullscreen_asr') ?? false;
      _fullScreenPrayers['maghrib'] =
          prefs.getBool('fullscreen_maghrib') ?? false;
      _fullScreenPrayers['isha'] = prefs.getBool('fullscreen_isha') ?? false;
      _ignoreBatteryOptimizations =
          prefs.getBool('ignore_battery_optimizations') ?? false;
      _adhanVolume = prefs.getDouble('adhan_volume') ?? 1.0;
      _adhanPreAlert = prefs.getInt('adhan_pre_alert') ?? 0;
      _manualAdjustments['fajr'] = prefs.getInt('adj_fajr') ?? 0;
      _manualAdjustments['dhuhr'] = prefs.getInt('adj_dhuhr') ?? 0;
      _manualAdjustments['asr'] = prefs.getInt('adj_asr') ?? 0;
      _manualAdjustments['maghrib'] = prefs.getInt('adj_maghrib') ?? 0;
      _manualAdjustments['isha'] = prefs.getInt('adj_isha') ?? 0;
      _selectedProvince = prefs.getString('prayer_city') ?? "بغداد";

      final lat = prefs.getDouble('gps_lat');
      final lon = prefs.getDouble('gps_lon');
      if (lat != null &&
          lon != null &&
          _selectedProvince == "الموقع الحالي (GPS)") {
        _currentPosition = Position(
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
    });
  }

  Future<void> _getLocationAndPrayers() async {
    try {
      Position pos;
      if (_currentPosition != null) {
        pos = _currentPosition!;
      } else {
        final coords = iraqProvinces[_selectedProvince]!;
        pos = Position(
          latitude: coords[0],
          longitude: coords[1],
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
      final pt = _prayerService.calculatePrayerTimes(pos);
      final db = DataManager.getDB();
      final todayStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (db != null &&
          db['settings'] != null &&
          db['settings']['adhan'] != null &&
          db['settings']['adhan']['manual_schedules'] != null) {
        final list = db['settings']['adhan']['manual_schedules'] as List;
        final manual = list.firstWhere(
          (s) => s['date'] == todayStr,
          orElse: () => null,
        );
        if (manual != null) {
          pt['fajr'] = _applyManualTime(pt['fajr']!, manual['fajr']);
          pt['dhuhr'] = _applyManualTime(pt['dhuhr']!, manual['dhuhr']);
          pt['asr'] = _applyManualTime(pt['asr']!, manual['asr']);
          pt['maghrib'] = _applyManualTime(pt['maghrib']!, manual['maghrib']);
          pt['isha'] = _applyManualTime(pt['isha']!, manual['isha']);
        }
      }
      setState(() {
        _prayerTimes = pt;
        _loading = false;
      });
      await _prayerService.scheduleAdhanNotifications(
        pos,
        _enabledPrayers,
        _manualAdjustments,
      );
    } catch (e) {
      debugPrint("Prayer times error: $e");
      setState(() => _loading = false);
    }
  }

  DateTime _applyManualTime(DateTime calc, String? man) {
    if (man == null || !man.contains(':')) return calc;
    try {
      final parts = man.split(':');
      final dt = DateTime(
        calc.year,
        calc.month,
        calc.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return calc.isUtc ? dt.toUtc() : dt;
    } catch (e) {
      return calc;
    }
  }

  Future<void> _useGPS() async {
    setState(() => _loading = true);
    final pos = await _prayerService.getCurrentLocation();
    if (pos != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('gps_lat', pos.latitude);
      await prefs.setDouble('gps_lon', pos.longitude);
      await prefs.setString('prayer_city', "الموقع الحالي (GPS)");
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _selectedProvince = "الموقع الحالي (GPS)";
      });
      _getLocationAndPrayers();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء منح صلاحية الوصول للموقع')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on),
                    const SizedBox(width: 10),
                    const Text(
                      'المحافظة:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _selectedProvince,
                      underline: const SizedBox(),
                      onChanged: (v) async {
                        if (v != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('prayer_city', v);
                          if (v != "الموقع الحالي (GPS)") {
                            await prefs.remove('gps_lat');
                            await prefs.remove('gps_lon');
                          }
                          setState(() {
                            _selectedProvince = v;
                            if (v != "الموقع الحالي (GPS)")
                              _currentPosition = null;
                            _loading = true;
                          });
                          _getLocationAndPrayers();
                        }
                      },
                      items: [
                        ...iraqProvinces.keys.map(
                          (p) => DropdownMenuItem(value: p, child: Text(p)),
                        ),
                        if (_selectedProvince == "الموقع الحالي (GPS)")
                          const DropdownMenuItem(
                            value: "الموقع الحالي (GPS)",
                            child: Text("الموقع الحالي (GPS)"),
                          ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                TextButton.icon(
                  onPressed: _useGPS,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    _currentPosition == null
                        ? 'استخدام الموقع الحالي (GPS)'
                        : 'موقعك محدد حالياً عبر GPS',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildPrayerCard('الفجر', _prayerTimes?['fajr'], 'fajr'),
          _buildPrayerCard('الظهر', _prayerTimes?['dhuhr'], 'dhuhr'),
          _buildPrayerCard('العصر', _prayerTimes?['asr'], 'asr'),
          _buildPrayerCard('المغرب', _prayerTimes?['maghrib'], 'maghrib'),
          _buildPrayerCard('العشاء', _prayerTimes?['isha'], 'isha'),
          const SizedBox(height: 30),
          const Divider(),
          const Text(
            'إعدادات الأذان والتنبيهات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          ..._enabledPrayers.keys.map(
            (k) => Card(
              margin: const EdgeInsets.only(bottom: 15),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'تفعيل أذان ${{
                        'fajr': 'الفجر',
                        'dhuhr': 'الظهر',
                        'asr': 'العصر',
                        'maghrib': 'المغرب',
                        'isha': 'العشاء'
                      }[k]}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: _enabledPrayers[k] ?? true,
                    onChanged: (v) async {
                      setState(() => _enabledPrayers[k] = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('adhan_$k', v);

                      Position pos;
                      if (_currentPosition != null) {
                        pos = _currentPosition!;
                      } else {
                        final coords = iraqProvinces[_selectedProvince]!;
                        pos = Position(
                          latitude: coords[0],
                          longitude: coords[1],
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
                      await _prayerService.rescheduleSinglePrayer(k, pos);
                    },
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              setState(() => _fullScreenPrayers[k] = false);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('fullscreen_$k', false);

                              Position pos;
                              if (_currentPosition != null) {
                                pos = _currentPosition!;
                              } else {
                                final coords = iraqProvinces[_selectedProvince]!;
                                pos = Position(
                                  latitude: coords[0],
                                  longitude: coords[1],
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
                              await _prayerService.rescheduleSinglePrayer(k, pos);
                            },
                            child: Card(
                              color: (_fullScreenPrayers[k] ?? false)
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                              elevation:
                                  (_fullScreenPrayers[k] ?? false) ? 0 : 2,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.notifications,
                                        color: (_fullScreenPrayers[k] ?? false)
                                            ? Colors.grey
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary),
                                    const SizedBox(height: 5),
                                    Text('إشعار',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                (_fullScreenPrayers[k] ?? false)
                                                    ? Colors.grey
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .primary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              setState(() => _fullScreenPrayers[k] = true);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('fullscreen_$k', true);

                              Position pos;
                              if (_currentPosition != null) {
                                pos = _currentPosition!;
                              } else {
                                final coords = iraqProvinces[_selectedProvince]!;
                                pos = Position(
                                  latitude: coords[0],
                                  longitude: coords[1],
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
                              await _prayerService.rescheduleSinglePrayer(k, pos);
                            },
                            child: Card(
                              color: (_fullScreenPrayers[k] ?? false)
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              elevation:
                                  (_fullScreenPrayers[k] ?? false) ? 2 : 0,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.fullscreen,
                                        color: (_fullScreenPrayers[k] ?? false)
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey),
                                    const SizedBox(height: 5),
                                    Text('شاشة كاملة',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                (_fullScreenPrayers[k] ?? false)
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مستوى الصوت',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        Slider(
                          value: _adhanVolume,
                          onChanged: (v) async {
                            setState(() => _adhanVolume = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setDouble('adhan_volume', v);
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('تنبيه قبل الأذان',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle:
                        const Text('دقائق', style: TextStyle(fontSize: 12)),
                    trailing: DropdownButton<int>(
                      value: _adhanPreAlert,
                      items: [0, 5, 10, 15, 20, 30].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value == 0 ? 'معطل' : '$value'),
                        );
                      }).toList(),
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => _adhanPreAlert = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('adhan_pre_alert', v);
                          _getLocationAndPrayers(); // Reschedule with pre alerts
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('قناة الإشعارات',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('إعدادات النظام للإشعارات',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.settings),
                    onTap: () async {
                      // Launch native Android notification settings for the app channel
                      await const MethodChannel('com.techtouchai.islamic/adhan')
                          .invokeMethod('openNotificationSettings');
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('تخطي وضع توفير الطاقة (Doze Mode)',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text('مطلوب لضمان عمل الأذان في وقته بدقة',
                        style: TextStyle(fontSize: 12)),
                    value: _ignoreBatteryOptimizations,
                    onChanged: (v) async {
                      setState(() => _ignoreBatteryOptimizations = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('ignore_battery_optimizations', v);
                      if (v) {
                        if (await Permission
                            .ignoreBatteryOptimizations.isDenied) {
                          await Permission.ignoreBatteryOptimizations.request();
                        }
                      }
                    },
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(String label, DateTime? utcTime, String key) {
    if (utcTime == null) return const SizedBox();
    final localTime = utcTime.toLocal();
    final adjTime = localTime.add(
      Duration(minutes: _manualAdjustments[key] ?? 0),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: const Text(
          'اضغط لتعديل الوقت يدوياً (دقائق)',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Text(
          intl.DateFormat('hh:mm a').format(adjTime),
          style: TextStyle(
            fontSize: 22,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        onTap: () async {
          final TimeOfDay? picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(adjTime),
          );
          if (picked != null) {
            final pickedDateTimeLocal = DateTime(
              localTime.year,
              localTime.month,
              localTime.day,
              picked.hour,
              picked.minute,
            );
            final diff = pickedDateTimeLocal.difference(localTime).inMinutes;

            // التحقق من الإزاحة الجديدة لضمان عدم التداخل
            final validatedDiff =
                _prayerService.validateOffset(key, diff, _prayerTimes!);

            setState(() {
              _manualAdjustments[key] = validatedDiff;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('adj_$key', validatedDiff);

            // إعادة جدولة ذكية لهذه الصلاة فقط لتقليل الاستهلاك
            Position pos;
            if (_currentPosition != null) {
              pos = _currentPosition!;
            } else {
              final coords = iraqProvinces[_selectedProvince]!;
              pos = Position(
                latitude: coords[0],
                longitude: coords[1],
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
            await _prayerService.rescheduleSinglePrayer(key, pos);

            if (validatedDiff != diff) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'تم ضبط الوقت لأقرب قيمة مسموح بها لمنع التداخل مع الصلاة المجاورة')),
              );
            }
          }
        },
      ),
    );
  }
}
