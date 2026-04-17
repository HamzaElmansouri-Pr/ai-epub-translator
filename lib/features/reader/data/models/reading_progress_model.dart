import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';

class ReadingProgressModel extends ReadingProgress {
  const ReadingProgressModel({
    required super.bookId,
    required super.chapterIndex,
    required super.paragraphIndex,
    required super.scrollPosition,
    required super.updatedAt,
  });

  factory ReadingProgressModel.fromMap(Map<String, dynamic> map) {
    return ReadingProgressModel(
      bookId: map['book_id'],
      chapterIndex: map['chapter_index'],
      paragraphIndex: map['paragraph_index'],
      scrollPosition: map['scroll_position']?.toDouble() ?? 0.0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'paragraph_index': paragraphIndex,
      'scroll_position': scrollPosition,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingProgressModel.fromEntity(ReadingProgress entity) {
    return ReadingProgressModel(
      bookId: entity.bookId,
      chapterIndex: entity.chapterIndex,
      paragraphIndex: entity.paragraphIndex,
      scrollPosition: entity.scrollPosition,
      updatedAt: entity.updatedAt,
    );
  }
}
