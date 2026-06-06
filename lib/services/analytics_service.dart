import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static const String _deviceTrackedKey = 'is_device_tracked';

  Future<void> checkAndRegisterDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isTracked = prefs.getBool(_deviceTrackedKey) ?? false;

      if (!isTracked) {
        // Log the new device registration event
        await FirebaseAnalytics.instance.logEvent(
          name: 'new_device_registered',
          parameters: {
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Update the local storage so it won't track again
        await prefs.setBool(_deviceTrackedKey, true);
        debugPrint('AnalyticsService: new_device_registered event logged successfully.');
      } else {
        debugPrint('AnalyticsService: Device already tracked.');
      }
    } catch (e) {
      // Log the error but do not disrupt the application flow
      debugPrint('AnalyticsService: Failed to check or register device: $e');
    }
  }
}
