import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';
import 'package:epub_translate_meaning/core/storage/database_helper.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';

abstract class TranslationCacheDataSource {
  Future<Translation?> getCachedTranslation(
    String bookId,
    String hash,
    String langPair,
  );
  Future<void> cacheTranslation(
    String bookId,
    String hash,
    String langPair,
    Translation translation,
    String provider,
  );
  Future<List<Map<String, dynamic>>> getTranslationsForBook(String bookId);
}

@LazySingleton(as: TranslationCacheDataSource)
class TranslationCacheDataSourceImpl implements TranslationCacheDataSource {
  final DatabaseHelper dbHelper;
  static final Map<String, List<Map<String, dynamic>>> _webCache = {};

  TranslationCacheDataSourceImpl(this.dbHelper);

  @override
  Future<List<Map<String, dynamic>>> getTranslationsForBook(
    String bookId,
  ) async {
    if (kIsWeb) {
      return _webCache[bookId] ?? [];
    }
    try {
      final db = await dbHelper.database;
      return await db.query(
        'translations',
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Translation?> getCachedTranslation(
    String bookId,
    String hash,
    String langPair,
  ) async {
    if (kIsWeb) {
      final list = _webCache[bookId] ?? [];
      for (var item in list) {
        if (item['paragraph_hash'] == hash &&
            item['language_pair'] == langPair) {
          return Translation(
            original: item['original_text'],
            translation: item['translated_text'],
          );
        }
      }
      return null;
    }
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'translations',
        where: 'book_id = ? AND paragraph_hash = ? AND language_pair = ?',
        whereArgs: [bookId, hash, langPair],
      );

      if (maps.isNotEmpty) {
        return Translation(
          original: maps[0]['original_text'],
          translation: maps[0]['translated_text'],
        );
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  @override
  Future<void> cacheTranslation(
    String bookId,
    String hash,
    String langPair,
    Translation translation,
    String provider,
  ) async {
    if (kIsWeb) {
      final list = _webCache[bookId] ??= [];
      list.add({
        'book_id': bookId,
        'paragraph_hash': hash,
        'original_text': translation.original,
        'translated_text': translation.translation,
        'language_pair': langPair,
        'provider': provider,
      });
      return;
    }
    try {
      final db = await dbHelper.database;
      await db.insert('translations', {
        'book_id': bookId,
        'paragraph_hash': hash,
        'original_text': translation.original,
        'translated_text': translation.translation,
        'language_pair': langPair,
        'provider': provider,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      // Ignore
    }
  }
}
