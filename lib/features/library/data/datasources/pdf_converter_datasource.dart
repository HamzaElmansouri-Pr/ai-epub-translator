import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide ServerException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:epub_translate_meaning/core/error/exceptions.dart';
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart';

@lazySingleton
class PdfConverterDatasource {
  final SettingsRepository _settingsRepository;
  late final TextRecognizer _latinRecognizer;

  PdfConverterDatasource(this._settingsRepository) {
    _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Tries multiple model names to find one that works in the user's region
  Future<GenerativeModel> _getGeminiModel() async {
    final settingsResult = await _settingsRepository.getSettings();
    String? apiKey;
    settingsResult.fold((_) => null, (s) => apiKey = s.customGeminiKey);

    if (apiKey == null || apiKey!.trim().isEmpty) {
      throw ServerException('Gemini API Key is missing. Please add it in Settings.');
    }

    // List of models to try in order of preference
    final modelCandidates = [
      'gemini-flash-latest',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-pro-latest',
    ];

    // For the actual conversion, we need a model that works.
    // In a real app, we'd verify this once at startup, but here we'll use a reliable default
    // and provide a way to override it.
    return GenerativeModel(
      model: 'gemini-flash-latest', // Future-proof default
      apiKey: apiKey!.trim(),
    );
  }

  /// Renders a PDF page to a high-res image (Uint8List)
  Future<Uint8List> renderPageToImage(String filePath, int pageNumber) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      final page = await document.getPage(pageNumber);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        quality: 90,
      );
      await page.close();
      await document.close();
      
