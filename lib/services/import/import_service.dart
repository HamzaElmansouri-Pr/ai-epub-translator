import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:epub_translate_meaning/services/parsers/pdf_parser.dart';
import 'package:epub_translate_meaning/services/database/database_service.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';


class ImportService {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  // Overlay-based progress indicator — NO Navigator interaction at all
  OverlayEntry? _progressOverlay;

  Future<void> importPdf(BuildContext context, {required Function(Book) onComplete}) async {
    // 1. Pick File
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );

    if (result == null || result.files.single.path == null) return;
    final sourcePath = result.files.single.path!;

    // 2. Prepare destination
    final originalFileName = result.files.single.name;
    final displayTitle = originalFileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final dir = await getApplicationDocumentsDirectory();
    final bookId = _uuid.v4();
    final booksDir = Directory('${dir.path}/books');
    if (!await booksDir.exists()) await booksDir.create(recursive: true);
    
    final destPath = '${booksDir.path}/$bookId.pdf';
    await File(sourcePath).copy(destPath);

    // 3. Show Progress Overlay (NOT a dialog — zero Navigator interaction)
    final progressController = StreamController<double>();
    _showProgressOverlay(context, progressController.stream);

    try {
      // 4. Extract Cover (Page 1)
      final coverPath = await _extractCover(destPath, bookId, dir.path);

      // 5. Parse PDF
      final parsedBook = await parsePdf(destPath, onProgress: (p) {
        progressController.add(p * 0.8); // First 80% for parsing
      });

      // 6. Save to Database
      final book = Book(
        id: bookId,
        title: displayTitle,
        author: parsedBook.author,
        filePath: destPath,
        coverUrl: coverPath,
        addedAt: DateTime.now(),
        status: 'reading',
      );

      await _db.insertBook(book);
      
      // Save Chapters and Paragraphs
      int chapterCount = parsedBook.chapters.length;
      for (int i = 0; i < chapterCount; i++) {
        final chapter = parsedBook.chapters[i];
        final chapterId = '${bookId}_$i';
        await _db.insertChapters([chapter], bookId);
        await _db.insertParagraphs(chapter.paragraphs, chapterId, bookId);
        progressController.add(0.8 + (0.2 * (i + 1) / chapterCount)); // Last 20% for DB
      }

      // 7. Complete — dismiss overlay and navigate
      _dismissProgressOverlay();
      if (context.mounted) {
        onComplete(book);
      }

    } on PdfParseException catch (e, stack) {
      debugPrint('PdfParseException during import: $e\n$stack');
      _dismissProgressOverlay();
      if (context.mounted) {
        _showError(context, e.message);
      }
    } catch (e, stack) {
      debugPrint('Exception during import: $e\n$stack');
      _dismissProgressOverlay();
      if (context.mounted) {
        _showError(context, 'Import failed: $e');
      }
    } finally {
      progressController.close();
    }
  }

  Future<String?> _extractCover(String pdfPath, String bookId, String appPath) async {
    try {
      final document = await PdfDocument.openFile(pdfPath);
      final page = document.pages[0];
      final renderWidth = 300;
      final renderHeight = (page.height / page.width * renderWidth).toInt();
      final pageImage = await page.render(width: renderWidth, height: renderHeight);
      if (pageImage == null) return null;
      
      final image = await pageImage.createImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return null;

      final coversDir = Directory('$appPath/covers');
      if (!await coversDir.exists()) await coversDir.create(recursive: true);
      
      final coverPath = '${coversDir.path}/$bookId.png';
      await File(coverPath).writeAsBytes(byteData.buffer.asUint8List());
      
      return coverPath;
    } catch (e) {
      debugPrint('Cover extraction failed: $e');
      return null;
    }
  }

  /// Shows a progress overlay using OverlayEntry — completely bypasses Navigator/GoRouter.
  /// This can never cause _debugLocked or "popped last page" errors.
  void _showProgressOverlay(BuildContext context, Stream<double> progressStream) {
    _dismissProgressOverlay(); // Safety: remove any existing overlay first

    _progressOverlay = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.black54,
        child: Center(
          child: StreamBuilder<double>(
            stream: progressStream,
            initialData: 0.0,
            builder: (context, snapshot) {
              final progress = snapshot.data ?? 0.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Importing PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Parsing content and layout...',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_progressOverlay!);
  }

  /// Instantly removes the progress overlay — no Navigator involved.
  void _dismissProgressOverlay() {
    _progressOverlay?.remove();
    _progressOverlay = null;
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        action: SnackBarAction(label: 'RETRY', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }
}
