import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class Chapter extends Equatable {
  final int index;
  final String title;
  final List<Paragraph> paragraphs;

  const Chapter({
    required this.index,
    required this.title,
    required this.paragraphs,
  });

  @override
  List<Object?> get props => [index, title, paragraphs];
}

class Paragraph extends Equatable {
  final String id; // Hash of the text or image bytes
  final String text;
  final int index;
  final Uint8List? imageBytes;

  const Paragraph({
    required this.id,
    required this.text,
    required this.index,
    this.imageBytes,
  });

  @override
  List<Object?> get props => [id, text, index, imageBytes];
}
