import 'package:dartz/dartz.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/local_book_datasource.dart';
import 'package:epub_translate_meaning/features/library/data/models/book_model.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/domain/repositories/library_repository.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'file_reader_stub.dart'
    if (dart.library.io) 'package:epub_translate_meaning/core/utils/file_reader_native.dart'
    if (dart.library.html) 'package:epub_translate_meaning/core/utils/file_reader_web.dart';

@LazySingleton(as: LibraryRepository)
class LibraryRepositoryImpl implements LibraryRepository {
  final LocalBookDataSource localDataSource;
  final Uuid uuid = const Uuid();

  LibraryRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, List<Book>>> getBooks() async {
    try {
      final books = await localDataSource.getBooks();
      return Right(books);
    } catch (e) {
      return const Left(CacheFailure('Failed to load books from library'));
    }
  }

  @override
  Future<Either<Failure, Book>> importBook(String filePath) async {
    if (kIsWeb) {
      return const Left(
        FileFailure(
          'File path import is unavailable on Web. Use import from bytes.',
        ),
      );
    }
    try {
      final bytes = await readFileBytes(filePath);
      return _parseAndSave(filePath, bytes);
    } catch (e) {
      return Left(FileFailure('Failed to import file: $e'));
    }
  }

  @override
  Future<Either<Failure, Book>> importBookFromBytes(
    String title,
    Uint8List bytes,
  ) async {
    return _parseAndSave('memory://$title', bytes, epubBytes: bytes);
  }

  Future<Either<Failure, Book>> _parseAndSave(
    String filePath,
    Uint8List bytes, {
    Uint8List? epubBytes,
  }) async {
    try {
      final epubBook = await EpubReader.readBook(bytes);
      final bookModel = BookModel(
        id: uuid.v4(),
        title:
            epubBook.Title ?? filePath.split('/').last.replaceAll('.epub', ''),
        author: epubBook.Author,
        filePath: filePath,
        addedAt: DateTime.now(),
      );
      await localDataSource.saveBook(bookModel, epubBytes: epubBytes ?? bytes);
      return Right(bookModel);
    } catch (e) {
      return Left(FileFailure('Failed to parse ePub: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeBook(String id) async {
    try {
      await localDataSource.removeBook(id);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to remove book from library'));
    }
  }

  @override
  Future<Either<Failure, Book>> updateBook(Book book) async {
    try {
      final bookModel = BookModel.fromEntity(book);
      await localDataSource.saveBook(bookModel);
      return Right(bookModel);
    } catch (e) {
      return const Left(CacheFailure('Failed to update book'));
    }
  }
}
