import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart';

abstract class GeminiDataSource {
  Future<Translation> translate(String text, String targetLanguage);
}

@LazySingleton(as: GeminiDataSource)
class GeminiDataSourceImpl implements GeminiDataSource {
  final SettingsRepository _settingsRepository;

  GeminiDataSourceImpl(this._settingsRepository);

  Future<GenerativeModel> _getModel() async {
    final settingsResult = await _settingsRepository.getSettings();
    String apiKey = AppConstants.defaultGeminiKey;
    
    settingsResult.fold(
      (failure) => null,
      (settings) {
        if (settings.customGeminiKey != null && settings.customGeminiKey!.isNotEmpty) {
          apiKey = settings.customGeminiKey!;
        }
      },
    );

    return GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: apiKey,
    );
  }

  @override
  Future<Translation> translate(String text, String targetLanguage) async {
    final model = await _getModel();
    final systemPrompt =
        """
You are a professional literary translator. Translate the following paragraph into $targetLanguage. Maintain the soul and emotional tone of the text, use natural linguistic flow, and strictly avoid literal translation. Return the result in a JSON format: {"original": "...", "translation": "..."}.
""";

    final content = [
      Content.text("$systemPrompt\n\nParagraph to translate:\n$text"),
    ];
    final response = await model.generateContent(content);

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
