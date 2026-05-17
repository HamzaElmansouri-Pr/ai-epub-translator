import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';

class ReadingProgressModel extends ReadingProgress {
  const ReadingProgressModel({
    required super.bookId,
    required super.chapterIndex,
    required super.paragraphIndex,
    required super.scrollPosition,
    super.progressPercent,
    super.format,
    super.epubCfi,
    required super.updatedAt,
  });

  factory ReadingProgressModel.fromMap(Map<String, dynamic> map) {
    return ReadingProgressModel(
      bookId: map['book_id'] as String,
      chapterIndex: map['chapter_index'] as int,
      paragraphIndex: map['paragraph_index'] as int? ?? 0,
      scrollPosition: (map['scroll_position'] as num?)?.toDouble() ?? 0.0,
      progressPercent: (map['progress_percent'] as num?)?.toDouble() ?? 0.0,
      format: map['format'] as String? ?? 'epub',
      epubCfi: map['epub_cfi'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'paragraph_index': paragraphIndex,
      'scroll_position': scrollPosition,
      'progress_percent': progressPercent,
      'format': format,
      'epub_cfi': epubCfi,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingProgressModel.fromEntity(ReadingProgress entity) {
    return ReadingProgressModel(
      bookId: entity.bookId,
      chapterIndex: entity.chapterIndex,
      paragraphIndex: entity.paragraphIndex,
      scrollPosition: entity.scrollPosition,
      progressPercent: entity.progressPercent,
      format: entity.format,
      epubCfi: entity.epubCfi,
      updatedAt: entity.updatedAt,
    );
  }
}
