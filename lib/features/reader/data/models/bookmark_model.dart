import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';

class BookmarkModel extends Bookmark {
  const BookmarkModel({
    super.id,
    required super.bookId,
    required super.chapterIndex,
    required super.paragraphIndex,
    super.title,
    required super.createdAt,
  });

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'],
      bookId: map['book_id'],
      chapterIndex: map['chapter_index'],
      paragraphIndex: map['paragraph_index'],
      title: map['title'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'paragraph_index': paragraphIndex,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BookmarkModel.fromEntity(Bookmark entity) {
    return BookmarkModel(
      id: entity.id,
      bookId: entity.bookId,
      chapterIndex: entity.chapterIndex,
      paragraphIndex: entity.paragraphIndex,
      title: entity.title,
      createdAt: entity.createdAt,
    );
  }
}
