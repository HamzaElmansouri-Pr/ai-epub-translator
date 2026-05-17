import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:epub_translate_meaning/core/storage/database_helper.dart';
import 'package:epub_translate_meaning/core/utils/hash_utils.dart';

@lazySingleton
class ExportService {
  final DatabaseHelper dbHelper;

  ExportService(this.dbHelper);

  Future<String> getExportDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir.path;
  }

  Future<List<String>> extractAllParagraphs(String filePath) async {
    return await compute(_extractAllParagraphsInIsolate, filePath);
  }

  static Future<List<String>> _extractAllParagraphsInIsolate(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<String> paragraphs = [];

    for (final file in archive) {
      if (file.isFile && (file.name.endsWith('.html') || file.name.endsWith('.xhtml'))) {
        // SKIP nav and toc files for extraction as well to be consistent
        final lowerName = file.name.toLowerCase();
        if (lowerName.contains('nav.') || lowerName.contains('toc.')) continue;

        try {
          final content = _safeDecode(file.content as List<int>);
          final document = html_parser.parse(content);
          final elements = document.querySelectorAll('p, div, h1, h2, h3, h4, h5, h6, li');
          for (var element in elements) {
            final text = element.text.trim();
            if (text.isNotEmpty && text.length > 5) {
              paragraphs.add(text);
            }
          }
        } catch (e) {
          debugPrint('ExportService extract ERROR: ${file.name}: $e');
        }
      }
    }
    return paragraphs;
  }

  Future<File> generateMarkdown(
    String bookId,
    String bookTitle,
    String originalFilePath, {
    required String targetLanguage,
    bool isBilingual = true,
  }) async {
    final db = await dbHelper.database;
    final langCode = _getLangCode(targetLanguage);
    final langPair = 'auto_$langCode'.toLowerCase();
    
    final translationsMaps = await db.query(
      'translations',
      where: 'book_id = ? AND language_pair = ?',
      whereArgs: [bookId, langPair],
    );

    final outPath = await getExportDirectory();
    return await compute(_generateMarkdownInIsolate, {
      'bookTitle': bookTitle,
      'translationsMaps': translationsMaps,
      'outPath': outPath,
      'isBilingual': isBilingual,
    });
  }

  static Future<File> _generateMarkdownInIsolate(Map<String, dynamic> params) async {
    final bookTitle = params['bookTitle'] as String;
    final translationsMaps = params['translationsMaps'] as List<Map<String, Object?>>;
    final outPath = params['outPath'] as String;
    final bool isBilingual = params['isBilingual'] ?? true;

    final safeBookTitle = bookTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final suffix = isBilingual ? '_bilingual' : '_translated';
    final file = File('$outPath/$safeBookTitle$suffix.md');

    final buffer = StringBuffer();
    buffer.writeln('# $bookTitle');
    buffer.writeln('## ${isBilingual ? "Bilingual Edition" : "Translated Edition"}');
    buffer.writeln('');

    if (translationsMaps.isEmpty) {
      buffer.writeln('No translated paragraphs found in database.');
    } else {
      for (var m in translationsMaps) {
        final orig = m['original_text'] as String;
        final trans = m['translated_text'] as String;

        if (isBilingual) {
          buffer.writeln(orig);
          buffer.writeln('');
        }
        buffer.writeln('**$trans**');
        buffer.writeln('');
        buffer.writeln('---');
        buffer.writeln('');
      }
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<File> generatePdf(
    String bookId,
    String bookTitle,
    String originalFilePath, {
    required String targetLanguage,
    bool isBilingual = true,
  }) async {
    final db = await dbHelper.database;
    final langCode = _getLangCode(targetLanguage);
    final langPair = 'auto_$langCode'.toLowerCase();

    final translationsMaps = await db.query(
      'translations',
      where: 'book_id = ? AND language_pair = ?',
      whereArgs: [bookId, langPair],
    );
    return await compute(_generatePdfInIsolate, {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'originalFilePath': originalFilePath,
      'translationsMaps': translationsMaps,
      'outPath': await getExportDirectory(),
      'isBilingual': isBilingual,
    });
  }

  Future<File> generateEpub(
    String bookId,
    String bookTitle,
    String originalFilePath, {
    required String targetLanguage,
    bool isBilingual = true,
  }) async {
    final db = await dbHelper.database;
    final langCode = _getLangCode(targetLanguage);
    final langPair = 'auto_$langCode'.toLowerCase();

    final translationsMaps = await db.query(
      'translations',
      where: 'book_id = ? AND language_pair = ?',
      whereArgs: [bookId, langPair],
    );
    return await compute(_generateEpubInIsolate, {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'originalFilePath': originalFilePath,
      'translationsMaps': translationsMaps,
      'outPath': await getExportDirectory(),
      'isBilingual': isBilingual,
    });
  }

  String _getLangCode(String targetLang) {
    final lower = targetLang.toLowerCase();
    if (lower.length == 2) return lower;
    if (lower.contains('arabic')) return 'ar';
    if (lower.contains('spanish')) return 'es';
    if (lower.contains('french')) return 'fr';
    if (lower.contains('german')) return 'de';
    if (lower.contains('chinese')) return 'zh-cn';
    if (lower.contains('japanese')) return 'ja';
    if (lower.contains('russian')) return 'ru';
    if (lower.contains('portuguese')) return 'pt';
    if (lower.contains('italian')) return 'it';
    if (lower.contains('korean')) return 'ko';
    if (lower.contains('hindi')) return 'hi';
    if (lower.contains('turkish')) return 'tr';
    if (lower.contains('dutch')) return 'nl';
    return 'en';
  }

  static Future<File> _generatePdfInIsolate(Map<String, dynamic> params) async {
    final bookTitle = params['bookTitle'] as String;
    final translationsMaps = params['translationsMaps'] as List<Map<String, Object?>>;
    final outPath = params['outPath'] as String;
    final bool isBilingual = params['isBilingual'] ?? true;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          List<pw.Widget> widgets = [
            pw.Header(
              level: 0,
              child: pw.Text(bookTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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

            if (isBilingual) {
              widgets.add(pw.Text(orig, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)));
              widgets.add(pw.SizedBox(height: 5));
            }
            widgets.add(pw.Text(trans, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 15));
          }
          return widgets;
        },
      ),
    );

    final safeBookTitle = bookTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final suffix = isBilingual ? '_bilingual' : '_translated';
    final file = File('$outPath/$safeBookTitle$suffix.pdf');
    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  static Future<File> _generateEpubInIsolate(Map<String, dynamic> params) async {
    final originalFilePath = params['originalFilePath'] as String;
    final bookTitle = params['bookTitle'] as String;
    final translationsMaps = params['translationsMaps'] as List<Map<String, Object?>>;
    final outPath = params['outPath'] as String;
    final bool isBilingual = params['isBilingual'] ?? true;

    final bytes = await File(originalFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final newArchive = Archive();

    final mimetypeBytes = utf8.encode('application/epub+zip');
    newArchive.addFile(ArchiveFile('mimetype', mimetypeBytes.length, mimetypeBytes)..compress = false);

    for (final file in archive) {
      if (file.name == 'mimetype') continue;
      if (file.isFile && (file.name.endsWith('.html') || file.name.endsWith('.xhtml'))) {
        final lowerName = file.name.toLowerCase();
        if (lowerName.contains('nav.') || lowerName.contains('toc.') || lowerName.contains('index.')) {
           newArchive.addFile(file);
           continue; 
        }

        try {
          String content = _safeDecode(file.content as List<int>);
          final document = html_parser.parse(content);
          int matchCount = 0;
          
          void processElement(html_dom.Element element) {
            final tagRegex = RegExp(r'^(p|div|h1|h2|h3|h4|h5|h6|li|blockquote|caption|td)$');
            if (tagRegex.hasMatch(element.localName ?? '')) {
              final hasBlockChild = element.children.any((c) => tagRegex.hasMatch(c.localName ?? ''));
              if (!hasBlockChild) {
                final text = element.text.trim();
                if (text.isNotEmpty) {
                  final pHash = HashUtils.hashText(text);
                  var matchingTrans = translationsMaps.where((m) => (m['paragraph_hash'] as String) == pHash).toList();
                  
                  if (matchingTrans.isEmpty) {
                    final normalizedCurrent = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                    matchingTrans = translationsMaps.where((m) {
                      final dbOriginal = (m['original_text'] as String? ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                      return dbOriginal == normalizedCurrent;
                    }).toList();
                  }

                  if (matchingTrans.isNotEmpty) {
                    matchCount++;
                    final translatedText = matchingTrans.first['translated_text'] as String;

                    if (isBilingual) {
                      final newP = html_dom.Element.tag('p');
                      newP.text = translatedText;
                      newP.attributes['style'] = 'color: #3b82f6; font-weight: bold; margin-top: 5px; margin-bottom: 15px;';
                      if (element.parentNode != null) {
                        final index = element.parentNode!.nodes.indexOf(element);
                        element.parentNode!.nodes.insert(index + 1, newP);
                      }
                    } else {
                      element.text = translatedText;
                    }
                  }
                }
              }
            }
            for (var child in element.children) {
              processElement(child);
            }
          }

          if (document.body != null) {
            for (var child in document.body!.children) {
              processElement(child);
            }
          }

          final xhtmlContent = _serializeToXhtml(document);
          final newBytes = utf8.encode(xhtmlContent);
          newArchive.addFile(ArchiveFile(file.name, newBytes.length, newBytes));
        } catch (e) {
          newArchive.addFile(file);
        }
      } else {
        newArchive.addFile(file);
      }
    }

    final safeBookTitle = bookTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final suffix = isBilingual ? '_bilingual' : '_translated';
    final file = File('$outPath/$safeBookTitle$suffix.epub');
    final encoder = ZipEncoder();
    final newBytes = encoder.encode(newArchive);
    if (newBytes != null) await file.writeAsBytes(newBytes);
    return file;
  }

  static String _safeDecode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (e) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  static String _serializeToXhtml(html_dom.Document document) {
    final html = document.querySelector('html');
    if (html != null && !html.attributes.containsKey('xmlns')) {
      html.attributes['xmlns'] = 'http://www.w3.org/1999/xhtml';
    }
    String htmlString = document.outerHtml;
    final voidTags = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'];

    for (final tag in voidTags) {
      final regex = RegExp('<$tag([^>]*?)(?<!\\/)>', caseSensitive: false);
      htmlString = htmlString.replaceAllMapped(regex, (match) {
        final attrs = match.group(1);
        return '<$tag$attrs />';
      });
    }
    if (!htmlString.startsWith('<?xml')) {
      return '<?xml version="1.0" encoding="utf-8"?>\n$htmlString';
    }
    return htmlString;
  }
}
