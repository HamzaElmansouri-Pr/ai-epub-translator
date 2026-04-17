import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reader_entities.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';
import 'package:epub_translate_meaning/features/reader/domain/repositories/reader_repository.dart';
import 'package:epub_translate_meaning/features/reader/data/datasources/epub_parser_datasource.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/local_book_datasource.dart';
import 'package:epub_translate_meaning/features/reader/data/models/bookmark_model.dart';
import 'package:epub_translate_meaning/features/reader/data/models/note_model.dart';
import 'package:epub_translate_meaning/features/reader/data/models/reading_progress_model.dart';

@LazySingleton(as: ReaderRepository)
class ReaderRepositoryImpl implements ReaderRepository {
  final EpubParserDataSource dataSource;
  final LocalBookDataSource localDataSource;

  ReaderRepositoryImpl(this.dataSource, this.localDataSource);

  @override
  Future<Either<Failure, List<Chapter>>> getChapters(String filePath) async {
    try {
      final chapters = await dataSource.parseEpub(filePath);
      return Right(chapters);
    } catch (e) {
      return const Left(FileFailure('Failed to parse ePub content'));
    }
  }

  @override
  Future<Either<Failure, List<Bookmark>>> getBookmarks(String bookId) async {
    try {
      final bookmarks = await localDataSource.getBookmarks(bookId);
      return Right(bookmarks);
    } catch (_) {
      return const Left(CacheFailure('Failed to fetch bookmarks'));
    }
  }

  @override
  Future<Either<Failure, void>> saveBookmark(Bookmark bookmark) async {
    try {
      await localDataSource.saveBookmark(BookmarkModel.fromEntity(bookmark));
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to save bookmark'));
    }
  }

  @override
  Future<Either<Failure, void>> removeBookmark(int id) async {
    try {
      await localDataSource.removeBookmark(id);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to remove bookmark'));
    }
  }

  @override
  Future<Either<Failure, List<Note>>> getNotes(String bookId) async {
    try {
      final notes = await localDataSource.getNotes(bookId);
      return Right(notes);
    } catch (_) {
      return const Left(CacheFailure('Failed to fetch notes'));
    }
  }

  @override
  Future<Either<Failure, void>> saveNote(Note note) async {
    try {
      await localDataSource.saveNote(NoteModel.fromEntity(note));
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to save note'));
    }
  }

  @override
  Future<Either<Failure, void>> removeNote(int id) async {
    try {
      await localDataSource.removeNote(id);
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to remove note'));
    }
  }

  @override
  Future<Either<Failure, ReadingProgress?>> getReadingProgress(String bookId) async {
    try {
      final progress = await localDataSource.getReadingProgress(bookId);
      return Right(progress);
    } catch (_) {
      return const Left(CacheFailure('Failed to fetch reading progress'));
    }
  }

  @override
  Future<Either<Failure, void>> saveReadingProgress(ReadingProgress progress) async {
    try {
      await localDataSource.saveReadingProgress(ReadingProgressModel.fromEntity(progress));
      return const Right(null);
    } catch (_) {
      return const Left(CacheFailure('Failed to save reading progress'));
    }
  }
}
