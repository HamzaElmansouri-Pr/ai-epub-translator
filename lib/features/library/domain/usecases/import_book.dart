import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/domain/repositories/library_repository.dart';

@lazySingleton
class ImportBook {
  final LibraryRepository repository;

  ImportBook(this.repository);

  Future<Either<Failure, Book>> call(String filePath) async {
    return await repository.importBook(filePath);
  }

  Future<Either<Failure, Book>> fromBytes(String title, Uint8List bytes) async {
    return await repository.importBookFromBytes(title, bytes);
  }
}
