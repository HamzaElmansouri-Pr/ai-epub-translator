import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';

abstract class LibraryRepository {
  Future<Either<Failure, List<Book>>> getBooks();
  Future<Either<Failure, Book>> importBook(String filePath);
  Future<Either<Failure, Book>> importBookFromBytes(
    String title,
    Uint8List bytes,
  );
  Future<Either<Failure, Unit>> removeBook(String id);
  Future<Either<Failure, Book>> updateBook(Book book);
}
