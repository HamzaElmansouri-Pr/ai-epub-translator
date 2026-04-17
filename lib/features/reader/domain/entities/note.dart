import 'package:equatable/equatable.dart';

class Note extends Equatable {
  final int? id;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final String selectedText;
  final String? noteText;
  final String colorMark;
  final String paragraphHash;
  final DateTime createdAt;

  const Note({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.selectedText,
    this.noteText,
    required this.colorMark,
    required this.paragraphHash,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, bookId, chapterIndex, paragraphIndex, selectedText, noteText, colorMark, paragraphHash, createdAt];
}
