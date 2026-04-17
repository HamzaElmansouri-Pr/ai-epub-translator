import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';

class BookModel extends Book {
  const BookModel({
    required super.id,
    required super.title,
    super.author,
    required super.filePath,
    required super.addedAt,
    super.lastReadAt,
    super.status = 'reading',
    super.isFavorite = false,
    super.coverUrl,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      filePath: json['filePath'],
      addedAt: DateTime.parse(json['addedAt']),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'])
          : null,
      status: json['status'] ?? 'reading',
      isFavorite: json['isFavorite'] == 1 || json['isFavorite'] == true,
      coverUrl: json['coverUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'status': status,
      'isFavorite': isFavorite ? 1 : 0,
      'coverUrl': coverUrl,
    };
  }

  factory BookModel.fromEntity(Book book) {
    return BookModel(
      id: book.id,
      title: book.title,
      author: book.author,
      filePath: book.filePath,
      addedAt: book.addedAt,
      lastReadAt: book.lastReadAt,
      status: book.status,
      isFavorite: book.isFavorite,
      coverUrl: book.coverUrl,
    );
  }
}
