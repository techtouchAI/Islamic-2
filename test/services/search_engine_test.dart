import 'package:flutter_test/flutter_test.dart';
import 'package:aldhakereen/services/search_engine.dart';

void main() {
  group('SearchEngine Core Logic Tests', () {
    test('testNormalizeArabic normalizes properly', () {
      final input = "سُورَةٌ";
      final output = SearchEngine.normalizeArabic(input);
      expect(output, "سوره");
    });

    test('testTypoTolerance distance calc', () {
      final dist = SearchEngine.levenshteinDistance("دعاء الرزق", "دعا الرزق");
      expect(dist, 1);
      final dist2 = SearchEngine.levenshteinDistance("دعا", "دعاء");
      expect(dist2, 1);
    });

    test('testFuzzyThreshold logic', () {
      expect(SearchEngine.fuzzyMatch("كتاب", "كتااب", isFuzzy: true), isTrue);
      expect(SearchEngine.fuzzyMatch("كتاب", "كتب", isFuzzy: true), isTrue);
      expect(SearchEngine.fuzzyMatch("كتاب", "ك", isFuzzy: true), isFalse);
    });

    test('testMultiKeywordAND', () {
      final engine = SearchEngine.instance;
      engine.setMockIndex([
        SearchDocument(
          id: '1',
          title: 'صلاة الفجر',
          content: 'وقت صلاة الفجر',
          category: 'cat1',
          tags: [],
          type: 'content',
          normalizedTitle: SearchEngine.normalizeArabic('صلاة الفجر'),
          normalizedContent: SearchEngine.normalizeArabic('وقت صلاة الفجر'),
          normalizedCategory: 'cat1',
          normalizedTags: [],
        ),
        SearchDocument(
          id: '2',
          title: 'صلاة الظهر',
          content: 'وقت الصلاة',
          category: 'cat1',
          tags: [],
          type: 'content',
          normalizedTitle: SearchEngine.normalizeArabic('صلاة الظهر'),
          normalizedContent: SearchEngine.normalizeArabic('وقت الصلاة'),
          normalizedCategory: 'cat1',
          normalizedTags: [],
        ),
        SearchDocument(
          id: '3',
          title: 'الفجر',
          content: 'الفجر في المسجد',
          category: 'cat1',
          tags: [],
          type: 'content',
          normalizedTitle: SearchEngine.normalizeArabic('الفجر'),
          normalizedContent: SearchEngine.normalizeArabic('الفجر في المسجد'),
          normalizedCategory: 'cat1',
          normalizedTags: [],
        )
      ]);

      // Search for "صلاة فجر"
      final results = engine.search("صلاة فجر");

      // Should only match doc 1 which contains both 'صلاه' and 'فجر'
      expect(results.length, 1);
      expect(results.first.document.id, '1');
    });

    test('testScoringPriority', () {
      final engine = SearchEngine.instance;
      engine.setMockIndex([
        SearchDocument(
          id: '1',
          title: 'كلمة', // Title match (+10)
          content: 'نص عادي',
          category: 'cat1',
          tags: [],
          type: 'content',
          normalizedTitle: SearchEngine.normalizeArabic('كلمة'),
          normalizedContent: SearchEngine.normalizeArabic('نص عادي'),
          normalizedCategory: 'cat1',
          normalizedTags: [],
        ),
        SearchDocument(
          id: '2',
          title: 'عنوان آخر',
          content: 'هذه كلمة في النص', // Content match (+2)
          category: 'cat1',
          tags: [],
          type: 'content',
          normalizedTitle: SearchEngine.normalizeArabic('عنوان آخر'),
          normalizedContent: SearchEngine.normalizeArabic('هذه كلمة في النص'),
          normalizedCategory: 'cat1',
          normalizedTags: [],
        ),
      ]);

      final results = engine.search("كلمة");
      expect(results.length, 2);
      expect(results[0].document.id, '1'); // Higher score should be first
      expect(results[1].document.id, '2');
      expect(results[0].score > results[1].score, isTrue);
    });

    test('testEmptyQuery', () {
      final engine = SearchEngine.instance;
      // Index is already mock populated
      final results = engine.search("");
      expect(results.isEmpty, isTrue);

      final resultsSpaces = engine.search("   ");
      expect(resultsSpaces.isEmpty, isTrue);
    });
  });
}
