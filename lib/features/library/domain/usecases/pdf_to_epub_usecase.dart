import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/pdf_converter_datasource.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/epub_assembler.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/import_book.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:file_saver/file_saver.dart';
import 'package:permission_handler/permission_handler.dart';

typedef ProgressCallback = void Function(double progress, String status);

@lazySingleton
class PdfToEpubUseCase {
  final PdfConverterDatasource _pdfConverter;
  final EpubAssembler _epubAssembler;
  final ImportBook _importBook;
  final SettingsRepository _settingsRepository;
  final ExportService _exportService;

  PdfToEpubUseCase(
    this._pdfConverter, 
    this._epubAssembler, 
    this._importBook, 
    this._settingsRepository,
    this._exportService,
  );

  Future<File> execute({
    required String pdfPath,
    required String title,
    required String author,
    int? endPage,
    void Function(double progress, String status)? onProgress,
  }) async {
    PdfDocument? document;
    try {
      debugPrint('PdfToEpubUseCase: Initializing for large file conversion: "$title"');
      
      final settingsResult = await _settingsRepository.getSettings();
      String preferredService = 'Gemini';
      String targetLang = 'en';
      settingsResult.fold((_) => null, (s) {
        preferredService = s.preferredProService;
        targetLang = s.targetLanguage.toLowerCase().contains('arabic') ? 'ar' : 'en';
      });

      onProgress?.call(0.01, 'Opening PDF document...');
      document = await PdfDocument.openFile(pdfPath);
      final pageCount = document.pagesCount;
      final int limit = endPage != null ? math.min(endPage, pageCount) : pageCount;
      
      onProgress?.call(0.1, 'Extracting text from PDF images...');
      
      List<String> extractedTexts = [];
      for (int i = 1; i <= limit; i++) {
        // Calculate progress carefully: extraction takes 50% of the total time
        final progress = 0.1 + (i / limit) * 0.4;
        onProgress?.call(progress, 'Reading page $i of $limit (AI Vision)...');

        // Render page directly from the open document to save I/O
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2.0, // High resolution for accurate AI Vision OCR
          height: page.height * 2.0,
          format: PdfPageImageFormat.jpeg,
          quality: 100,
        );
        final imageBytes = pageImage?.bytes;
        await page.close();

        if (imageBytes == null) {
          debugPrint('PdfToEpubUseCase: Warning - Page $i failed to render');
          continue;
        }

        String pageText = '';
        // Force Gemini for Arabic because ML Kit doesn't support it and Groq is text-only.
        if (targetLang == 'ar' || preferredService == 'Gemini') {
          try {
            pageText = await _pdfConverter.performGeminiVisionOcr(imageBytes);
          } catch (e) {
            debugPrint('Gemini OCR failed, falling back to ML Kit: $e');
            pageText = await _pdfConverter.performMlKitOcr(imageBytes);
          }
        } else {
          pageText = await _pdfConverter.performMlKitOcr(imageBytes);
        }
        
        extractedTexts.add(pageText);
        
        // Periodic memory cleanup hint for background service
        if (i % 20 == 0) {
          debugPrint('PdfToEpubUseCase: Progress check at page $i');
        }
      }

      await document.close();
      document = null;

      // Step 3: Text Refinement
      onProgress?.call(0.5, 'Preparing AI text refinement...');
      if (extractedTexts.isEmpty) {
        throw Exception('Extraction Error: No text was found in this PDF.');
      }

      int chunkSize = 3;
      List<String> refinedChunks = [];
      int totalChunks = (extractedTexts.length / chunkSize).ceil();

      for (int i = 0; i < extractedTexts.length; i += chunkSize) {
        int currentChunk = (i / chunkSize).floor() + 1;
        final progress = 0.5 + (currentChunk / totalChunks) * 0.25;
        onProgress?.call(progress, 'Structuring and refining part $currentChunk of $totalChunks...');

        final chunkTexts = extractedTexts.skip(i).take(chunkSize).toList();
        final rawChunk = chunkTexts.join('\n\n');
        
        if (rawChunk.trim().isEmpty) continue;

        try {
          final refined = await _pdfConverter.refineText(rawChunk);
          refinedChunks.add(refined);
        } catch (e) {
          debugPrint('PdfToEpubUseCase: Refinement failed for chunk $currentChunk: $e');
          refinedChunks.add(rawChunk); // Fallback to raw text for this chunk
        }
      }

      final refinedMarkdown = refinedChunks.join('\n\n');
      
      if (refinedMarkdown.trim().isEmpty) {
         throw Exception('Extraction Error: Failed to process any text.');
      }

      // Step 4: EPUB Assembly
      onProgress?.call(0.8, 'Building EPUB package...');
      final List<String> htmlChapters = _splitMarkdownIntoHtmlChapters(refinedMarkdown);
      
      final epubBytes = await compute(_assembleInIsolate, {
        'assembler': _epubAssembler,
        'title': title,
        'author': author,
        'chapters': htmlChapters,
        'language': targetLang,
      });

      // Step 5: Persistence & Library Integration
      onProgress?.call(0.9, 'Saving to library storage...');
      final exportPath = await _exportService.getExportDirectory();
      final outDir = Directory('$exportPath/converted');
      if (!await outDir.exists()) await outDir.create(recursive: true);
      
      final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final outFile = File('${outDir.path}/$safeTitle.epub');
      
      await outFile.writeAsBytes(epubBytes, flush: true);
      
      // Step 6: Database Import
      onProgress?.call(0.95, 'Updating library database...');
      final importResult = await _importBook.call(outFile.path);
      
      // Step 7: Public Download (Downloads Folder)
      onProgress?.call(0.98, 'Exporting to phone Downloads...');
      try {
        if (Platform.isAndroid) {
          await Permission.storage.request();
        }
        await FileSaver.instance.saveFile(
          name: safeTitle,
          bytes: epubBytes,
          fileExtension: 'epub',
          mimeType: MimeType.other,
        );
      } catch (e) {
        debugPrint('PdfToEpubUseCase: Public download error: $e');
      }

      onProgress?.call(1.0, 'Process complete!');
      return outFile;
    } catch (e) {
      await document?.close();
      debugPrint('PdfToEpubUseCase CRITICAL ERROR: $e');
      rethrow;
    }
  }

  static Future<Uint8List> _assembleInIsolate(Map<String, dynamic> args) async {
    final assembler = args['assembler'] as EpubAssembler;
    final title = args['title'] as String;
    final author = args['author'] as String;
    final chapters = args['chapters'] as List<String>;
    final language = args['language'] as String? ?? 'en';
    return await assembler.assembleEpub(
      title: title, 
      author: author, 
      chapters: chapters,
      language: language,
    );
  }

  List<String> _splitMarkdownIntoHtmlChapters(String markdown) {
    final chapters = <String>[];
    final lines = markdown.split('\n');
    var currentChapter = StringBuffer();

    for (var line in lines) {
      if (line.startsWith('# ') || line.startsWith('## ')) {
        if (currentChapter.toString().trim().isNotEmpty) {
          chapters.add(md.markdownToHtml(currentChapter.toString().trim()));
          currentChapter = StringBuffer();
        }
      }
      currentChapter.writeln(line);
    }
    
    if (currentChapter.toString().trim().isNotEmpty) {
      chapters.add(md.markdownToHtml(currentChapter.toString().trim()));
    } else if (chapters.isEmpty && markdown.trim().isNotEmpty) {
      chapters.add(md.markdownToHtml(markdown.trim()));
    }

    return chapters;
  }

  Future<bool> checkApiStatus() async {
    return await _pdfConverter.testApiConnection();
  }
}