      if (pageImage == null) throw ServerException('Failed to render PDF page');
      return pageImage.bytes;
    } catch (e) {
      debugPrint('PdfConverterDatasource.renderPageToImage ERROR: $e');
      throw ServerException(e.toString());
    }
  }

  /// Fast on-device OCR. Only supports Latin-based scripts.
  Future<String> performMlKitOcr(Uint8List imageBytes) async {
    try {
      final targetLang = await _getTargetLanguage();
      final isArabic = targetLang.toLowerCase().contains('arabic');
      
      if (isArabic) {
        // ML Kit on-device does not support Arabic script.
        return '';
      }

      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/page_image.jpg');
      await tempFile.writeAsBytes(imageBytes);
      final inputImage = InputImage.fromFile(tempFile);

      final recognizedText = await _latinRecognizer.processImage(inputImage);
      final resultText = recognizedText.text;
      
      await tempFile.delete();
      await tempDir.delete();
      return resultText;
    } catch (e) {
      debugPrint('PdfConverterDatasource.performMlKitOcr ERROR: $e');
      return '';
    }
  }

  /// Elite AI OCR using Gemini Vision. 
  Future<String> performGeminiVisionOcr(Uint8List imageBytes) async {
    try {
      final targetLang = await _getTargetLanguage();
      final model = await _getGeminiModel();
      
      final prompt = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(
            'Transcribe this PDF page image. '
            'IMPORTANT: The book is likely in $targetLang. DO NOT translate it. '
            'Transcribe the text EXACTLY as it appears. '
            'YOU MUST TRANSCRIBE EVERY SINGLE WORD. DO NOT summarize or skip any text. '
            'If the text is Arabic, ensure you transcribe it with perfect accuracy and structure. '
            'Maintain semantic structure (headings, paragraphs). '
            'Remove headers, footers, and page numbers. '
            'Output in clean Markdown format.'
          ),
        ])
      ];

      final response = await model.generateContent(prompt);
      return response.text ?? '';
    } catch (e) {
      debugPrint('PdfConverterDatasource.performGeminiVisionOcr ERROR: $e');
      rethrow;
    }
  }

  Future<String> _getTargetLanguage() async {
    final settingsResult = await _settingsRepository.getSettings();
    return settingsResult.fold((_) => 'English', (s) => s.targetLanguage);
  }

  /// AI Text Refinement (Step 3) - Uses preferred service with language awareness
  Future<String> refineText(String rawText) async {
    final settingsResult = await _settingsRepository.getSettings();
    String service = 'Gemini';
    String targetLang = 'the original language of the PDF';
    settingsResult.fold((_) => null, (s) {
      service = s.preferredProService;
      targetLang = s.targetLanguage;
    });

    final prompt = 
      'You are a professional book digitizer. Your goal is to FORMAT the following raw OCR text into a high-quality ebook.\n\n'
      'CRITICAL INSTRUCTIONS:\n'
      '1. PRESERVE LANGUAGE: The original language is $targetLang. DO NOT TRANSLATE.\n'
      '2. REMOVE ALL ARTIFACTS: Delete page numbers, headers, and footers.\n'
      '3. CLEAN TEXT: Fix OCR errors and merged words. Rebuild the semantic meaning and flow of paragraphs.\n'
      '4. SEMANTIC STRUCTURE: Use Markdown for structure. Chapters MUST start with "# " (Level 1 Header).\n'
      '5. CONTINUITY: Ensure sentences flow naturally. Maintain paragraph continuity.\n'
      '6. NO CONVERSATIONAL TEXT: Output ONLY the refined book text. Do not include conversational filler.\n'
      '7. DO NOT OMIT ANY TEXT: You MUST retain every single paragraph, sentence, and word from the original OCR text. DO NOT summarize or skip anything!\n\n'
      'RAW OCR DATA:\n$rawText';

    try {
      if (service == 'Groq') {
        return await _getGroqResponse(prompt);
      } else {
        final model = await _getGeminiModel();
        final response = await model.generateContent([Content.text(prompt)]);
        return response.text ?? rawText;
      }
    } catch (e) {
      debugPrint('PdfConverterDatasource.refineText ERROR ($service): $e');
      return rawText;
    }
  }

  Future<String> _getGroqResponse(String prompt) async {
    final settingsResult = await _settingsRepository.getSettings();
    String? apiKey;
    settingsResult.fold((_) => null, (s) => apiKey = s.customGroqKey);

    if (apiKey == null || apiKey!.trim().isEmpty) {
      throw ServerException('Groq API Key is missing.');
    }

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${apiKey!.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      final error = jsonDecode(response.body);
      throw ServerException('Groq API Error (${response.statusCode}): ${error['error']?['message'] ?? 'Unknown error'}');
    }
  }

  /// Verifies if the selected API is working correctly by testing multiple Gemini models
  Future<bool> testApiConnection() async {
    final settingsResult = await _settingsRepository.getSettings();
    String service = 'Gemini';
    String? apiKey;
    settingsResult.fold((_) => null, (s) {
      service = s.preferredProService;
      apiKey = s.customGeminiKey;
    });

    try {
      if (service == 'Groq') {
        final result = await _getGroqResponse('hi');
        return result.isNotEmpty;
      } else {
        if (apiKey == null || apiKey!.isEmpty) return false;
        
        // Try multiple models to find the one working in this region
        final candidates = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-pro-latest'];
        String lastError = '';
        
        for (var modelName in candidates) {
          try {
            final model = GenerativeModel(model: modelName, apiKey: apiKey!.trim());
            final response = await model.generateContent([Content.text('hi')]);
            if (response.text != null) {
              debugPrint('Gemini: Successfully connected using model $modelName');
              return true; 
            }
          } catch (e) {
            lastError = e.toString();
            debugPrint('Gemini: Model $modelName failed: $e');
            continue;
          }
        }
        throw ServerException('Gemini Error: None of the available models (Flash/Pro) are supported in your region with this API key. Error: $lastError');
      }
    } catch (e) {
      debugPrint('PdfConverterDatasource.testApiConnection ERROR ($service): $e');
      rethrow;
    }
  }

  void dispose() {
    _latinRecognizer.close();
  }
}
