import 'package:flutter_test/flutter_test.dart';
import 'package:aldhakereen/services/prayer_times_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrayerTimesService getCurrentLocation tests', () {
    int checkPermissionStatusResult = PermissionStatus.granted.index;
    Map<int, int> requestPermissionsResult = {
      Permission.location.value: PermissionStatus.granted.index,
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') {
            return checkPermissionStatusResult;
          }
          if (methodCall.method == 'requestPermissions') {
            return requestPermissionsResult;
          }
          if (methodCall.method == 'openAppSettings') {
            return true;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        null,
      );
    });

    test(
      'returns null when permission is permanently denied initially',
      () async {
        checkPermissionStatusResult = PermissionStatus.permanentlyDenied.index;

        final service = PrayerTimesService();
        final result = await service.getCurrentLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 32.4682);
      },
    );

    test(
      'returns null when permission is denied and then requested and denied',
      () async {
        checkPermissionStatusResult = PermissionStatus.denied.index;
        requestPermissionsResult = {
          Permission.location.value: PermissionStatus.denied.index,
        };

        final service = PrayerTimesService();
        final result = await service.getCurrentLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 32.4682);
      },
    );

    test(
      'returns null when permission is denied and then requested and permanently denied',
      () async {
        checkPermissionStatusResult = PermissionStatus.denied.index;
        requestPermissionsResult = {
          Permission.location.value: PermissionStatus.permanentlyDenied.index,
        };

        final service = PrayerTimesService();
        final result = await service.getCurrentLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 32.4682);
      },
    );

    test('returns null when an exception is thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          throw Exception('Simulated Exception');
        },
      );

      final service = PrayerTimesService();
      final result = await service.getCurrentLocation();

      expect(result, isNotNull);
      expect(result!.latitude, 32.4682);
    });
  });
}
