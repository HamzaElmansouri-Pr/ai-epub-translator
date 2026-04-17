import 'package:equatable/equatable.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';

abstract class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {}

class LibraryLoading extends LibraryState {}

class LibraryLoaded extends LibraryState {
  final List<Book> books;
  const LibraryLoaded(this.books);

  @override
  List<Object?> get props => [books];
}

class LibraryError extends LibraryState {
  final String message;
  const LibraryError(this.message);

  @override
  List<Object?> get props => [message];
}
