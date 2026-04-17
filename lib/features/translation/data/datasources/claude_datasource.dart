import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/exceptions.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';

@lazySingleton
class ClaudeDataSource {
  Future<String> translate(
    String text,
    String targetLanguage,
    UserSettings settings,
  ) async {
    final apiKey = settings.customClaudeKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw ServerException('Claude API key not found');
    }

    final model = settings.preferredEliteModel.startsWith('claude')
        ? settings.preferredEliteModel
        : 'claude-3-5-sonnet-20240620'; // fallback

    final uri = Uri.parse('https://api.anthropic.com/v1/messages');

    final systemPrompt =
        """You are a professional literary translator. Translate the following paragraph into $targetLanguage.
Maintain the soul and emotional tone of the text, use natural linguistic flow, and strictly avoid literal translation.
Return ONLY the translated text. Do not use JSON, do not add introductory text, do not add quotes around the output unless they are part of the translation.""";

    final response = await http.post(
      uri,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': text},
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded['content'] != null && decoded['content'].isNotEmpty) {
        final message = decoded['content'][0]['text'];
        return (message as String).trim();
      }
    }

    throw ServerException('Claude Error: ${response.statusCode}');
  }
}
