import 'package:equatable/equatable.dart';

class ReadingProgress extends Equatable {
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final double scrollPosition;
  final double progressPercent;
  final String format; // 'epub' or 'pdf'
  final String? epubCfi; // Canonical Fragment Identifier for exact ePub position
  final DateTime updatedAt;

  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.scrollPosition,
    this.progressPercent = 0.0,
    this.format = 'epub',
    this.epubCfi,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [bookId, chapterIndex, paragraphIndex, scrollPosition, progressPercent, format, epubCfi, updatedAt];
}
