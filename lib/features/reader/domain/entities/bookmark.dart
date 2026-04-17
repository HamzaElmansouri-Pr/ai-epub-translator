import 'package:equatable/equatable.dart';

class Bookmark extends Equatable {
  final int? id;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final String? title;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    this.title,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, bookId, chapterIndex, paragraphIndex, title, createdAt];
}
