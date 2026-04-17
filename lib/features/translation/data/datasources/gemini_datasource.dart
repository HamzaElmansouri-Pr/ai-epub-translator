import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';

abstract class GeminiDataSource {
  Future<Translation> translate(String text, String targetLanguage);
}

@LazySingleton(as: GeminiDataSource)
class GeminiDataSourceImpl implements GeminiDataSource {
  late final GenerativeModel _model;

  GeminiDataSourceImpl() {
    _model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: AppConstants.defaultGeminiKey,
    );
  }

  @override
  Future<Translation> translate(String text, String targetLanguage) async {
    final systemPrompt =
        """
You are a professional literary translator. Translate the following paragraph into $targetLanguage. Maintain the soul and emotional tone of the text, use natural linguistic flow, and strictly avoid literal translation. Return the result in a JSON format: {"original": "...", "translation": "..."}.
""";

    final content = [
      Content.text("$systemPrompt\n\nParagraph to translate:\n$text"),
    ];
    final response = await _model.generateContent(content);

    final responseText = response.text;
    if (responseText == null) throw Exception('Empty response from Gemini');

    // Extract JSON from response (Gemini sometimes wraps in markdown code blocks)
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(responseText);
    if (jsonMatch == null) throw Exception('No JSON found in response');

    final Map<String, dynamic> data = json.decode(jsonMatch);
    return Translation(
      original: data['original'] ?? text,
      translation: data['translation'] ?? '',
    );
  }
}
