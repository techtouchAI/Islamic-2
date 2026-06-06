import 'dart:math' as math;

/// Configuration object for prayer calculation parameters to avoid hardcoding.
class PrayerCalculationParameters {
  final double fajrAngle;
  final double maghribAngle;
  final double ishaAngle;
  final double refraction;

  const PrayerCalculationParameters({
    required this.fajrAngle,
    required this.maghribAngle,
    required this.ishaAngle,
    required this.refraction,
  });

  /// Predefined Shia Jafari calculation parameters
  static const jafari = PrayerCalculationParameters(
    fajrAngle: 16.0,
    maghribAngle: 4.0,
    ishaAngle: 14.0,
    refraction: 0.833,
  );
}

/// Abstract interface for Prayer Times Engine
abstract class PrayerTimesEngine {
  Map<String, DateTime> getTimes(
    DateTime date,
    double lat,
    double lng,
    double timeZone, {
    double elevation = 0,
  });
}


/// Implementation of PrayTimes astronomical algorithms.
/// Based on PrayTimes.org JS library (v2.5) by Hamid Zarrabi-Zadeh.
/// Adapted for clean architecture in Dart with Jafari parameters.
class PrayTimes implements PrayerTimesEngine {
  // Constants for calculation
  final double _numIterations = 4;

  // Calculation parameters
  final PrayerCalculationParameters _params;

  // Coordinate and timezone info
  late double _lat;
  late double _lng;
  late double _elv;
  late double _timeZone;
  late double _jDate;

  PrayTimes([PrayerCalculationParameters? params]) : _params = params ?? PrayerCalculationParameters.jafari;

  /// Calculate prayer times for a given date, coordinates, and timezone.
  /// returns a Map of string to DateTime
  @override
  Map<String, DateTime> getTimes(
      DateTime date, double lat, double lng, double timeZone, {double elevation = 0}) {
    _lat = lat;
    _lng = lng;
    _elv = elevation;
    _timeZone = timeZone;

    int year = date.year;
    int month = date.month;
    int day = date.day;

    _jDate = _julian(year, month, day) - lng / 360;

    Map<String, double> times = _computeTimes();

    // Convert double times to DateTimes
    Map<String, DateTime> dateTimes = {};
    times.forEach((key, value) {
      dateTimes[key] = _timeToDateTime(date, value);
    });

    return dateTimes;
  }

  //---------------------- Calculation Functions -----------------------

  // compute mid-day time
  double _midDay(double time) {
    double eqt = _sunPosition(_jDate + time).equation;
    return _DMath.fixHour(12 - eqt);
  }

  // compute the time at which sun reaches a specific angle below horizon
  double _sunAngleTime(double angle, double time, String direction) {
    double decl = _sunPosition(_jDate + time).declination;
    double noon = _midDay(time);

    double denominator = _DMath.cos(decl) * _DMath.cos(_lat);
    if (denominator == 0) denominator = 0.00001; // zero-division safeguard

    double t = 1 / 15 * _DMath.arccos(
        (-_DMath.sin(angle) - _DMath.sin(decl) * _DMath.sin(_lat)) / denominator);

    return noon + (direction == 'ccw' ? -t : t);
  }

  // compute asr time
  double _asrTime(double factor, double time) {
    double decl = _sunPosition(_jDate + time).declination;
    double angle = -_DMath.arccot(factor + _DMath.tan((_lat - decl).abs()));
    return _sunAngleTime(angle, time, 'cw');
  }

  // compute declination angle of sun and equation of time
  // Ref: http://aa.usno.navy.mil/faq/docs/SunApprox.php
  _SunPosition _sunPosition(double jd) {
    double D = jd - 2451545.0;
    double g = _DMath.fixAngle(357.529 + 0.98560028 * D);
    double q = _DMath.fixAngle(280.459 + 0.98564736 * D);
    double L = _DMath.fixAngle(q + 1.915 * _DMath.sin(g) + 0.020 * _DMath.sin(2 * g));

    // double R = 1.00014 - 0.01671 * _DMath.cos(g) - 0.00014 * _DMath.cos(2 * g);
    double e = 23.439 - 0.00000036 * D;

    double ra = _DMath.arctan2(_DMath.cos(e) * _DMath.sin(L), _DMath.cos(L)) / 15;
    double eqt = q / 15 - _DMath.fixHour(ra);
    double decl = _DMath.arcsin(_DMath.sin(e) * _DMath.sin(L));

    return _SunPosition(declination: decl, equation: eqt);
  }

