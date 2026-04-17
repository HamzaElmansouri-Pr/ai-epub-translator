import 'package:dartz/dartz.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/entities/dictionary_entry.dart';

abstract class DictionaryRepository {
  Future<Either<Failure, List<DictionaryEntry>>> lookupWord(String word);
}