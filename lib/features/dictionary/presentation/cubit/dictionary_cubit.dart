import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/repositories/dictionary_repository.dart';
import 'package:epub_translate_meaning/features/dictionary/presentation/cubit/dictionary_state.dart';

@injectable
class DictionaryCubit extends Cubit<DictionaryState> {
  final DictionaryRepository repository;

  DictionaryCubit(this.repository) : super(DictionaryInitial());

  Future<void> lookupWord(String rawWord) async {
    // Sanitize word: remove punctuation like commas, periods, quotes
    final word = rawWord.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().toLowerCase();
    
    if (word.isEmpty) {
      return;
    }

    emit(DictionaryLoading(word));
    
    final result = await repository.lookupWord(word);
    
    result.fold(
      (failure) => emit(DictionaryError(failure.message)),
      (entries) {
        if (entries.isEmpty) {
          emit(DictionaryNotFound(word));
        } else {
          emit(DictionaryLoaded(word, entries));
        }
      },
    );
  }
}