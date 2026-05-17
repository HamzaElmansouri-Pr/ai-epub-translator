import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/models/parsed_book.dart';
import 'package:path/path.dart' as p;

class PdfParseException implements Exception {
  final String code;
  final String message;
  PdfParseException(this.code, this.message);
  @override
  String toString() => 'PdfParseException: [$code] $message';
}

/// Regex to detect Arabic/Hebrew characters
final _rtlRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');

Future<ParsedBook> parsePdf(String filePath, {void Function(double)? onProgress}) async {
  PdfDocument? document;
  try {
    document = await PdfDocument.openFile(filePath);
  } catch (e) {
    throw PdfParseException('corrupt_file', 'Failed to open PDF file: $e');
  }

  final pageCount = document.pages.length;
  List<ParsedParagraph> allParagraphs = [];

  for (int i = 0; i < pageCount; i++) {
    final page = document.pages[i];
    final pageText = await page.loadText();
    final textFragments = pageText.fragments;

    onProgress?.call((i + 1) / pageCount);

    // ── Image-only page detection → run OCR ──
    int totalTextLength = textFragments.fold(0, (sum, f) => sum + f.text.length);
    if (textFragments.isEmpty || (textFragments.length < 5 && totalTextLength < 20)) {
      // Render page as image and run OCR
      try {
        final ocrText = await _ocrPage(page, i);
        if (ocrText.isNotEmpty) {
          final lines = ocrText.split('\n').where((l) => l.trim().isNotEmpty).toList();
          StringBuffer currentPara = StringBuffer();
          for (int k = 0; k < lines.length; k++) {
            final line = lines[k].trim();
            // Simple paragraph break: blank-ish gaps or short lines
            bool isNewPara = false;
            if (k > 0 && lines[k - 1].trim().length < line.length * 0.4) {
              isNewPara = true;
            }
            if (isNewPara && currentPara.isNotEmpty) {
              final paraText = currentPara.toString().trim();
              allParagraphs.add(ParsedParagraph(
                index: allParagraphs.length,
                text: paraText,
                type: ParagraphType.text,
                isRTL: _rtlRegex.hasMatch(paraText),
                isOcrResult: true,
              ));
              currentPara.clear();
            }
            currentPara.write(currentPara.isEmpty ? line : ' $line');
          }
          if (currentPara.isNotEmpty) {
            final paraText = currentPara.toString().trim();
            allParagraphs.add(ParsedParagraph(
              index: allParagraphs.length,
              text: paraText,
              type: ParagraphType.text,
              isRTL: _rtlRegex.hasMatch(paraText),
              isOcrResult: true,
            ));
          }
        } else {
          allParagraphs.add(ParsedParagraph(
            index: allParagraphs.length,
            text: '[Page ${i + 1}: Scanned image — no text detected]',
            type: ParagraphType.text,
            isRTL: false,
            isOcrResult: true,
          ));
        }
      } catch (e) {
        debugPrint('OCR failed for page ${i + 1}: $e');
        allParagraphs.add(ParsedParagraph(
          index: allParagraphs.length,
          text: '[Page ${i + 1}: OCR failed — $e]',
          type: ParagraphType.text,
          isRTL: false,
          isOcrResult: true,
        ));
      }
      continue;
    }
    // ── Use fullText (pdfium's native text reconstruction) ──
    final fullText = pageText.fullText.trim();
    if (fullText.length > 20) {
      _addParagraphsFromFullText(fullText, allParagraphs);
      continue;
    }

    // ── Fallback: fragment-based reconstruction for sparse pages ──
    _addParagraphsFromFragments(textFragments, allParagraphs, page.width);
  }

  if (allParagraphs.isEmpty) {
    throw PdfParseException('empty_content', 'Zero paragraphs extracted from PDF.');
  }

  final bool isBookRTL = allParagraphs.where((p) => p.text.length > 5).any((p) => p.isRTL);

  return ParsedBook(
    title: p.basenameWithoutExtension(filePath),
    author: null,
    language: isBookRTL ? 'ar' : 'en',
    isRTL: isBookRTL,
    chapters: _structureChapters(allParagraphs),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Fragment-based extraction
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

void _addParagraphsFromFragments(
  List<PdfPageTextFragment> textFragments,
  List<ParsedParagraph> allParagraphs,
  double pageWidth,
) {
  // Sort fragments top-to-bottom, left-to-right
  List<PdfPageTextFragment> sorted = List.from(textFragments);
  sorted.sort((a, b) {
    if ((a.bounds.top - b.bounds.top).abs() < 5) {
      return a.bounds.left.compareTo(b.bounds.left);
    }
    return a.bounds.top.compareTo(b.bounds.top);
  });

  // Calculate page-level average character width
  double totalFragWidth = 0;
  int totalChars = 0;
  for (var f in sorted) {
    totalFragWidth += f.bounds.width;
    totalChars += f.text.length;
  }
  double avgCharWidth = totalChars > 0 ? totalFragWidth / totalChars : 8.0;

  // Group into lines by vertical position
  double totalHeight = sorted.fold(0.0, (sum, f) => sum + f.bounds.height);
  double avgFontSize = sorted.isNotEmpty ? totalHeight / sorted.length : 14.0;

  List<List<PdfPageTextFragment>> lines = [];
  if (sorted.isNotEmpty) {
    List<PdfPageTextFragment> currentLine = [sorted[0]];
    for (int j = 1; j < sorted.length; j++) {
      var frag = sorted[j];
      var prev = currentLine.last;
      if ((frag.bounds.top - prev.bounds.top).abs() < avgFontSize * 1.2) {
        currentLine.add(frag);
      } else {
        lines.add(currentLine);
        currentLine = [frag];
      }
    }
    lines.add(currentLine);
  }

  // Build line text with proper spacing
  List<_LineData> lineData = [];
  for (var lineFrags in lines) {
    StringBuffer lineText = StringBuffer();
    PdfRect lineBounds = lineFrags[0].bounds;
    double lineFontTotal = 0;
    for (var f in lineFrags) {
      lineBounds = lineBounds.merge(f.bounds);
      lineFontTotal += f.bounds.height;
    }
    double lineFontSize = lineFontTotal / lineFrags.length;

    bool isArabic = lineFrags.any((f) => _rtlRegex.hasMatch(f.text));

    // Sort by reading direction
    if (isArabic) {
      lineFrags.sort((a, b) => b.bounds.left.compareTo(a.bounds.left));
    } else {
      lineFrags.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    }

    if (isArabic) {
      // ----- ARABIC: Concatenate all fragments then apply linguistic repair -----
      // Fragment-based gap detection is unreliable for Arabic because non-connecting
      // letters create visual gaps indistinguishable from word spaces.
      // Instead, join all fragments with spaces and let _repairArabicText() fix it.
      for (int k = 0; k < lineFrags.length; k++) {
        if (k > 0) lineText.write(' ');
        lineText.write(lineFrags[k].text);
      }
    } else {
      // ----- ENGLISH / LATIN: Standard font-size based spacing -----
      double spaceThreshold = lineFontSize * 0.2;
      for (int k = 0; k < lineFrags.length; k++) {
        if (k > 0) {
          var prevFrag = lineFrags[k - 1];
          var frag = lineFrags[k];
          double gap = frag.bounds.left - prevFrag.bounds.right;
          if (gap < 0) gap = 0;
          if (gap > spaceThreshold) {
            lineText.write(' ');
          }
        }
        lineText.write(lineFrags[k].text);
      }
    }

    lineData.add(_LineData(
      text: lineText.toString(),
      bounds: lineBounds,
      fontSize: lineFontSize,
    ));
  }

  // Multi-column detection
  bool isTwoCol = _detectMultiColumn(lineData, pageWidth);
  List<_LineData> orderedLines = isTwoCol ? _reorderMultiColumn(lineData, pageWidth) : lineData;

  // Paragraph grouping
  double avgLineHeight = orderedLines.isEmpty
      ? 20
      : orderedLines.map((l) => l.bounds.height).reduce((a, b) => a + b) / orderedLines.length;

  StringBuffer currentPara = StringBuffer();
  for (int k = 0; k < orderedLines.length; k++) {
    var line = orderedLines[k];
    var prevLine = k > 0 ? orderedLines[k - 1] : null;

    bool isNewPara = false;
    if (prevLine != null) {
      double vGap = line.bounds.top - prevLine.bounds.bottom;
      if (vGap > avgLineHeight * 1.5) isNewPara = true;

      String prevTrimmed = prevLine.text.trim();
      if (prevTrimmed.isNotEmpty && RegExp(r'[.!?؟]$').hasMatch(prevTrimmed)) {
        if (vGap > avgLineHeight * 0.8) isNewPara = true;
      }
    }

    if (isNewPara && currentPara.isNotEmpty) {
      String paraText = currentPara.toString().trim();
      if (_rtlRegex.hasMatch(paraText)) paraText = _repairArabicText(paraText);
      allParagraphs.add(ParsedParagraph(
        index: allParagraphs.length,
        text: paraText,
        type: ParagraphType.text,
        isRTL: _rtlRegex.hasMatch(paraText),
        isOcrResult: false,
      ));
      currentPara.clear();
    }
    currentPara.write(currentPara.isEmpty ? line.text : ' ${line.text}');
  }
  if (currentPara.isNotEmpty) {
    String paraText = currentPara.toString().trim();
    if (_rtlRegex.hasMatch(paraText)) paraText = _repairArabicText(paraText);
    allParagraphs.add(ParsedParagraph(
      index: allParagraphs.length,
      text: paraText,
      type: ParagraphType.text,
      isRTL: _rtlRegex.hasMatch(paraText),
      isOcrResult: false,
    ));
  }
}

void _addParagraphsFromFullText(String fullText, List<ParsedParagraph> allParagraphs) {
  // ── fullText from pdfium already has correct Arabic word boundaries. ──
  // DO NOT apply _repairArabicText here — it corrupts the text by merging
  // words that pdfium correctly separated.
  // Only clean up excessive whitespace.
  final cleanedText = fullText.replaceAll(RegExp(r' {2,}'), ' ');
  final lines = cleanedText.split('\n').map((l) => l.trim()).toList();
  StringBuffer currentPara = StringBuffer();

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (line.isEmpty) {
      if (currentPara.isNotEmpty) {
        String paraText = currentPara.toString().trim();
        allParagraphs.add(ParsedParagraph(
          index: allParagraphs.length,
          text: paraText,
          type: ParagraphType.text,
          isRTL: _rtlRegex.hasMatch(paraText),
          isOcrResult: false,
        ));
        currentPara.clear();
      }
      continue;
    }

    if (currentPara.isNotEmpty) {
      final prevLine = lines[i - 1];
      if (RegExp(r'[.!?؟]$').hasMatch(prevLine)) {
        String paraText = currentPara.toString().trim();
        allParagraphs.add(ParsedParagraph(
          index: allParagraphs.length,
          text: paraText,
          type: ParagraphType.text,
          isRTL: _rtlRegex.hasMatch(paraText),
          isOcrResult: false,
        ));
        currentPara.clear();
      }
    }

    currentPara.write(currentPara.isEmpty ? line : ' $line');
  }

  if (currentPara.isNotEmpty) {
    String paraText = currentPara.toString().trim();
    allParagraphs.add(ParsedParagraph(
      index: allParagraphs.length,
      text: paraText,
      type: ParagraphType.text,
      isRTL: _rtlRegex.hasMatch(paraText),
      isOcrResult: false,
    ));
  }
}

/// Ultra-conservative Arabic text repair for fragment-based extraction ONLY.
/// 
/// This function ONLY merges tokens when there is very strong evidence of an
/// incorrect split. It does NOT touch text from fullText extraction.
/// 
/// The only case it handles: a single Arabic character that is clearly a torn
/// affix (not a standalone conjunction like و) appearing next to another
/// Arabic token.
String _repairArabicText(String text) {
  // Single-char Arabic tokens that are VALID standalone words/particles
  // and must NEVER be merged with adjacent words.
  const standaloneChars = <String>{
    'و', // "and" — the most common standalone single letter
    'أ', // question prefix (standalone usage)
    'ب', // "by/with" (standalone usage in some dialects)
    'ف', // "so/then" (standalone usage)
    'ل', // "to/for" (standalone usage)
  };

  // Common standalone short Arabic words (2-3 chars)
  const standaloneWords = <String>{
    'في', 'من', 'ما', 'هو', 'هي', 'لا', 'أو', 'إن', 'أن', 'عن',
    'بل', 'لم', 'لن', 'قد', 'إذ', 'أي', 'هل', 'كي', 'لو', 'مع',
    'أم', 'ثم', 'بي', 'ذو', 'ذي', 'يا', 'لي', 'بك', 'له', 'بها',
    'إذا', 'هذا', 'هذه', 'كان', 'كما', 'بين', 'حتى', 'عند', 'بعد',
    'قبل', 'مثل', 'غير', 'حول', 'منذ', 'ولا', 'فلا', 'وما', 'لها',
    'مما', 'فما', 'وهو', 'وهي', 'أما', 'إلى', 'على', 'عبر', 'ضمن',
    'دون', 'فوق', 'تحت', 'كلا', 'ولم', 'ولن', 'هنا', 'كل', 'تلك',
    'ذلك', 'التي', 'الذي', 'هؤلاء', 'أولئك',
  };

  List<String> tokens = text.split(RegExp(r' +'));
  tokens.removeWhere((t) => t.isEmpty);
  if (tokens.length <= 1) return text;

  // Single pass — only merge truly orphaned single characters
  List<String> result = [];
  int i = 0;
  while (i < tokens.length) {
    String current = tokens[i];
    bool currentIsArabic = _rtlRegex.hasMatch(current);

    // Only consider merging if current is a SINGLE Arabic character
    // that is NOT a known standalone particle
    if (currentIsArabic &&
        current.length == 1 &&
        !standaloneChars.contains(current) &&
        i + 1 < tokens.length) {
      String next = tokens[i + 1];
      bool nextIsArabic = _rtlRegex.hasMatch(next);
      if (nextIsArabic && !standaloneWords.contains(next)) {
        // Merge single orphaned char with next word
        result.add(current + next);
        i += 2;
        continue;
      }
    }

    // Check if NEXT token is a single orphaned Arabic char that should
    // attach to current word (suffix case)
    if (currentIsArabic &&
        i + 1 < tokens.length &&
        tokens[i + 1].length == 1 &&
        _rtlRegex.hasMatch(tokens[i + 1]) &&
        !standaloneChars.contains(tokens[i + 1])) {
      // Check there isn't a word after it that it belongs to instead
      bool nextBelongsToAfter = false;
      if (i + 2 < tokens.length &&
          tokens[i + 2].length <= 2 &&
          _rtlRegex.hasMatch(tokens[i + 2])) {
        nextBelongsToAfter = true;
      }
      if (!nextBelongsToAfter) {
        result.add(current + tokens[i + 1]);
        i += 2;
        continue;
      }
    }

    result.add(current);
    i++;
  }

  return result.join(' ');
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Helpers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LineData {
  final String text;
  final PdfRect bounds;
  final double fontSize;
  _LineData({required this.text, required this.bounds, required this.fontSize});
}

bool _detectMultiColumn(List<_LineData> lines, double pageWidth) {
  if (lines.length < 10) return false;
  double mid = pageWidth / 2;
  int leftCount = lines.where((l) => l.bounds.right < mid - 20).length;
  int rightCount = lines.where((l) => l.bounds.left > mid + 20).length;
  return leftCount > lines.length * 0.3 && rightCount > lines.length * 0.3;
}

List<_LineData> _reorderMultiColumn(List<_LineData> lines, double pageWidth) {
  double mid = pageWidth / 2;
  double centerX(PdfRect b) => (b.left + b.right) / 2;
  List<_LineData> left = lines.where((l) => centerX(l.bounds) < mid).toList();
  List<_LineData> right = lines.where((l) => centerX(l.bounds) >= mid).toList();
  return [...left, ...right];
}

List<ParsedChapter> _structureChapters(List<ParsedParagraph> paragraphs) {
  List<ParsedChapter> chapters = [];
  List<ParsedParagraph> currentParas = [];
  String currentTitle = 'Introduction';
  int chapterIndex = 0;

  final chapterRegex = RegExp(
    r'^(Chapter|CHAPTER|Part|PART|Section|الفصل|الباب|المقدمة)\s*[\dIVX]*',
    caseSensitive: false,
  );

  for (var para in paragraphs) {
    if (chapterRegex.hasMatch(para.text) && para.text.length < 80) {
      if (currentParas.isNotEmpty) {
        chapters.add(ParsedChapter(
          index: chapterIndex++,
          title: currentTitle,
          paragraphs: List.from(currentParas),
        ));
        currentParas.clear();
      }
      currentTitle = para.text;
    } else {
      currentParas.add(para);
    }
  }

  if (currentParas.isNotEmpty) {
    chapters.add(ParsedChapter(
      index: chapterIndex++,
      title: currentTitle,
      paragraphs: currentParas,
    ));
  }

  return chapters;
}
/// Elite hybrid OCR pipeline for scanned PDF pages.
/// Priority: Tesseract Arabic (offline) → MLKit (offline) → Gemini Flash (API fallback)
Future<String> _ocrPage(PdfPage page, int pageIndex) async {
  // 1. Render page at 3x resolution for maximum OCR accuracy
  final renderWidth = (page.width * 3).toInt();
  final renderHeight = (page.height * 3).toInt();

  final pdfImage = await page.render(
    width: renderWidth,
    height: renderHeight,
  );
  if (pdfImage == null) return '';

  // 2. Convert to PNG and save to temp file
  final image = await pdfImage.createImage();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return '';
  final pngBytes = byteData.buffer.asUint8List();

  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/ocr_page_$pageIndex.png');
  await tempFile.writeAsBytes(pngBytes);

  // 3. Multi-stage OCR Pipeline
  String bestResult = '';

  // ── STAGE 1: Tesseract Arabic (LSTM-best, offline, fast) ──
  try {
    final tesseractResult = await FlutterTesseractOcr.extractText(
      tempFile.path,
      language: 'ara',
      args: {
        "psm": "6",  // Assume a uniform block of text (better for book pages)
        "oem": "1",  // LSTM engine only (best for cursive Arabic)
      },
    );
    final cleaned = tesseractResult.trim();
    if (cleaned.length > 20 && _isArabicTextValid(cleaned)) {
      bestResult = cleaned;
      debugPrint('OCR page ${pageIndex + 1}: Tesseract Arabic succeeded (${cleaned.length} chars)');
    }
  } catch (e) {
    debugPrint('OCR page ${pageIndex + 1}: Tesseract failed: $e');
  }

  // ── STAGE 2: Tesseract with combined Arabic+English for mixed pages ──
  if (bestResult.isEmpty) {
    try {
      final tesseractMixed = await FlutterTesseractOcr.extractText(
        tempFile.path,
        language: 'ara+eng',
        args: {
          "psm": "3",  // Fully automatic page segmentation
          "oem": "1",
        },
      );
      final cleaned = tesseractMixed.trim();
      if (cleaned.length > 20 && _isTextMeaningful(cleaned)) {
        bestResult = cleaned;
        debugPrint('OCR page ${pageIndex + 1}: Tesseract mixed succeeded (${cleaned.length} chars)');
      }
    } catch (e) {
      debugPrint('OCR page ${pageIndex + 1}: Tesseract mixed failed: $e');
    }
  }

  // ── STAGE 3: Google MLKit Latin (for non-Arabic/Latin pages) ──
  if (bestResult.isEmpty) {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final result = await recognizer.processImage(inputImage);
      final mlkitText = result.text.trim();

      if (mlkitText.length > 20 && _isTextMeaningful(mlkitText)) {
        bestResult = mlkitText;
        debugPrint('OCR page ${pageIndex + 1}: MLKit Latin succeeded (${mlkitText.length} chars)');
      }
    } catch (e) {
      debugPrint('OCR page ${pageIndex + 1}: MLKit failed: $e');
    } finally {
      await recognizer.close();
    }
  }

  // ── STAGE 4: Gemini Flash API (emergency fallback — fast & cheap) ──
  if (bestResult.isEmpty) {
    int maxRetries = 3;
    int currentTry = 0;
    
    while (currentTry < maxRetries && bestResult.isEmpty) {
      try {
        final apiKey = AppConstants.defaultGeminiKey;
        if (apiKey.isNotEmpty) {
          final model = GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: apiKey,
          );
          final prompt = TextPart(
            'Extract ALL text from this scanned page image. '
            'Output the text exactly as it appears, preserving paragraphs and line breaks. '
            'If the text is Arabic, output proper Arabic with correct word spacing. '
            'Return ONLY the extracted text, no commentary.',
          );
          final imagePart = DataPart('image/png', pngBytes);

          final response = await model.generateContent([
            Content.multi([prompt, imagePart])
          ]);

          if (response.text != null && response.text!.trim().isNotEmpty) {
            bestResult = response.text!.trim();
            debugPrint('OCR page ${pageIndex + 1}: Gemini Flash succeeded (${bestResult.length} chars)');
            
            // Baseline delay to prevent bursting past the 15 Requests Per Minute limit (1 req / 4s)
            await Future.delayed(const Duration(seconds: 4));
          }
        }
        break; // Break loop if successful or no API key available
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('quota') || errorString.contains('429')) {
          currentTry++;
          if (currentTry >= maxRetries) {
            debugPrint('OCR page ${pageIndex + 1}: Gemini failed permanently after retries.');
            break;
          }
          final waitSeconds = 15 * currentTry; // Exponential backoff: 15s, 30s...
          debugPrint('OCR page ${pageIndex + 1}: Gemini Rate Limit hit. Retrying in $waitSeconds seconds... ($currentTry/$maxRetries)');
          await Future.delayed(Duration(seconds: waitSeconds));
        } else {
          debugPrint('OCR page ${pageIndex + 1}: Gemini failed: $e');
          break; // Break loop for non-quota errors
        }
      }
    }
  }

  // 4. Post-process: apply Arabic text repair if the result contains Arabic
  if (bestResult.isNotEmpty && _rtlRegex.hasMatch(bestResult)) {
    final repairedLines = bestResult.split('\n').map((line) {
      if (_rtlRegex.hasMatch(line)) return _repairArabicText(line);
      return line;
    }).toList();
    bestResult = repairedLines.join('\n');
  }

  // 5. Cleanup temp file
  try {
    await tempFile.delete();
  } catch (_) {}

  return bestResult;
}

/// Checks if OCR text is valid Arabic (not Latin gibberish).
bool _isArabicTextValid(String text) {
  if (text.isEmpty) return false;
  final arabicChars = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
  final matches = arabicChars.allMatches(text).length;
  final ratio = matches / text.replaceAll(RegExp(r'\s'), '').length;
  // Valid Arabic text should be at least 40% Arabic characters
  return ratio > 0.4;
}

/// Checks if text is meaningful (not random symbols/gibberish).
bool _isTextMeaningful(String text) {
  if (text.length < 10) return false;
  final stripped = text.replaceAll(RegExp(r'\s'), '');
  // Check letter-to-total ratio (meaningful text has mostly letters)
  final letterCount = RegExp(r'[\p{L}]', unicode: true).allMatches(stripped).length;
  if (stripped.isEmpty) return false;
  return (letterCount / stripped.length) > 0.5;
}
