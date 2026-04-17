import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/features/settings/data/datasources/settings_local_datasource.dart';

class VisualContentService {
  final SettingsLocalDataSource settingsDataSource;

  VisualContentService(this.settingsDataSource);

  Future<String> describeImage(Uint8List imageBytes) async {
    final settings = await settingsDataSource.getSettings();
    final targetLang = settings.targetLanguage;

    final model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: settings.customGeminiKey ?? AppConstants.defaultGeminiKey,
    );

    final prompt =
        "Describe this book illustration in 2 sentences for a visually impaired reader in $targetLang.";

    // Provide the image bytes as a DataPart alongside the text prompt
    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes), // Assuming jpeg/png handling
      ]),
    ];

    try {
      final response = await model.generateContent(content);
      return response.text ?? "Image description unavailable.";
    } catch (e) {
      return "Unable to describe image: ${e.toString()}";
    }
  }
}
