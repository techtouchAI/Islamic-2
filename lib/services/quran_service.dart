import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/data_manager.dart';

class QuranService {
  static Database? _db;
  static final Map<int, List<Map<String, dynamic>>> _ayahsCache = {};
  static final Map<int, String> _formattedContentCache = {};

  static Future<void> initDB() async {
    if (kIsWeb) return;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, "quran_db.db");

      // Ensure directory exists
      await Directory(dirname(path)).create(recursive: true);

      if (!await File(path).exists()) {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load("assets/data/quran_db.db");
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes);
        rootBundle.evict("assets/data/quran_db.db");
      }
      _db = await openDatabase(path, readOnly: true);
    } catch (e) {
      debugPrint("QuranService Init Error: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getSurahs() async {
    try {
      if (kIsWeb || _db == null) {
        // Use DataManager as fallback (CMS support)
        final items = DataManager.getItems('quran');
        if (items.isNotEmpty) {
          return items
              .map(
                (e) => {
                  'id': e['id'],
                  'name': e['title'].toString().replaceFirst('سورة ', ''),
                  'total_ayahs': 'غير محدد',
                },
              )
              .toList();
        }
        return [
          {'id': 2, 'name': 'الفاتحة', 'total_ayahs': 7},
          {'id': 3, 'name': 'البقرة', 'total_ayahs': 286},
        ];
      }
      return await _db!.query('surah', orderBy: 'id ASC');
    } catch (e) {
      debugPrint("QuranService getSurahs Error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAyahs(int surahId) async {
    try {
      if (_ayahsCache.containsKey(surahId)) {
        return _ayahsCache[surahId]!;
      }

      if (kIsWeb || _db == null) {
        final items = DataManager.getItems('quran');
        final found = items.firstWhere(
          (e) => e['id'] == surahId,
          orElse: () => null,
        );
        if (found != null) {
          final result = [
            {'ar_text': found['content'].toString(), 'ayah_surah_index': ''},
          ];
          _ayahsCache[surahId] = result;
          return result;
        }
        return [];
      }
      // Using 'text' column for full Tashkeel
      final result = await _db!.query(
        'ayah',
        where: 'sid = ?',
        columns: ['text as ar_text', 'anum', 'ayah_surah_index'],
        whereArgs: [surahId],
        orderBy: 'anum ASC',
      );
      _ayahsCache[surahId] = result;
      return result;
    } catch (e) {
      debugPrint("QuranService getAyahs Error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVersesByPage(
    int pageNumber,
  ) async {
    if (_db == null) return [];
    try {
      final result = await _db!.rawQuery(
        '''
        SELECT a.ar_text, a.anum, s.name AS surah_name
        FROM ayah a
        INNER JOIN surah s ON a.sid = s.id
        WHERE a.ayah_page_number = ?
        ORDER BY a.id ASC
      ''',
        [pageNumber],
      );
      return result;
    } catch (e) {
      debugPrint("QuranService getVersesByPage Error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllVerses() async {
    if (_db == null) return [];

    try {
      final List<Map<String, dynamic>> result = await _db!.rawQuery('''
        SELECT a.anum, a.text, a.sid, s.name as surah_name
        FROM ayah a
        JOIN surah s ON a.sid = s.id
      ''');

      return result
          .map(
            (row) => {
              'ayah_text': row['text']?.toString() ?? '',
              'surah_name': row['surah_name']?.toString() ?? '',
              'ayah_number': row['anum'],
              'surah_number': row['sid'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint("QuranService getAllVerses Error: \$e");
      return [];
    }
  }

  static String getFormattedContent(
    int surahId,
    List<Map<String, dynamic>> ayahs,
  ) {
    if (_formattedContentCache.containsKey(surahId)) {
      return _formattedContentCache[surahId]!;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < ayahs.length; i++) {
      final a = ayahs[i];
      final text = a['ar_text'].toString().trim();
      final index = a['anum']?.toString() ?? a['ayah_surah_index'].toString();
      if (index.isEmpty) {
        buffer.write(text);
      } else {
        buffer.write(text);
        buffer.write(" \uFD3F");
        buffer.write(index);
        buffer.write("\uFD3E");
      }
      if (i < ayahs.length - 1) {
        buffer.write(" ");
      }
    }

    final content = buffer.toString();
    _formattedContentCache[surahId] = content;
    return content;
  }
}
