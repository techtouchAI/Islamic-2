import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mafatih_category.dart';
import '../models/mafatih_article.dart';
import '../main.dart'; // To access navigatorKey

class MafatihService {
  static Database? _db;

  static Future<void> initDB() async {
    if (kIsWeb) return;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, "maftiha.ar2.db");

      // Ensure directory exists
      await Directory(dirname(path)).create(recursive: true);

      if (!await File(path).exists()) {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load("assets/data/maftiha.ar2.db");
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes);
        rootBundle.evict("assets/data/maftiha.ar2.db");
      }
      _db = await openDatabase(path, readOnly: true);
    } catch (e) {
      debugPrint("MafatihService Init Error: $e");
      _showError("حدث خطأ أثناء تهيئة مفاتيح الجنان: ${e.toString()}");
    }
  }

  static void _showError(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  static Future<List<MafatihCategory>> getCategories() async {
    try {
      if (kIsWeb || _db == null) {
        return [];
      }
      final maps = await _db!.query('categories', where: 'parent_id = 0');
      return maps.map((m) => MafatihCategory.fromMap(m)).toList();
    } catch (e) {
      debugPrint("MafatihService getCategories Error: $e");
      _showError("حدث خطأ أثناء جلب الفئات: ${e.toString()}");
      return [];
    }
  }

  static Future<List<MafatihCategory>> getSubCategories(int parentId) async {
    try {
      if (kIsWeb || _db == null) {
        return [];
      }
      final maps = await _db!.query(
        'categories',
        where: 'parent_id = ?',
        whereArgs: [parentId],
      );
      return maps.map((m) => MafatihCategory.fromMap(m)).toList();
    } catch (e) {
      debugPrint("MafatihService getSubCategories Error: $e");
      _showError("حدث خطأ أثناء جلب الأقسام الفرعية: ${e.toString()}");
      return [];
    }
  }

  static Future<int> getTotalArticlesCount() async {
    try {
      if (kIsWeb || _db == null) {
        return 0;
      }
      final count = Sqflite.firstIntValue(
        await _db!.rawQuery('SELECT COUNT(*) FROM articles'),
      );
      return count ?? 0;
    } catch (e) {
      debugPrint("MafatihService getTotalArticlesCount Error: $e");
      return 0;
    }
  }

  static Future<int> getCategoryArticlesCount(int categoryId) async {
    try {
      if (kIsWeb || _db == null) {
        return 0;
      }
      final String idStr = categoryId.toString();
      final count = Sqflite.firstIntValue(await _db!.rawQuery(
        'SELECT COUNT(*) FROM articles WHERE group_id = ? OR group_id LIKE ? OR group_id LIKE ? OR group_id LIKE ?',
        [
          idStr,
          '$idStr@@%',
          '%@@$idStr',
          '%@@$idStr@@%',
        ],
      ));
      return count ?? 0;
    } catch (e) {
      debugPrint("MafatihService getCategoryArticlesCount Error: $e");
      return 0;
    }
  }

  static Future<List<MafatihArticle>> getArticles(int categoryId) async {
    try {
      if (kIsWeb || _db == null) {
        return [];
      }
      final String idStr = categoryId.toString();
      // group_id can be exact '10', start with '10@@', end with '@@10', or contain '@@10@@'
      final maps = await _db!.query(
        'articles',
        where: 'group_id = ? OR group_id LIKE ? OR group_id LIKE ? OR group_id LIKE ?',
        whereArgs: [
          idStr,
          '$idStr@@%',
          '%@@$idStr',
          '%@@$idStr@@%',
        ],
      );
      return maps.map((m) => MafatihArticle.fromMap(m)).toList();
    } catch (e) {
      debugPrint("MafatihService getArticles Error: $e");
      _showError("حدث خطأ أثناء جلب المقالات: ${e.toString()}");
      return [];
    }
  }
}
