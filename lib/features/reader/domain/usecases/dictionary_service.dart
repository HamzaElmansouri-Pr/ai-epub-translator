import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/core/storage/database_helper.dart';
import 'package:epub_translate_meaning/features/settings/data/datasources/settings_local_datasource.dart';

class SmartDictionaryService {
  final DatabaseHelper dbHelper;
  final SettingsLocalDataSource settingsDataSource;

  SmartDictionaryService(this.dbHelper, this.settingsDataSource);

  Future<Map<String, String>> analyzeWord(String word, String paragraph) async {
    final settings = await settingsDataSource.getSettings();
    final targetLang = settings.targetLanguage;

    final model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: settings.customGeminiKey ?? AppConstants.defaultGeminiKey,
    );

    final prompt =
        """
Analyze the word '$word' within this context: '$paragraph'. Provide: 
1. A short contextual meaning in $targetLang. 
2. A usage example. 
3. Phonetic pronunciation.
Return result as JSON: {"meaning": "...", "example": "...", "phonetic": "..."}
""";

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text;
    if (responseText == null) throw Exception('Empty response');

    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(responseText);
    if (jsonMatch == null) throw Exception('No JSON found');

    final data = json.decode(jsonMatch);

    // Save to Vault
    await _saveToVault(word, paragraph, data['meaning'] ?? '', targetLang);

    return {
      'meaning': data['meaning'] ?? '',
      'example': data['example'] ?? '',
      'phonetic': data['phonetic'] ?? '',
    };
  }

  Future<void> _saveToVault(
    String word,
    String context,
    String meaning,
    String language,
  ) async {
    if (kIsWeb) return;
    final db = await dbHelper.database;
    await db.insert('vocabulary_vault', {
      'word': word,
      'context_paragraph': context,
      'meaning': meaning,
      'language': language,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
