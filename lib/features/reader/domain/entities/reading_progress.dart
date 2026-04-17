import 'package:equatable/equatable.dart';

class ReadingProgress extends Equatable {
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final double scrollPosition;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.scrollPosition,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [bookId, chapterIndex, paragraphIndex, scrollPosition, updatedAt];
}
