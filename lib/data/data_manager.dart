import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../utils/string_extensions.dart';

class DataManager {
  static Map<String, dynamic>? _db;
  static final ValueNotifier<int> dbNotifier = ValueNotifier(0);
  static const String _repoUrl =
      "https://raw.githubusercontent.com/techtouchAI/Islamic/main/assets/data/content.json";

  // Allows dependency injection for testing
  static http.Client? httpClient;
  static Future<File> Function()? getLocalFileOverride;

  static Map<String, dynamic>? getDB() => _db;

  @visibleForTesting
  static void setDB(Map<String, dynamic>? newDb) {
    _db = newDb;
    _normalizeDB(_db);
  }

  static Map<String, dynamic> _decodeAndNormalizeJson(String source) {
    final db = json.decode(source) as Map<String, dynamic>;
    _normalizeDBLocal(db);
    return db;
  }

  static void _normalizeDBLocal(Map<String, dynamic>? db) {
    if (db == null) return;

    void normalizeItem(Map item) {
      if (item.containsKey('name') && !item.containsKey('title')) {
        item['title'] = item['name'];
        item['content'] = item['name'];
      }
      if (item['title'] != null) {
        item['_normalized_title'] = item['title'].toString().normalizeArabic();
      }
      if (item['content'] != null) {
        item['_normalized_content'] = item['content']
            .toString()
            .normalizeArabic();
      }
      if (item.containsKey('items') && item['items'] is List) {
        for (var nestedItem in item['items']) {
          if (nestedItem is Map) {
            normalizeItem(nestedItem);
          }
        }
      }
    }

    final content = db['content'];
    if (content is Map) {
      for (var section in content.values) {
        if (section is List) {
          for (var item in section) {
            if (item is Map) normalizeItem(item);
          }
        }
      }
    }

    final topLevelSections = [
      'fatawa_categories',
      'dreams_categories',
      'prophets_stories',
      'imam_ali',
    ];
    for (var sectionName in topLevelSections) {
      final sectionList = db[sectionName];
      if (sectionList is List) {
        for (var item in sectionList) {
          if (item is Map) normalizeItem(item);
        }
      }
    }
  }

  static Future<void> loadContent() async {
    try {
      final localFile = await _getLocalFile();

      // 1. Try to load from local storage first
      if (await localFile.exists()) {
        final content = await localFile.readAsString(encoding: utf8);
        _db = await compute(_decodeAndNormalizeJson, content);
        debugPrint("DataManager: Loaded from local storage.");
      } else {
        // 2. Fallback to bundled assets
        final String response = await rootBundle.loadString(
          'assets/data/content.json',
        );
        _db = await compute(_decodeAndNormalizeJson, response);
        rootBundle.evict('assets/data/content.json');
        debugPrint("DataManager: Loaded from bundled assets.");
      }
    } catch (e) {
      debugPrint("DataManager Error: $e");
      _db = {
        'content': {},
        'sections': {},
        'fatawa_categories': [],
        'dreams_categories': [],
      };
    }
  }

