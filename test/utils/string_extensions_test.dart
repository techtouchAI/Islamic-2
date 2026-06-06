import 'package:flutter_test/flutter_test.dart';
import 'package:aldhakereen/utils/string_extensions.dart';

void main() {
  group('ArabicStringNormalization Extension', () {
    test('should remove diacritics (Harakat)', () {
      expect('بِسْمِ اللهِ'.normalizeArabic(), 'بسم الله');
      expect('الْحَمْدُ لِلَّهِ'.normalizeArabic(), 'الحمد لله');
    });

    test('should normalize Alef variations to bare Alef', () {
      expect('أحمد'.normalizeArabic(), 'احمد');
      expect('إسلام'.normalizeArabic(), 'اسلام');
      expect('قرآن'.normalizeArabic(), 'قران');
    });

    test('should normalize Teh Marbuta to Heh', () {
      expect('فاطمة'.normalizeArabic(), 'فاطمه');
      expect('صلاة'.normalizeArabic(), 'صلاه');
    });

    test('should normalize Alef Maksura to Yeh', () {
      expect('موسى'.normalizeArabic(), 'موسي');
      expect('على'.normalizeArabic(), 'علي');
    });

    test('should handle mixed normalization cases', () {
      expect(
        'أَلْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ'.normalizeArabic(),
        'الحمد لله رب العالمين',
      );
      expect(
        'آتِنَا فِي الدُّنْيَا حَسَنَةً'.normalizeArabic(),
        'اتنا في الدنيا حسنه',
      );
    });

    test('should handle empty strings', () {
      expect(''.normalizeArabic(), '');
    });

    test('should handle non-Arabic text without changes', () {
      expect('Hello 123!'.normalizeArabic(), 'Hello 123!');
    });

    test('should handle strings with no normalization needed', () {
      expect('محمد رسول الله'.normalizeArabic(), 'محمد رسول الله');
    });
  });
}
