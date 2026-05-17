import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/models/parsed_book.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'pdf_reader_v2.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Books table
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        filePath TEXT NOT NULL,
        coverPath TEXT,
        format TEXT DEFAULT 'pdf',
        language TEXT DEFAULT 'en',
        totalChapters INTEGER DEFAULT 0,
        currentChapterIndex INTEGER DEFAULT 0,
        currentParagraphIndex INTEGER DEFAULT 0,
        readingProgress REAL DEFAULT 0,
        isRTL INTEGER DEFAULT 0,
        addedAt TEXT,
        lastReadAt TEXT
      )
    ''');

    // 2. Chapters table
    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        chapterIndex INTEGER NOT NULL,
        title TEXT,
        totalParagraphs INTEGER DEFAULT 0,
        FOREIGN KEY(bookId) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // 3. Paragraphs table
    await db.execute('''
      CREATE TABLE paragraphs (
        id TEXT PRIMARY KEY,
        chapterId TEXT NOT NULL,
        bookId TEXT NOT NULL,
        paragraphIndex INTEGER NOT NULL,
        text TEXT NOT NULL,
        type TEXT DEFAULT 'text',
        imagePath TEXT,
        originalLang TEXT,
        isRTL INTEGER DEFAULT 0,
        isOcr INTEGER DEFAULT 0,
        pdfPageNumber INTEGER,
        FOREIGN KEY(chapterId) REFERENCES chapters(id) ON DELETE CASCADE
      )
    ''');

    // 4. Bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        chapterId TEXT NOT NULL,
        paragraphIndex INTEGER NOT NULL,
        note TEXT,
        color TEXT,
        createdAt TEXT
      )
    ''');

    // 5. Reading positions table
    await db.execute('''
      CREATE TABLE reading_positions (
        bookId TEXT PRIMARY KEY,
        chapterIndex INTEGER,
        paragraphIndex INTEGER,
        savedAt TEXT
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_chapters_bookId ON chapters(bookId)');
    await db.execute('CREATE INDEX idx_paragraphs_bookId ON paragraphs(bookId)');
    await db.execute('CREATE INDEX idx_paragraphs_chapterId_index ON paragraphs(chapterId, paragraphIndex)');
    await db.execute('CREATE INDEX idx_bookmarks_bookId ON bookmarks(bookId)');
  }

  // --- Book CRUD ---

  Future<void> insertBook(Book book) async {
    final db = await database;
    await db.insert('books', {
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'filePath': book.filePath,
      'coverPath': book.coverUrl,
      'format': 'pdf',
      'addedAt': book.addedAt.toIso8601String(),
      'lastReadAt': book.lastReadAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Book?> getBook(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final map = maps.first;
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      filePath: map['filePath'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastReadAt: map['lastReadAt'] != null ? DateTime.parse(map['lastReadAt'] as String) : null,
      coverUrl: map['coverPath'] as String?,
      readingProgress: (map['readingProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'addedAt DESC');
    return maps.map((map) => Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      filePath: map['filePath'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastReadAt: map['lastReadAt'] != null ? DateTime.parse(map['lastReadAt'] as String) : null,
      coverUrl: map['coverPath'] as String?,
      readingProgress: (map['readingProgress'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  Future<void> updateReadingProgress(String bookId, int chapterIndex, int paragraphIndex, double progress) async {
    final db = await database;
    await db.update('books', {
      'currentChapterIndex': chapterIndex,
      'currentParagraphIndex': paragraphIndex,
      'readingProgress': progress,
      'lastReadAt': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> deleteBook(String id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // --- Chapter CRUD ---

  Future<void> insertChapters(List<ParsedChapter> chapters, String bookId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var chapter in chapters) {
        await txn.insert('chapters', {
          'id': '${bookId}_${chapter.index}',
          'bookId': bookId,
          'chapterIndex': chapter.index,
          'title': chapter.title,
          'totalParagraphs': chapter.paragraphs.length,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<ParsedChapter>> getChapters(String bookId) async {
    final db = await database;
    final maps = await db.query('chapters', where: 'bookId = ?', whereArgs: [bookId], orderBy: 'chapterIndex ASC');
    List<ParsedChapter> chapters = [];
    for (var map in maps) {
      chapters.add(ParsedChapter(
        index: map['chapterIndex'] as int,
        title: map['title'] as String,
        paragraphs: [], // Loaded separately via getParagraphsForChapter
      ));
    }
    return chapters;
  }

  // --- Paragraph CRUD ---

  Future<void> insertParagraphs(List<ParsedParagraph> paragraphs, String chapterId, String bookId) async {
    final db = await database;
    await db.transaction((txn) async {
      const batchSize = 500;
      for (var i = 0; i < paragraphs.length; i += batchSize) {
        final batch = txn.batch();
        final end = (i + batchSize < paragraphs.length) ? i + batchSize : paragraphs.length;
        for (var j = i; j < end; j++) {
          final p = paragraphs[j];
          batch.insert('paragraphs', {
            'id': '${chapterId}_${p.index}',
            'chapterId': chapterId,
            'bookId': bookId,
            'paragraphIndex': p.index,
            'text': p.text,
            'type': p.type.name,
            'imagePath': p.imagePath,
            'isRTL': p.isRTL ? 1 : 0,
            'isOcr': p.isOcrResult ? 1 : 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<List<ParsedParagraph>> getParagraphsForChapter(String chapterId) async {
    final db = await database;
    final maps = await db.query('paragraphs', where: 'chapterId = ?', whereArgs: [chapterId], orderBy: 'paragraphIndex ASC');
    return maps.map((map) => ParsedParagraph(
      index: map['paragraphIndex'] as int,
      text: map['text'] as String,
      type: ParagraphType.values.firstWhere((e) => e.name == (map['type'] as String)),
      imagePath: map['imagePath'] as String?,
      isRTL: map['isRTL'] == 1,
      isOcrResult: map['isOcr'] == 1,
    )).toList();
  }

  Future<List<ParsedParagraph>> searchInBook(String bookId, String query) async {
    final db = await database;
    final maps = await db.query('paragraphs', where: 'bookId = ? AND text LIKE ?', whereArgs: [bookId, '%$query%']);
    return maps.map((map) => ParsedParagraph(
      index: map['paragraphIndex'] as int,
      text: map['text'] as String,
      type: ParagraphType.values.firstWhere((e) => e.name == (map['type'] as String)),
      imagePath: map['imagePath'] as String?,
      isRTL: map['isRTL'] == 1,
      isOcrResult: map['isOcr'] == 1,
    )).toList();
  }

  // --- Reading Position ---

  Future<void> saveReadingPosition(String bookId, int chapterIndex, int paragraphIndex) async {
    final db = await database;
    await db.insert('reading_positions', {
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'paragraphIndex': paragraphIndex,
      'savedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>?> getReadingPosition(String bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reading_positions', where: 'bookId = ?', whereArgs: [bookId]);
    if (maps.isEmpty) return null;
    return {
      'chapterIndex': maps.first['chapterIndex'],
      'paragraphIndex': maps.first['paragraphIndex'],
    };
  }

  // --- Bookmarks ---

  Future<void> addBookmark(Bookmark bookmark) async {
    final db = await database;
    await db.insert('bookmarks', {
      'id': bookmark.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'bookId': bookmark.bookId,
      'chapterId': '${bookmark.bookId}_${bookmark.chapterIndex}',
      'paragraphIndex': bookmark.paragraphIndex,
      'note': bookmark.title,
      'createdAt': bookmark.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Bookmark>> getBookmarks(String bookId) async {
    final db = await database;
    final maps = await db.query('bookmarks', where: 'bookId = ?', whereArgs: [bookId], orderBy: 'createdAt DESC');
    return maps.map((map) => Bookmark(
      id: int.tryParse((map['id'] as String?) ?? ''),
      bookId: map['bookId'] as String,
      chapterIndex: int.parse((map['chapterId'] as String).split('_').last),
      paragraphIndex: map['paragraphIndex'] as int,
      title: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    )).toList();
  }

  Future<void> deleteBookmark(String id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
