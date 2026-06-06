import 'package:flutter/foundation.dart';
import '../data_manager.dart';
import 'package:hijri/hijri_calendar.dart';

class CalendarEvent {
  final String title;
  final String? description;
  final bool isImportant;

  CalendarEvent({
    required this.title,
    this.description,
    this.isImportant = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CalendarEvent(title: 'غير معروف');
    }
    return CalendarEvent(
      title: json['title']?.toString() ?? 'بدون عنوان',
      description: json['description']?.toString().isNotEmpty == true ? json['description'].toString() : null,
      isImportant: json['isImportant'] == true,
    );
  }
}

class AstronomicalEvent {
  final String title;
  final String? description;

  AstronomicalEvent({
    required this.title,
    this.description,
  });

  factory AstronomicalEvent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AstronomicalEvent(title: 'غير معروف');
    }
    return AstronomicalEvent(
      title: json['title']?.toString() ?? 'بدون عنوان',
      description: json['description']?.toString().isNotEmpty == true ? json['description'].toString() : null,
    );
  }
}

class HijriDayData {
  final int day;
  final List<CalendarEvent> events;
  final List<AstronomicalEvent> astronomicalEvents;

  HijriDayData({
    required this.day,
    required this.events,
    required this.astronomicalEvents,
  });

  factory HijriDayData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return HijriDayData(day: 1, events: [], astronomicalEvents: []);
    }

    List<CalendarEvent> parsedEvents = [];
    if (json['events'] is List) {
      for (var e in json['events']) {
        try {
          if (e is Map<String, dynamic>) {
            parsedEvents.add(CalendarEvent.fromJson(e));
          }
        } catch (err) {
          debugPrint('Error parsing event: $err');
        }
      }
    }

    List<AstronomicalEvent> parsedAstroEvents = [];
    if (json['astronomical_events'] is List) {
      for (var e in json['astronomical_events']) {
        try {
          if (e is Map<String, dynamic>) {
            parsedAstroEvents.add(AstronomicalEvent.fromJson(e));
          }
        } catch (err) {
          debugPrint('Error parsing astronomical event: $err');
        }
      }
    }

    return HijriDayData(
      day: json['day'] is int ? json['day'] : int.tryParse(json['day']?.toString() ?? '1') ?? 1,
      events: parsedEvents,
      astronomicalEvents: parsedAstroEvents,
    );
  }
}

class HijriMonthData {
  final int year;
  final int month;
  final int totalDays;
  final String expectedGregorianStart;
  final List<HijriDayData> days;

  HijriMonthData({
    required this.year,
    required this.month,
    required this.totalDays,
    required this.expectedGregorianStart,
    required this.days,
  });

  factory HijriMonthData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return HijriMonthData(
        year: 1446,
        month: 1,
        totalDays: 30,
        expectedGregorianStart: DateTime.now().toIso8601String().split('T').first,
        days: [],
      );
    }

    List<HijriDayData> parsedDays = [];
    if (json['days'] is List) {
      for (var dayObj in json['days']) {
        try {
          if (dayObj is Map<String, dynamic>) {
            parsedDays.add(HijriDayData.fromJson(dayObj));
          }
        } catch (e) {
          debugPrint('Error parsing day: $e');
        }
      }
    }

    return HijriMonthData(
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? '1446') ?? 1446,
      month: json['month'] is int ? json['month'] : int.tryParse(json['month']?.toString() ?? '1') ?? 1,
      totalDays: json['total_days'] is int ? json['total_days'] : int.tryParse(json['total_days']?.toString() ?? '30') ?? 30,
      expectedGregorianStart: json['expected_gregorian_start']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
      days: parsedDays,
    );
  }
}

class CalendarRepository {
  static Future<HijriMonthData> getMonthDataAsync(int year, int month) async {
    return getMonthData(year, month);
  }

  static HijriMonthData getMonthData(int year, int month) {
    final db = DataManager.getDB();
    if (db != null && db['hijri_calendar'] != null) {
      final monthsData = db['hijri_calendar'];
      if (monthsData is List) {
        for (var m in monthsData) {
          try {
            if (m is Map<String, dynamic>) {
              final hYear = m['year'] is int ? m['year'] : int.tryParse(m['year']?.toString() ?? '');
              final hMonth = m['month'] is int ? m['month'] : int.tryParse(m['month']?.toString() ?? '');

              if (hYear == year && hMonth == month) {
                return HijriMonthData.fromJson(m);
              }
            }
          } catch (e) {
            debugPrint('Error checking month data: $e');
          }
        }
      }
    }

    try {
      final fallbackHijri = HijriCalendar()
        ..hYear = year
        ..hMonth = month
        ..hDay = 1;

      final gregorianStart = fallbackHijri.hijriToGregorian(year, month, 1);
      final totalDays = fallbackHijri.getDaysInMonth(year, month);

      return HijriMonthData(
        year: year,
        month: month,
        totalDays: totalDays,
        expectedGregorianStart: gregorianStart.toIso8601String().split('T').first,
        days: [],
      );
    } catch (e) {
      return HijriMonthData(
        year: year, month: month, totalDays: 30,
        expectedGregorianStart: DateTime.now().toIso8601String().split('T').first,
        days: []
      );
    }
  }

  static HijriDayData? getDayData(int year, int month, int day) {
    final monthData = getMonthData(year, month);
    if (monthData != null) {
      for (var d in monthData.days) {
        if (d.day == day) return d;
      }
    }
    return null;
  }

  static List<CalendarEvent> getEventsForDay(int year, int month, int day) {
    final dayData = getDayData(year, month, day);
    if (dayData != null) {
      return dayData.events;
    }
    return [];
  }

  static List<AstronomicalEvent> getAstronomicalEventsForDay(int year, int month, int day) {
    final dayData = getDayData(year, month, day);
    if (dayData != null) {
      return dayData.astronomicalEvents;
    }
    return [];
  }
}
