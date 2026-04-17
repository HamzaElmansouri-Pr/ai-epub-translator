import 'package:equatable/equatable.dart';

class Book extends Equatable {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final String status; // 'want_to_read', 'reading', 'finished'
  final bool isFavorite;
  final String? coverUrl;

  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    required this.addedAt,
    this.lastReadAt,
    this.status = 'reading',
    this.isFavorite = false,
    this.coverUrl,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    DateTime? addedAt,
    DateTime? lastReadAt,
    String? status,
    bool? isFavorite,
    String? coverUrl,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    filePath,
    addedAt,
    lastReadAt,
    status,
    isFavorite,
    coverUrl,
  ];
}
