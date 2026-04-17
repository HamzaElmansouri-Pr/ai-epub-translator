import 'package:equatable/equatable.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reader_entities.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';

abstract class ReaderState extends Equatable {
  const ReaderState();

  @override
  List<Object?> get props => [];
}

class ReaderInitial extends ReaderState {}

class ReaderLoading extends ReaderState {}

class ReaderLoaded extends ReaderState {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final List<Bookmark> bookmarks;
  final List<Note> notes;
  final ReadingProgress? progress;

  const ReaderLoaded({
    required this.chapters,
    this.currentChapterIndex = 0,
    this.bookmarks = const [],
    this.notes = const [],
    this.progress,
  });

  Chapter get currentChapter => chapters[currentChapterIndex];

  ReaderLoaded copyWith({
    List<Chapter>? chapters,
    int? currentChapterIndex,
    List<Bookmark>? bookmarks,
    List<Note>? notes,
    ReadingProgress? progress,
  }) {
    return ReaderLoaded(
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      bookmarks: bookmarks ?? this.bookmarks,
      notes: notes ?? this.notes,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [chapters, currentChapterIndex, bookmarks, notes, progress];
}

class ReaderError extends ReaderState {
  final String message;
  const ReaderError(this.message);

  @override
  List<Object?> get props => [message];
}
