import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/get_books.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/import_book.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/update_book.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_state.dart';

@injectable
class LibraryCubit extends Cubit<LibraryState> {
  final GetBooks getBooks;
  final ImportBook importBook;
  final UpdateBook updateBook;

  LibraryCubit({
    required this.getBooks,
    required this.importBook,
    required this.updateBook,
  }) : super(LibraryInitial());

  Future<void> loadBooks() async {
    emit(LibraryLoading());
    final result = await getBooks();
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (books) => emit(LibraryLoaded(books)),
    );
  }

  Future<void> pickAndImportBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    emit(LibraryLoading());

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        emit(const LibraryError('Could not read file bytes on Web.'));
        return;
      }
      final importResult = await importBook.fromBytes(
        file.name.replaceAll('.epub', ''),
        bytes,
      );
      importResult.fold(
        (failure) => emit(LibraryError(failure.message)),
        (_) => loadBooks(),
      );
    } else {
      final path = file.path;
      if (path == null) {
        emit(const LibraryError('Could not get file path.'));
        return;
      }
      final importResult = await importBook(path);
      importResult.fold(
        (failure) => emit(LibraryError(failure.message)),
        (_) => loadBooks(),
      );
    }
  }

  Future<void> importBookFromBytes(String title, Uint8List bytes) async {
    emit(LibraryLoading());
    final result = await importBook.fromBytes(title, bytes);
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (_) => loadBooks(),
    );
  }

  Future<void> changeBookStatus(Book book, String newStatus) async {
    if (book.status == newStatus) return;
    final updatedBook = book.copyWith(status: newStatus);
    final result = await updateBook(updatedBook);
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (_) => loadBooks(),
    );
  }

  Future<void> toggleFavorite(Book book) async {
    final updatedBook = book.copyWith(isFavorite: !book.isFavorite);
    final result = await updateBook(updatedBook);
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (_) => loadBooks(),
    );
  }

  Future<void> updateBookCover(Book book, String coverUrl) async {
    final updatedBook = book.copyWith(coverUrl: coverUrl);
    final result = await updateBook(updatedBook);
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (_) => loadBooks(),
    );
  }
}
