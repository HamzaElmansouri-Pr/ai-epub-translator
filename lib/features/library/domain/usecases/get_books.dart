import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/domain/repositories/library_repository.dart';

@lazySingleton
class GetBooks {
  final LibraryRepository repository;

  GetBooks(this.repository);

  Future<Either<Failure, List<Book>>> call() async {
    return await repository.getBooks();
  }
}