  static Future<bool> syncCloudData({http.Client? client}) async {
    try {
      client = client ?? httpClient ?? http.Client();
      // Add random component to fully bypass strict CDN caches
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString() + '_' + DateTime.now().microsecondsSinceEpoch.toString();
      final url = Uri.parse("$_repoUrl?t=$timestamp");

      final response = await client.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);

        // التحقق من وجود تغييرات فعلية
        final localFile = await _getLocalFile();
        if (await localFile.exists()) {
          final oldContent = await localFile.readAsString(encoding: utf8);
          if (oldContent == content) return false;
        }

        try {
          final newDb = await compute(_decodeAndNormalizeJson, content);
          // ⚠️ تم حذف الشرط الخبيث الذي يبحث عن 'sections' ليقبل أي JSON صالح
          if (newDb is Map) {
            await localFile.writeAsString(content, encoding: utf8);
            _db = Map<String, dynamic>.from(newDb);
            dbNotifier.value++;
            debugPrint("DataManager: Cloud sync successful.");
            return true;
          } else {
             debugPrint("DataManager Sync Error: Root JSON is not a valid Map");
          }
        } catch (parseError) {
          debugPrint("CRITICAL JSON ERROR: Invalid JSON Syntax in the remote file. $parseError");
          assert(false, "CRITICAL JSON ERROR: Failed to parse remote content.json. $parseError");
        }
      } else {
        debugPrint("DataManager Sync Error: HTTP Status ${response.statusCode}");
      }
} catch (e) {
      debugPrint("DataManager Sync Error (Network/Timeout): $e");
    }
    return false;
  }

  static Future<File> _getLocalFile() async {
    if (getLocalFileOverride != null) {
      return await getLocalFileOverride!();
    }
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/content.json');
  }

  static List<dynamic> getItems(String section) {
    if (_db == null) return [];
    if (section == 'adhkar') {
      List all = [];
      all.addAll(_db!['content']['adhkar_munajat'] ?? []);
      all.addAll(_db!['content']['adhkar_tasbihs'] ?? []);
      return all;
    }
    if (section == 'duas') {
      List all = [];
      all.addAll(_db!['content']['duas_days'] ?? []);
      all.addAll(_db!['content']['duas_taqeebat'] ?? []);
      all.addAll(_db!['content']['duas_general'] ?? []);
      all.addAll(_db!['content']['duas_salawat'] ?? []);
      return all;
    }
    if (section == 'visits') {
      List all = [];
      all.addAll(_db!['content']['visits_days'] ?? []);
      all.addAll(_db!['content']['visits_general'] ?? []);
      return all;
    }
    if (section == 'imam_ali') {
      return _db!['content']['imam_ali'] ?? [];
    }
    if (section.startsWith('fatawa_cat_')) {
      try {
        final idString = section.replaceAll('fatawa_cat_', '');
        final cats = _db!['fatawa_categories'] as List<dynamic>? ?? [];
        final cat = cats.firstWhere(
          (c) => c['id'].toString() == idString,
          orElse: () => null,
        );
        if (cat != null) {
          if (cat is Map) {
            if (cat.containsKey('items'))
              return cat['items'] as List<dynamic>? ?? [];
            return cat['items'] ?? [];
          }
        }
      } catch (e) {
        debugPrint('Error getting fatawa categories: $e');
      }
      return [];
    }

    if (section.startsWith('dreams_cat_')) {
      try {
        final idString = section.replaceAll('dreams_cat_', '');
        final cats = _db!['dreams_categories'] as List<dynamic>? ?? [];
        final cat = cats.firstWhere(
          (c) => c['id'].toString() == idString,
          orElse: () => null,
        );
        if (cat != null) {
          if (cat is Map) {
            if (cat.containsKey('items'))
              return cat['items'] as List<dynamic>? ?? [];
            return cat['items'] ?? [];
          }
          return _db!['content']['dreams_cat_$idString'] as List<dynamic>? ??
              [];
        }
      } catch (e) {
        debugPrint('Error getting dreams categories: $e');
      }
      return [];
    }

    if (section.startsWith('imam_ali_cat_')) {
      try {
        final idString = section.replaceAll('imam_ali_cat_', '');
        final cats = _db!['content']['imam_ali'] as List<dynamic>? ?? [];
        final cat = cats.firstWhere(
          (c) => c['id'].toString() == idString,
          orElse: () => null,
        );
        if (cat != null) {
          if (cat is Map) {
            if (cat.containsKey('items'))
              return cat['items'] as List<dynamic>? ?? [];
            return cat['items'] ?? [];
          }
          return _db!['content']['imam_ali_cat_$idString'] as List<dynamic>? ??
              [];
        }
      } catch (e) {
        debugPrint('Error getting imam ali categories: $e');
      }
      return [];
    }
    if (section == 'fatawa') {
      return _db!['fatawa_categories'] ?? [];
    }
    if (section == 'dreams') {
      return _db!['dreams_categories'] ?? [];
    }
    if (section == 'prophets_stories') {
      return _db!['prophets_stories'] as List<dynamic>? ?? [];
    }
    return _db!['content'][section] as List<dynamic>? ?? [];
  }

  static Map<String, dynamic> getAbout() {
    return (_db?['about'] as Map<String, dynamic>?) ?? {};
  }

  static Map<String, dynamic> getSettings() {
    return (_db?['settings'] as Map<String, dynamic>?) ?? {};
  }

  static Map<String, dynamic> getSections() {
    return (_db?['sections'] as Map<String, dynamic>?) ?? {};
  }

  static String getIstikharaDua() {
    return getSettings()['istikhara_dua'] as String? ??
        "«اللَّهُمَّ إِنِّي تَفَأَّلْتُ بِكِتَابِكَ، وَتَوَكَّلْتُ عَلَيْكَ، فَأَرِنِي مِنْ كِتَابِكَ مَا هُوَ مَكْتُومٌ مِنْ سِرِّكَ الْمَكْنُونِ فِي غَيْبِكَ»";
  }

  static String getMainScreenDua() {
    return getSettings()['main_screen_dua'] as String? ??
        "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ";
  }

  static List<dynamic> getDailyDuas() {
    return _db?['content']?['daily_duas'] as List<dynamic>? ?? [];
  }

  static void _normalizeDB(Map<String, dynamic>? db) {
    if (db == null) return;

    void normalizeItem(Map item) {
      if (item.containsKey('name') && !item.containsKey('title')) {
        item['title'] = item['name'];
        item['content'] = item['name'];
      }
      if (item['title'] != null) {
        item['_normalized_title'] = item['title'].toString().normalizeArabic();
      }
      if (item['content'] != null) {
        item['_normalized_content'] = item['content']
            .toString()
            .normalizeArabic();
      }
      if (item.containsKey('items') && item['items'] is List) {
        for (var nestedItem in item['items']) {
          if (nestedItem is Map) {
            normalizeItem(nestedItem);
          }
        }
      }
    }

    final content = db['content'];
    if (content is Map) {
      for (var section in content.values) {
        if (section is List) {
          for (var item in section) {
            if (item is Map) normalizeItem(item);
          }
        }
      }
    }

    final topLevelSections = [
      'fatawa_categories',
      'dreams_categories',
      'prophets_stories',
      'imam_ali',
    ];
    for (var sectionName in topLevelSections) {
      final sectionList = db[sectionName];
      if (sectionList is List) {
        for (var item in sectionList) {
          if (item is Map) normalizeItem(item);
        }
      }
    }
  }
}
