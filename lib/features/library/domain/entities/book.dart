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
  final bool isPinned;
  final String? coverUrl;
  final double readingProgress;

  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    required this.addedAt,
    this.lastReadAt,
    this.status = 'reading',
    this.isFavorite = false,
    this.isPinned = false,
    this.coverUrl,
    this.readingProgress = 0.0,
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
    bool? isPinned,
    String? coverUrl,
    double? readingProgress,
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
      isPinned: isPinned ?? this.isPinned,
      coverUrl: coverUrl ?? this.coverUrl,
      readingProgress: readingProgress ?? this.readingProgress,
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
    isPinned,
    coverUrl,
    readingProgress,
  ];
}
