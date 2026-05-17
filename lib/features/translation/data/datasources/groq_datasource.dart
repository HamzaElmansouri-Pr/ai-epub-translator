import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart';

abstract class GroqDataSource {
  Future<Translation> translate(String text, String targetLanguage);
}

@LazySingleton(as: GroqDataSource)
class GroqDataSourceImpl implements GroqDataSource {
  final Dio dio;
  final SettingsRepository _settingsRepository;

  GroqDataSourceImpl(this.dio, this._settingsRepository);

  @override
  Future<Translation> translate(String text, String targetLanguage) async {
    final settingsResult = await _settingsRepository.getSettings();
    String apiKey = AppConstants.defaultGroqKey;
    
    settingsResult.fold(
      (failure) => null,
      (settings) {
        if (settings.customGroqKey != null && settings.customGroqKey!.isNotEmpty) {
          apiKey = settings.customGroqKey!;
        }
      },
    );

    const systemPrompt =
        "You are a professional literary translator. Translate the following paragraph into [Target Language]. Maintain the soul and emotional tone of the text, use natural linguistic flow, and strictly avoid literal translation. Return the result in a JSON format: {\"original\": \"...\", \"translation\": \"...\"}.";

    final payload = {
      "model": AppConstants.groqModel,
      "messages": [
        {
          "role": "system",
          "content": systemPrompt.replaceAll(
            '[Target Language]',
            targetLanguage,
          ),
        },
        {"role": "user", "content": text},
      ],
      "response_format": {"type": "json_object"},
    };

    final response = await dio.post(
      '${AppConstants.groqBaseUrl}/chat/completions',
      data: payload,
      options: Options(
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final content = data['choices'][0]['message']['content'];
      final Map<String, dynamic> jsonResponse = json.decode(content);

      return Translation(
        original: jsonResponse['original'] ?? text,
        translation: jsonResponse['translation'] ?? '',
      );
    } else {
      throw Exception('Groq API Error: ${response.statusCode}');
    }
  }
}
