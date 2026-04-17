import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/exceptions.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';

@lazySingleton
class OpenAiDataSource {
  Future<String> translate(
    String text,
    String targetLanguage,
    UserSettings settings,
  ) async {
    final apiKey = settings.customOpenAIKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw ServerException('OpenAI API key not found');
    }

    final model = settings.preferredEliteModel.startsWith('gpt')
        ? settings.preferredEliteModel
        : 'gpt-4o'; // fallback

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

    final systemPrompt =
        """You are a professional literary translator. Translate the following paragraph into $targetLanguage.
Maintain the soul and emotional tone of the text, use natural linguistic flow, and strictly avoid literal translation.
Return ONLY the translated text. Do not use JSON, do not add introductory text, do not add quotes around the output unless they are part of the translation.""";

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': text},
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded['choices'] != null && decoded['choices'].isNotEmpty) {
        final message = decoded['choices'][0]['message']['content'];
        return (message as String).trim();
      }
    }

    throw ServerException('OpenAI Error: ${response.statusCode}');
  }
}
