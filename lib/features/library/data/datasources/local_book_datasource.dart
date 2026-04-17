import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';
import 'package:epub_translate_meaning/core/storage/database_helper.dart';
import 'package:epub_translate_meaning/core/storage/in_memory_book_store.dart';
import 'package:epub_translate_meaning/features/library/data/models/book_model.dart';
import 'package:epub_translate_meaning/features/reader/data/models/bookmark_model.dart';
import 'package:epub_translate_meaning/features/reader/data/models/note_model.dart';
import 'package:epub_translate_meaning/features/reader/data/models/reading_progress_model.dart';

abstract class LocalBookDataSource {
  Future<List<BookModel>> getBooks();
  Future<void> saveBook(BookModel book, {Uint8List? epubBytes});
  Future<void> removeBook(String id);
  Uint8List? getEpubBytes(String bookId);

  Future<List<BookmarkModel>> getBookmarks(String bookId);
  Future<void> saveBookmark(BookmarkModel bookmark);
  Future<void> removeBookmark(int id);

  Future<List<NoteModel>> getNotes(String bookId);
  Future<void> saveNote(NoteModel note);
  Future<void> removeNote(int id);

  Future<ReadingProgressModel?> getReadingProgress(String bookId);
  Future<void> saveReadingProgress(ReadingProgressModel progress);
}

@LazySingleton(as: LocalBookDataSource)
class LocalBookDataSourceImpl implements LocalBookDataSource {
  final DatabaseHelper dbHelper;
  final InMemoryBookStore memoryStore;

  LocalBookDataSourceImpl(this.dbHelper, this.memoryStore);

  @override
  Future<List<BookModel>> getBooks() async {
    if (kIsWeb) {
      return memoryStore.getBooks();
    }
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        orderBy: 'added_at DESC',
      );
      return List.generate(maps.length, (i) {
        return BookModel(
          id: maps[i]['id'],
          title: maps[i]['title'],
          author: maps[i]['author'],
          filePath: maps[i]['file_path'],
          addedAt: DateTime.fromMillisecondsSinceEpoch(maps[i]['added_at']),
          lastReadAt: maps[i]['last_read_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(maps[i]['last_read_at'])
              : null,
          status: maps[i]['status'] as String? ?? 'reading',
          isFavorite: (maps[i]['is_favorite'] as int?) == 1,
        );
      });
    } catch (e) {
      return memoryStore.getBooks();
    }
  }

  @override
  Future<void> saveBook(BookModel book, {Uint8List? epubBytes}) async {
    memoryStore.saveBook(book);
    if (epubBytes != null) {
      memoryStore.saveBytes(book.id, epubBytes);
    }
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      await db.insert('books', {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'file_path': book.filePath,
        'added_at': book.addedAt.millisecondsSinceEpoch,
        'last_read_at': book.lastReadAt?.millisecondsSinceEpoch,
        'status': book.status,
        'is_favorite': book.isFavorite ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  @override
  Future<void> removeBook(String id) async {
    memoryStore.removeBook(id);
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      await db.delete('books', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  @override
  Uint8List? getEpubBytes(String bookId) => memoryStore.getBytes(bookId);

  @override
  Future<List<BookmarkModel>> getBookmarks(String bookId) async {
    if (kIsWeb) return [];
    try {
      final db = await dbHelper.database;
      final maps = await db.query('bookmarks', where: 'book_id = ?', whereArgs: [bookId], orderBy: 'created_at DESC');
      return maps.map((m) => BookmarkModel.fromMap(m)).toList();
    } catch (_) { return []; }
  }

  @override
  Future<void> saveBookmark(BookmarkModel bookmark) async {
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      await db.insert('bookmarks', bookmark.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  @override
  Future<void> removeBookmark(int id) async {
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  @override
  Future<List<NoteModel>> getNotes(String bookId) async {
    if (kIsWeb) return [];
    try {
      final db = await dbHelper.database;
      final maps = await db.query('notes', where: 'book_id = ?', whereArgs: [bookId], orderBy: 'created_at DESC');
      return maps.map((m) => NoteModel.fromMap(m)).toList();
    } catch (_) { return []; }
  }

  @override
  Future<void> saveNote(NoteModel note) async {
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      await db.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  @override
  Future<void> removeNote(int id) async {
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  @override
  Future<ReadingProgressModel?> getReadingProgress(String bookId) async {
    if (kIsWeb) return null;
    try {
      final db = await dbHelper.database;
      final maps = await db.query('reading_progress', where: 'book_id = ?', whereArgs: [bookId], limit: 1);
      if (maps.isNotEmpty) return ReadingProgressModel.fromMap(maps.first);
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveReadingProgress(ReadingProgressModel progress) async {
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      final existing = await db.query('reading_progress', where: 'book_id = ?', whereArgs: [progress.bookId]);
      if (existing.isNotEmpty) {
        await db.update('reading_progress', progress.toMap(), where: 'book_id = ?', whereArgs: [progress.bookId]);
      } else {
        await db.insert('reading_progress', progress.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
  }
}
