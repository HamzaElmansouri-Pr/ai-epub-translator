import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';

class NoteModel extends Note {
  const NoteModel({
    super.id,
    required super.bookId,
    required super.chapterIndex,
    required super.paragraphIndex,
    required super.selectedText,
    super.noteText,
    required super.colorMark,
    required super.paragraphHash,
    required super.createdAt,
  });

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'],
      bookId: map['book_id'],
      chapterIndex: map['chapter_index'],
      paragraphIndex: map['paragraph_index'],
      selectedText: map['selected_text'],
      noteText: map['note_text'],
      colorMark: map['color_mark'],
      paragraphHash: map['paragraph_hash'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'paragraph_index': paragraphIndex,
      'selected_text': selectedText,
      'note_text': noteText,
      'color_mark': colorMark,
      'paragraph_hash': paragraphHash,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NoteModel.fromEntity(Note entity) {
    return NoteModel(
      id: entity.id,
      bookId: entity.bookId,
      chapterIndex: entity.chapterIndex,
      paragraphIndex: entity.paragraphIndex,
      selectedText: entity.selectedText,
      noteText: entity.noteText,
      colorMark: entity.colorMark,
      paragraphHash: entity.paragraphHash,
      createdAt: entity.createdAt,
    );
  }
}
