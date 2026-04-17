import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/features/library/data/models/book_model.dart';

/// A simple in-memory store used on Web (where SQLite is unavailable)
/// and as a fallback to hold parsed ePub bytes for the reader.
@lazySingleton
class InMemoryBookStore {
  final Map<String, BookModel> _books = {};

  /// Raw epub bytes keyed by book ID, so the reader can parse them.
  final Map<String, Uint8List> _epubBytes = {};

  List<BookModel> getBooks() => _books.values.toList();

  void saveBook(BookModel book) {
    _books[book.id] = book;
  }

  void removeBook(String id) {
    _books.remove(id);
    _epubBytes.remove(id);
  }

  void saveBytes(String bookId, Uint8List bytes) {
    _epubBytes[bookId] = bytes;
  }

  Uint8List? getBytes(String bookId) => _epubBytes[bookId];
}
