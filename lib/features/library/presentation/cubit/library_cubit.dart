import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/get_books.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/import_book.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/update_book.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/delete_book.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_state.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';

@lazySingleton
class LibraryCubit extends Cubit<LibraryState> {
  final GetBooks getBooks;
  final ImportBook importBook;
  final UpdateBook updateBook;
  final DeleteBook removeBookFromDb;

  LibraryCubit({
    required this.getBooks,
    required this.importBook,
    required this.updateBook,
    required this.removeBookFromDb,
  }) : super(LibraryInitial());

  Future<void> loadBooks({List<String>? autoScanPaths}) async {
    if (autoScanPaths != null && autoScanPaths.isNotEmpty) {
      await scanAutoImportFolders(autoScanPaths);
    }
    
    emit(LibraryLoading());
    final result = await getBooks();
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (books) {
        // Sort: Pinned first, then by date added (newest first)
        final sortedBooks = List<Book>.from(books)
          ..sort((a, b) {
            if (a.isPinned != b.isPinned) {
              return a.isPinned ? -1 : 1;
            }
            return b.addedAt.compareTo(a.addedAt);
          });
        emit(LibraryLoaded(sortedBooks));
      },
    );
  }

  Future<void> scanAutoImportFolders(List<String> folderPaths) async {
    try {
      final currentBooksResult = await getBooks();
      final currentPaths = currentBooksResult.fold(
        (_) => <String>[], 
        (books) => books.map((b) => b.filePath).toList()
      );

      for (final folderPath in folderPaths) {
        final directory = Directory(folderPath);
        if (!await directory.exists()) continue;

        final entities = await directory.list().toList();
        final supportedFiles = entities
            .whereType<File>()
            .where((f) {
              final ext = p.extension(f.path).toLowerCase();
              return ext == '.epub' || ext == '.pdf';
            });

        for (final file in supportedFiles) {
          if (!currentPaths.contains(file.path)) {
            await importBook(file.path);
            // Refresh paths after each import to prevent double-importing if the scan is fast
            currentPaths.add(file.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning auto-import folders: $e');
    }
  }

  Future<void> pickAndImportBook({List<String> extensions = const ['epub', 'pdf']}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true, // Required for Web to get bytes
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    emit(LibraryLoading());

    if (kIsWeb) {
      // On Web, path is null - use bytes instead
      final bytes = file.bytes;
      if (bytes == null) {
        emit(const LibraryError('Could not read file bytes on Web.'));
        return;
      }
      final isPdf = file.name.toLowerCase().endsWith('.pdf');
      final importResult =
          await importBook.fromBytes(file.name.replaceAll(isPdf ? '.pdf' : '.epub', ''), bytes);
      importResult.fold(
        (failure) => emit(LibraryError(failure.message)),
        (_) => loadBooks(),
      );
    } else {
      // Native: use path
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

  Future<void> pickAndImportPdf() async {
    return pickAndImportBook(extensions: ['pdf']);
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

  Future<void> togglePin(Book book) async {
    final state = this.state;
    if (state is LibraryLoaded) {
      final pinnedCount = state.books.where((b) => b.isPinned).length;
      if (!book.isPinned && pinnedCount >= 3) {
        // Already 3 pinned books, don't allow more
        return;
      }
    }
    
    final updatedBook = book.copyWith(isPinned: !book.isPinned);
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

  Future<void> deleteBook(String id) async {
    emit(LibraryLoading());
    final result = await removeBookFromDb(id);
    result.fold(
      (failure) => emit(LibraryError(failure.message)),
      (_) => loadBooks(),
    );
  }
}
