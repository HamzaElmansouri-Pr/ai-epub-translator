import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/library/domain/repositories/library_repository.dart';

@lazySingleton
class DeleteBook {
  final LibraryRepository repository;

  DeleteBook(this.repository);

  Future<Either<Failure, Unit>> call(String id) async {
    return await repository.removeBook(id);
  }
}
