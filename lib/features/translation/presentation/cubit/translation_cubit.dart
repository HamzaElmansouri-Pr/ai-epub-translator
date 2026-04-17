import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/features/translation/domain/repositories/translation_repository.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_state.dart';

@injectable
class TranslationCubit extends Cubit<TranslationState> {
  final TranslationRepository repository;

  TranslationCubit(this.repository) : super(TranslationInitial());

  /// Reset to initial state so a new paragraph can be translated.
  void reset() {
    emit(TranslationInitial());
  }

  Future<void> translateParagraph(
    String text,
    String targetLanguage, {
    String? bookId,
    bool useGoogleTranslate = false,
  }) async {
    emit(TranslationLoading(text));
    final result = await repository.translate(
      text,
      targetLanguage: targetLanguage,
      bookId: bookId,
      useGoogleTranslate: useGoogleTranslate,
    );
    result.fold((failure) {
      if (failure.message.contains('exhausted') ||
          failure.message == 'API_QUOTA_EXCEEDED') {
        emit(TranslationExhausted());
      } else {
        emit(TranslationError(failure.message));
      }
    }, (translation) => emit(TranslationSuccess(translation)));
  }
}
