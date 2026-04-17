import 'package:dartz/dartz.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';

abstract class TranslationRepository {
  Future<Either<Failure, Translation>> translate(
    String text, {
    required String targetLanguage,
    String? bookId,
    bool useGoogleTranslate = false,
  });

  Future<Either<Failure, List<Translation>>> translateBatch(
    List<String> texts, {
    required String targetLanguage,
    String? bookId,
    bool useGoogleTranslate = false,
  });
}
