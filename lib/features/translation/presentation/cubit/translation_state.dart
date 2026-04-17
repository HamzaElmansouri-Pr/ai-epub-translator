import 'package:equatable/equatable.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';

abstract class TranslationState extends Equatable {
  const TranslationState();

  @override
  List<Object?> get props => [];
}

class TranslationInitial extends TranslationState {}

class TranslationLoading extends TranslationState {
  final String originalText;
  const TranslationLoading(this.originalText);

  @override
  List<Object?> get props => [originalText];
}

class TranslationSuccess extends TranslationState {
  final Translation translation;
  const TranslationSuccess(this.translation);

  @override
  List<Object?> get props => [translation];
}

class TranslationError extends TranslationState {
  final String message;
  const TranslationError(this.message);

  @override
  List<Object?> get props => [message];
}

class TranslationExhausted extends TranslationState {}
