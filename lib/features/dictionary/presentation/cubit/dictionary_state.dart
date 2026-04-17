import 'package:equatable/equatable.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/entities/dictionary_entry.dart';

abstract class DictionaryState extends Equatable {
  const DictionaryState();

  @override
  List<Object?> get props => [];
}

class DictionaryInitial extends DictionaryState {}

class DictionaryLoading extends DictionaryState {
  final String word;
  const DictionaryLoading(this.word);
  
  @override
  List<Object?> get props => [word];
}

class DictionaryLoaded extends DictionaryState {
  final String word;
  final List<DictionaryEntry> entries;

  const DictionaryLoaded(this.word, this.entries);

  @override
  List<Object?> get props => [word, entries];
}

class DictionaryError extends DictionaryState {
  final String message;

  const DictionaryError(this.message);

  @override
  List<Object?> get props => [message];
}

class DictionaryNotFound extends DictionaryState {
  final String word;
  const DictionaryNotFound(this.word);

  @override
  List<Object?> get props => [word];
}