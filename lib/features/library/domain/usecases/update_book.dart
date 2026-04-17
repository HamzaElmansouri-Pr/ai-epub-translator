import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/domain/repositories/library_repository.dart';

@lazySingleton
class UpdateBook {
  final LibraryRepository repository;

  UpdateBook(this.repository);

  Future<Either<Failure, Book>> call(Book book) {
    return repository.updateBook(book);
  }
}
