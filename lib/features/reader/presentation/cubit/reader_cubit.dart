import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/features/reader/domain/repositories/reader_repository.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_state.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';

@lazySingleton
class ReaderCubit extends Cubit<ReaderState> {
  final ReaderRepository repository;

  ReaderCubit(this.repository) : super(ReaderInitial());

  Future<void> loadBook(String filePath, String bookId) async {
    // Reset to initial state first to clear any stale data from previous book
    emit(ReaderInitial());
    emit(ReaderLoading());
    final result = await repository.getChapters(filePath);
    result.fold(
      (failure) => emit(ReaderError(failure.message)),
      (chapters) async {
        // Load offline data for the book
        final bookmarksResult = await repository.getBookmarks(bookId);
        final notesResult = await repository.getNotes(bookId);
        final progressResult = await repository.getReadingProgress(bookId);

        emit(ReaderLoaded(
          chapters: chapters,
          bookmarks: bookmarksResult.getOrElse(() => []),
          notes: notesResult.getOrElse(() => []),
          progress: progressResult.getOrElse(() => null),
          currentChapterIndex: progressResult.fold(
            (_) => 0,
            (progress) => progress?.chapterIndex ?? 0,
          ),
        ));
      },
    );
  }

  void changeChapter(int index) {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      if (index >= 0 && index < currentState.chapters.length) {
        emit(currentState.copyWith(currentChapterIndex: index));
      }
    }
  }

  Future<void> toggleBookmark(Bookmark bookmark) async {
    final currentState = state;
    if (currentState is ReaderLoaded) {
      // Find if ALREADY bookmarked this specific spot
      final existingAtSpot = currentState.bookmarks.where((b) => 
        b.chapterIndex == bookmark.chapterIndex && b.paragraphIndex == bookmark.paragraphIndex).firstOrNull;

      if (existingAtSpot != null) {
        // Unpin
        await repository.removeBookmark(existingAtSpot.id!);
      } else {
        // Enforce ONE PIN PER BOOK: Remove all other bookmarks for this bookId
        for (var b in currentState.bookmarks) {
          if (b.id != null) await repository.removeBookmark(b.id!);
        }
        // Save the new one
        await repository.saveBookmark(bookmark);
      }
      
      final updatedBookmarks = await repository.getBookmarks(bookmark.bookId);
      emit(currentState.copyWith(bookmarks: updatedBookmarks.getOrElse(() => [])));
    }
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    // Legacy support, but we'll use toggleBookmark
    await toggleBookmark(bookmark);
  }

  Future<void> removeBookmark(int id, String bookId) async {
    final currentState = state;
    if (currentState is ReaderLoaded) {
      await repository.removeBookmark(id);
      final updatedBookmarks = await repository.getBookmarks(bookId);
      emit(currentState.copyWith(bookmarks: updatedBookmarks.getOrElse(() => currentState.bookmarks)));
    }
  }

  Future<void> addNote(Note note) async {
    final currentState = state;
    if (currentState is ReaderLoaded) {
      await repository.saveNote(note);
      final updatedNotes = await repository.getNotes(note.bookId);
      emit(currentState.copyWith(notes: updatedNotes.getOrElse(() => currentState.notes)));
    }
  }

  Future<void> removeNote(int id, String bookId) async {
    final currentState = state;
    if (currentState is ReaderLoaded) {
      await repository.removeNote(id);
      final updatedNotes = await repository.getNotes(bookId);
      emit(currentState.copyWith(notes: updatedNotes.getOrElse(() => currentState.notes)));
    }
  }

  Future<void> updateReadingProgress(ReadingProgress progress) async {
    final currentState = state;
    if (currentState is ReaderLoaded) {
      // Don't emit to avoid unnecessary re-renders of the whole page, just save in background
      await repository.saveReadingProgress(progress);
    }
  }
}
