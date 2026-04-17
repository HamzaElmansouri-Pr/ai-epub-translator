import 'package:dartz/dartz.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reader_entities.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';

abstract class ReaderRepository {
  Future<Either<Failure, List<Chapter>>> getChapters(String filePath);

  Future<Either<Failure, List<Bookmark>>> getBookmarks(String bookId);
  Future<Either<Failure, void>> saveBookmark(Bookmark bookmark);
  Future<Either<Failure, void>> removeBookmark(int id);

  Future<Either<Failure, List<Note>>> getNotes(String bookId);
  Future<Either<Failure, void>> saveNote(Note note);
  Future<Either<Failure, void>> removeNote(int id);

  Future<Either<Failure, ReadingProgress?>> getReadingProgress(String bookId);
  Future<Either<Failure, void>> saveReadingProgress(ReadingProgress progress);
}
