import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/features/translation/domain/repositories/translation_repository.dart';

abstract class BulkTranslationState {}

class BulkTranslationIdle extends BulkTranslationState {}

class BulkTranslationInProgress extends BulkTranslationState {
  final int current;
  final int total;
  BulkTranslationInProgress(this.current, this.total);
}

class BulkTranslationCompleted extends BulkTranslationState {}

class BulkTranslationError extends BulkTranslationState {
  final String message;
  BulkTranslationError(this.message);
}

@lazySingleton
class BulkTranslationCubit extends Cubit<BulkTranslationState> {
  final TranslationRepository translationRepository;

  BulkTranslationCubit(this.translationRepository)
    : super(BulkTranslationIdle());

  bool _isTranslating = false;

  void stop() {
    _isTranslating = false;
    emit(BulkTranslationIdle());
  }

  Future<void> translateParagraphs(
    List<String> paragraphs,
    String targetLang,
    String bookId, {
    bool useGoogleTranslate = false,
  }) async {
    if (_isTranslating) return;
    _isTranslating = true;

    final validParagraphs = paragraphs
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (validParagraphs.isEmpty) {
      _isTranslating = false;
      return;
    }

    emit(BulkTranslationInProgress(0, validParagraphs.length));

    final batchSize = 10;
    int processedCount = 0;

    for (int i = 0; i < validParagraphs.length; i += batchSize) {
      if (!_isTranslating) break;

      final chunk = validParagraphs.skip(i).take(batchSize).toList();

      final res = await translationRepository.translateBatch(
        chunk,
        targetLanguage: targetLang,
        bookId: bookId,
        useGoogleTranslate: useGoogleTranslate,
      );

      res.fold(
        (failure) {
          // Skip failing chunk but continue translating the rest of the book
          if (_isTranslating) {
            processedCount += chunk.length;
            emit(
              BulkTranslationInProgress(processedCount, validParagraphs.length),
            );
          }
        },
        (translations) {
          if (_isTranslating) {
            processedCount += chunk.length;
            emit(
              BulkTranslationInProgress(processedCount, validParagraphs.length),
            );
          }
        },
      );

      if (!_isTranslating) break; // Error occurred, break chunk loop
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Sleep between chunks to prevent burst limits
    }

    if (_isTranslating) {
      _isTranslating = false;
      emit(BulkTranslationCompleted());
      Future.delayed(const Duration(seconds: 3), () {
        if (state is BulkTranslationCompleted) emit(BulkTranslationIdle());
      });
    }
  }
}