  // convert Gregorian date to Julian day
  // Ref: Astronomical Algorithms by Jean Meeus
  double _julian(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    int A = (year / 100).floor();
    int B = 2 - A + (A / 4).floor();

    double jd = (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() + day + B - 1524.5;
    return jd;
  }

  //---------------------- Compute Prayer Times -----------------------

  // compute prayer times at given julian date
  Map<String, double> _computePrayerTimes(Map<String, double> times) {
    times = _dayPortion(times);

    double fajr = _sunAngleTime(_params.fajrAngle, times['fajr']!, 'ccw');
    double sunrise = _sunAngleTime(_riseSetAngle(), times['sunrise']!, 'ccw');
    double dhuhr = _midDay(times['dhuhr']!);
    double asr = _asrTime(1, times['asr']!); // Standard factor = 1
    double sunset = _sunAngleTime(_riseSetAngle(), times['sunset']!, 'cw');
    double maghrib = _sunAngleTime(_params.maghribAngle, times['maghrib']!, 'cw');
    double isha = _sunAngleTime(_params.ishaAngle, times['isha']!, 'cw');

    return {
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'sunset': sunset,
      'maghrib': maghrib,
      'isha': isha
    };
  }

  // compute prayer times
  Map<String, double> _computeTimes() {
    // default times
    Map<String, double> times = {
      'fajr': 5,
      'sunrise': 6,
      'dhuhr': 12,
      'asr': 13,
      'sunset': 18,
      'maghrib': 18,
      'isha': 18
    };

    // main iterations
    for (int i = 1; i <= _numIterations; i++) {
      times = _computePrayerTimes(times);
    }

    times = _adjustTimes(times);

    // add midnight time (Jafari method)
    // For Sayyid Sistani, Midnight is halfway between Sunset and Sunrise of the next day
    times['midnight'] = times['sunset']! + _timeDiff(times['sunset']!, times['sunrise']! + 24) / 2;

    return times;
  }

  // adjust times
  Map<String, double> _adjustTimes(Map<String, double> times) {
    Map<String, double> newTimes = {};
    times.forEach((key, value) {
      newTimes[key] = value + _timeZone - _lng / 15;
    });

    newTimes = _adjustHighLats(newTimes);

    return newTimes;
  }

  // adjust times for locations in higher latitudes
  Map<String, double> _adjustHighLats(Map<String, double> times) {
    double nightTime = _timeDiff(times['sunset']!, times['sunrise']!);

    times['imsak'] = _adjustHLTime(times['imsak'] ?? times['fajr']!, times['sunrise']!, _params.fajrAngle, nightTime, 'ccw'); // fallback for imsak since it might not be in the map in this port
    times['fajr'] = _adjustHLTime(times['fajr']!, times['sunrise']!, _params.fajrAngle, nightTime, 'ccw');
    times['isha'] = _adjustHLTime(times['isha']!, times['sunset']!, _params.ishaAngle, nightTime, 'cw');
    times['maghrib'] = _adjustHLTime(times['maghrib']!, times['sunset']!, _params.maghribAngle, nightTime, 'cw');

    return times;
  }

  // adjust a time for higher latitudes
  double _adjustHLTime(double time, double base, double angle, double night, String direction) {
    double portion = _nightPortion(angle, night);
    double timeDiff = (direction == 'ccw') ? _timeDiff(time, base) : _timeDiff(base, time);

    if (time.isNaN || timeDiff > portion) {
      time = base + (direction == 'ccw' ? -portion : portion);
    }
    return time;
  }

  // the night portion used for adjusting times in higher latitudes
  double _nightPortion(double angle, double night) {
    // NightMiddle method is default for Jafari
    double portion = 1.0 / 2.0;
    return portion * night;
  }

  // return sun angle for sunset/sunrise
  double _riseSetAngle() {
    double angle = 0.0347 * math.sqrt(_elv); // an approximation
    return _params.refraction + angle;
  }

  // convert hours to day portions
  Map<String, double> _dayPortion(Map<String, double> times) {
    Map<String, double> newTimes = {};
    times.forEach((key, value) {
      newTimes[key] = value / 24;
    });
    return newTimes;
  }

  //---------------------- Misc Functions -----------------------

  // compute the difference between two times
  double _timeDiff(double time1, double time2) {
    return _DMath.fixHour(time2 - time1);
  }

  // Convert double hours to DateTime
  DateTime _timeToDateTime(DateTime date, double time) {
    if (time.isNaN) {
      return date; // or handle invalid time
    }

    // The time could be > 24 if it's the next day (e.g. midnight or tomorrow fajr calculation)
    double timeInHours = _DMath.fixHour(time);

    int hours = timeInHours.floor();
    int minutes = ((timeInHours - hours) * 60 + 0.5).floor();

    // Add days if time crossed past midnight
    int daysToAdd = (time / 24).floor();

    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: daysToAdd, hours: hours, minutes: minutes)).subtract(Duration(minutes: (_timeZone * 60).round())); // convert back to UTC
  }
}

class _SunPosition {
  final double declination;
  final double equation;

  _SunPosition({required this.declination, required this.equation});
}

//---------------------- Degree-Based Math Class -----------------------
class _DMath {
  static double dtr(double d) => (d * math.pi) / 180.0;
  static double rtd(double r) => (r * 180.0) / math.pi;

  static double sin(double d) => math.sin(dtr(d));
  static double cos(double d) => math.cos(dtr(d));
  static double tan(double d) => math.tan(dtr(d));

  static double arcsin(double d) => rtd(math.asin(d.clamp(-1.0, 1.0)));
  static double arccos(double d) => rtd(math.acos(d.clamp(-1.0, 1.0)));

  static double arccot(double x) => rtd(math.atan(1 / x));
  static double arctan2(double y, double x) => rtd(math.atan2(y, x));

  static double fixAngle(double a) => fix(a, 360);
  static double fixHour(double a) => fix(a, 24);

  static double fix(double a, double b) {
    if (a.isNaN) return a;
    double aFix = a - b * (a / b).floor();
    return (aFix < 0) ? aFix + b : aFix;
  }
}
