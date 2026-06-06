import 'package:flutter/material.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';

class BatteryOptimizationHelper {
  static Future<bool> checkAndRequestIgnoreBatteryOptimizations() async {
    bool? isIgnoring =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled;
    if (isIgnoring == true) {
      return true;
    }

    bool? result =
        await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
    return result == true;
  }

  static Future<void> showBatteryOptimizationDialog(
      BuildContext context) async {
    bool? isIgnoring =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled;

    if (isIgnoring == true) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('السماح بالعمل في الخلفية'),
        content: const Text(
          'لضمان عمل أذان الصلاة بدقة وتجنب إيقافه من قبل نظام توفير الطاقة، يرجى السماح للتطبيق بالعمل في الخلفية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await checkAndRequestIgnoreBatteryOptimizations();
            },
            child: const Text('الذهاب للإعدادات'),
          ),
        ],
      ),
    );
  }
}
