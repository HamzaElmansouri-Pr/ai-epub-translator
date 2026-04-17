import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:epub_translate_meaning/core/storage/database_helper.dart';

void main() async {
  final service = ExportService(DatabaseHelper());
  final paragraphs = await service.extractAllParagraphs('books epub/Thinking, Fast and Slow.epub');
  print('Extracted  paragraphs');
}
