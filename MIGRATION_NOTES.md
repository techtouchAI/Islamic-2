# Azan System Migration Notes

## Deduplication & Unification
* `prayer_notification_service.dart` has been completely **deleted** to prevent scheduling overlaps and "dueling services."
* `PrayerTimesService` (in `prayer_times_service.dart`) is now the **sole Singleton source of truth** for all calculating and scheduling logic.
* The `adhan_dart` package was completely removed in favor of a custom native Dart `PrayTimes` implementation to accurately support Jafari criteria.

## Background Scheduling (Workmanager)
* `flutter_local_notifications` 7-day limits are overcome using `workmanager`.
* A background task `com.aldhakereen.azan` is registered in `main.dart` with a 24-hour frequency.
* The background worker cancels all existing alarms (`_notificationsPlugin.cancelAll()`) before scheduling the new ones, ensuring no duplicates.
* A 1-hour backoff retry policy is implemented if background scheduling fails.

## Dynamic Location & Fallbacks
* Instead of silently failing, if `Geolocator` hits its 10-second timeout, the service attempts to fall back to coordinates cached in `SharedPreferences` (`cached_lat` & `cached_lon`).
* If no cached coordinates are available, it uses the fallback coordinates for Hillah (`32.4682`, `44.4361`).

## Battery Optimization & Resilience
* `disable_battery_optimization` plugin added.
* `BatteryOptimizationHelper` created to check and request exemptions.
* `AndroidManifest.xml` modified to include `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` and `SYSTEM_ALERT_WINDOW`.

## Audio Assets
* Explicit confirmation: Base64 audio decoding is NOT used. Native OS alarm intent using `adhan.mp3` from `android/app/src/main/res/raw/adhan.mp3` is utilized via the `"azan_channel_v3"` high priority channel.
