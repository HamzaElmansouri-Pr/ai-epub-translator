import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/storage/database_helper.dart';
import 'package:epub_translate_meaning/core/utils/hash_utils.dart';
import 'dart:convert';

@lazySingleton
class ExportService {
  final DatabaseHelper dbHelper;

  ExportService(this.dbHelper);

  Future<List<String>> extractAllParagraphs(String originalFilePath) async {
    return await compute(_extractAllParagraphsInIsolate, originalFilePath);
  }

  static Future<List<String>> _extractAllParagraphsInIsolate(
    String originalFilePath,
  ) async {
    final bytes = await File(originalFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<String> allParagraphs = [];

    for (final file in archive) {
      if (file.isFile &&
          (file.name.endsWith('.html') || file.name.endsWith('.xhtml'))) {
        try {
          String content = utf8.decode(file.content as List<int>);
          final document = html_parser.parse(content);
          final paragraphs = document.querySelectorAll('p, div');

          for (final p in paragraphs) {
            final text = p.text.trim();
            if (text.isNotEmpty) {
              allParagraphs.add(text);
            }
          }
        } catch (e) {
          // ignore parsing errors for individual files
        }
      }
    }
    return allParagraphs.toSet().toList(); // Unique paragraphs
  }

  Future<String> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }

  Future<File> generateBilingualMarkdown(
    String bookId,
    String bookTitle,
    String originalFilePath,
  ) async {
    final db = await dbHelper.database;
    final translationsMaps = await db.query(
      'translations',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    
    return await compute(_generateMarkdownInIsolate, {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'originalFilePath': originalFilePath,
      'translationsMaps': translationsMaps,
      'outPath': await getExportDirectory(),
    });
  }

  static Future<File> _generateMarkdownInIsolate(Map<String, dynamic> params) async {
    final bookTitle = params['bookTitle'] as String;
    final translationsMaps = params['translationsMaps'] as List<Map<String, Object?>>;
    final outPath = params['outPath'] as String;
    
    final safeBookTitle = bookTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final file = File('$outPath/${safeBookTitle}_bilingual.md');
    
    final buffer = StringBuffer();
    buffer.writeln('# $bookTitle');
    buffer.writeln('## Bilingual Export\n');
    
    if (translationsMaps.isEmpty) {
      buffer.writeln('*No translated paragraphs found in database.*');
    } else {
      for (var m in translationsMaps) {
        final orig = m['original_text'] as String;
        final trans = m['translated_text'] as String;
        
        buffer.writeln('*$orig*');
        buffer.writeln('');
        buffer.writeln('**$trans**');
        buffer.writeln('');
        buffer.writeln('---');
        buffer.writeln('');
      }
    }
    
    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<File> generateBilingualPdf(
    String bookId,
    String bookTitle,
    String originalFilePath,
  ) async {
    final db = await dbHelper.database;
    final translationsMaps = await db.query(
      'translations',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return await compute(_generatePdfInIsolate, {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'originalFilePath': originalFilePath,
      'translationsMaps': translationsMaps,
      'outPath': await getExportDirectory(),
    });
  }

  Future<File> generateBilingualEpub(
    String bookId,
    String bookTitle,
    String originalFilePath,
  ) async {
    final db = await dbHelper.database;
    final translationsMaps = await db.query(
      'translations',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return await compute(_generateEpubInIsolate, {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'originalFilePath': originalFilePath,
      'translationsMaps': translationsMaps,
      'outPath': await getExportDirectory(),
    });
  }

  static Future<File> _generatePdfInIsolate(Map<String, dynamic> params) async {
    final bookTitle = params['bookTitle'] as String;
    final bookId = params['bookId'] as String;
    final translationsMaps =
        params['translationsMaps'] as List<Map<String, Object?>>;
    final outPath = params['outPath'] as String;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          List<pw.Widget> widgets = [
            pw.Header(
              level: 0,
              child: pw.Text(
                bookTitle,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
          ];

          if (translationsMaps.isEmpty) {
            widgets.add(pw.Text('No translated paragraphs found in database.'));
            return widgets;
          }

          for (var m in translationsMaps) {
            final orig = m['original_text'] as String;
            final trans = m['translated_text'] as String;

            widgets.add(
              pw.Text(
                orig,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 5));
            widgets.add(
              pw.Text(
                trans,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 15));
          }

          return widgets;
        },
      ),
    );

    final safeBookTitle = bookTitle
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();
    final file = File('$outPath/${safeBookTitle}_bilingual.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> _generateEpubInIsolate(
    Map<String, dynamic> params,
  ) async {
    final originalFilePath = params['originalFilePath'] as String;
    final bookTitle = params['bookTitle'] as String;
    final bookId = params['bookId'] as String;
    final translationsMaps =
        params['translationsMaps'] as List<Map<String, Object?>>;
    final outPath = params['outPath'] as String;

    final bytes = await File(originalFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // We cannot directly alter file.content as it is read-only byte data in archive package.
    // Instead we create a new archive and selectively copy/replace files.
    final newArchive = Archive();

    for (final file in archive) {
      if (file.isFile &&
          (file.name.endsWith('.html') || file.name.endsWith('.xhtml'))) {
        try {
          String content = utf8.decode(file.content as List<int>);
          final document = html_parser.parse(content);
          final paragraphs = document.querySelectorAll('p, div');

          for (final p in paragraphs) {
            final text = p.text.trim();
            if (text.isNotEmpty) {
              final pHash = HashUtils.hashText(text);
              final transMaps = translationsMaps.where(
                (m) => (m['paragraph_hash'] as String) == pHash,
              );
              if (transMaps.isNotEmpty) {
                final translatedText =
                    transMaps.first['translated_text'] as String;
                final newP = html_dom.Element.tag('p');
                newP.text = translatedText;
                newP.attributes['style'] =
                    'color: #3b82f6; font-weight: bold; margin-top: 5px; margin-bottom: 15px;';

                if (p.parentNode != null) {
                  final index = p.parentNode!.nodes.indexOf(p);
                  p.parentNode!.nodes.insert(index + 1, newP);
                }
              }
            }
          }
          final newBytes = utf8.encode(document.outerHtml);
          final newFile = ArchiveFile(file.name, newBytes.length, newBytes);
          newArchive.addFile(newFile);
        } catch (e) {
          newArchive.addFile(file);
        }
      } else {
        newArchive.addFile(file);
      }
    }

    final safeBookTitle = bookTitle
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();
    final file = File('$outPath/${safeBookTitle}_bilingual.epub');
    final encoder = ZipEncoder();
    final newBytes = encoder.encode(newArchive);
    await file.writeAsBytes(newBytes!);
    return file;
  }
}
