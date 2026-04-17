import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

@lazySingleton
class DatabaseHelper {
  static const String _databaseName = "epub_translate.db";
  static const int _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not supported on Web. Use a mock or different storage.',
      );
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add status and is_favorite to books table
      await db.execute(
        'ALTER TABLE books ADD COLUMN status TEXT DEFAULT "reading"',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN is_favorite INTEGER DEFAULT 0',
      );

      // Create bookmarks table
      await db.execute('''
        CREATE TABLE bookmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          paragraph_index INTEGER NOT NULL,
          title TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create notes table
      await db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          paragraph_hash TEXT NOT NULL,
          text TEXT NOT NULL,
          color_mark TEXT, 
          created_at INTEGER NOT NULL
        )
      ''');

      // Reading progress table
      await db.execute('''
        CREATE TABLE reading_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          scroll_position REAL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(id)
        )
      ''');

      // Vocabulary Vault for Contextual Smart Dictionary
      await db.execute('''
        CREATE TABLE vocabulary_vault (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL,
          context_paragraph TEXT NOT NULL,
          meaning TEXT NOT NULL,
          language TEXT NOT NULL,
          added_at INTEGER NOT NULL,
          last_reviewed_at INTEGER
        )
      ''');
    }
    
    if (oldVersion < 3) {
      // Add cover_url to books
      await db.execute('ALTER TABLE books ADD COLUMN cover_url TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Translations table
    await db.execute('''
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        paragraph_hash TEXT NOT NULL,
        original_text TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        language_pair TEXT NOT NULL,
        provider TEXT,
        created_at INTEGER NOT NULL,
        UNIQUE(book_id, paragraph_hash, language_pair)
      )
    ''');

    // Index for fast lookup
    await db.execute('''
      CREATE INDEX idx_cache_lookup 
      ON translations(book_id, paragraph_hash, language_pair)
    ''');

    // Books table (to eventually replace SharedPreferences storage)
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        file_path TEXT NOT NULL,
        cover_image BLOB,
        cover_url TEXT,
        status TEXT DEFAULT 'reading',
        is_favorite INTEGER DEFAULT 0,
        added_at INTEGER NOT NULL,
        last_read_at INTEGER
      )
    ''');

    // Create bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        paragraph_index INTEGER NOT NULL,
        title TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create notes table
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        paragraph_hash TEXT NOT NULL,
        text TEXT NOT NULL,
        color_mark TEXT, 
        created_at INTEGER NOT NULL
      )
    ''');

    // Reading progress table
    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        scroll_position REAL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    // Vocabulary Vault for Contextual Smart Dictionary
    await db.execute('''
      CREATE TABLE vocabulary_vault (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        context_paragraph TEXT NOT NULL,
        meaning TEXT NOT NULL,
        language TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        last_reviewed_at INTEGER
      )
    ''');
  }
}
