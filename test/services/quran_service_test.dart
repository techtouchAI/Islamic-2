import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aldhakereen/services/quran_service.dart';
import 'package:aldhakereen/data/data_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // We will setup the environment and clear DataManager states before each test.
  setUp(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });
  });

  tearDown(() {
    final file = File('./content.json');
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  group('QuranService Fallback Logic', () {
    test('getSurahs Empty Fallback returns hardcoded surahs', () async {
      // Setup DataManager with empty content
      File('./content.json').writeAsStringSync(jsonEncode({'content': {}}));
      await DataManager.loadContent();

      final surahs = await QuranService.getSurahs();

      expect(surahs.length, 2);
      expect(surahs[0]['id'], 2);
      expect(surahs[0]['name'], 'الفاتحة');
      expect(surahs[0]['total_ayahs'], 7);

      expect(surahs[1]['id'], 3);
      expect(surahs[1]['name'], 'البقرة');
      expect(surahs[1]['total_ayahs'], 286);
    });

    test('getSurahs CMS Fallback returns formatted surahs', () async {
      // Setup DataManager with mock quran items
      File('./content.json').writeAsStringSync(
        jsonEncode({
          'content': {
            'quran': [
              {'id': 112, 'title': 'سورة الإخلاص', 'content': 'قل هو الله أحد'},
              {
                'id': 113,
                'title': 'سورة الفلق',
                'content': 'قل أعوذ برب الفلق',
              },
            ],
          },
        }),
      );
      await DataManager.loadContent();

      final surahs = await QuranService.getSurahs();

      expect(surahs.length, 2);
      expect(surahs[0]['id'], 112);
      expect(surahs[0]['name'], 'الإخلاص'); // 'سورة ' is replaced
      expect(surahs[0]['total_ayahs'], 'غير محدد');

      expect(surahs[1]['id'], 113);
      expect(surahs[1]['name'], 'الفلق'); // 'سورة ' is replaced
      expect(surahs[1]['total_ayahs'], 'غير محدد');
    });

    test('getAyahs CMS Fallback returns properly formatted ayahs', () async {
      File('./content.json').writeAsStringSync(
        jsonEncode({
          'content': {
            'quran': [
              {'id': 112, 'title': 'سورة الإخلاص', 'content': 'قل هو الله أحد'},
            ],
          },
        }),
      );
      await DataManager.loadContent();

      final ayahs = await QuranService.getAyahs(112);

      expect(ayahs.length, 1);
      expect(ayahs[0]['ar_text'], 'قل هو الله أحد');
      expect(ayahs[0]['ayah_surah_index'], '');
    });

    test('getAyahs Empty Fallback returns empty list', () async {
      File('./content.json').writeAsStringSync(
        jsonEncode({
          'content': {
            'quran': [
              {'id': 112, 'title': 'سورة الإخلاص', 'content': 'قل هو الله أحد'},
            ],
          },
        }),
      );
      await DataManager.loadContent();

      final ayahs = await QuranService.getAyahs(999);

      expect(ayahs.isEmpty, true);
    });
  });
}
