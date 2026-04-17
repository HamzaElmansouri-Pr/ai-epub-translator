import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';

abstract class SettingsLocalDataSource {
  Future<UserSettings> getSettings();
  Future<void> cacheTargetLanguage(String language);
  Future<void> cacheCustomGeminiKey(String? key);
  Future<void> cacheCustomOpenAIKey(String? key);
  Future<void> cacheCustomClaudeKey(String? key);
  Future<void> cachePreferredEliteModel(String model);
  Future<void> cacheReaderFontSize(double size);
  Future<void> cacheReaderFontFamily(String family);
  Future<void> cacheReaderBackgroundColor(String color);
  Future<void> cacheTtsVoice(String voice);
  Future<void> cacheBookVoice(String voice);
}

@LazySingleton(as: SettingsLocalDataSource)
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  static const String _langKey = 'target_language';
  static const String _geminiKey = 'custom_gemini_key';
  static const String _openAIKey = 'custom_openai_key';
  static const String _claudeKey = 'custom_claude_key';
  static const String _eliteModelKey = 'preferred_elite_model';
  static const String _readerFontSizeKey = 'reader_font_size';
  static const String _readerFontFamilyKey = 'reader_font_family';
  static const String _readerBgColorKey = 'reader_bg_color';
  static const String _ttsVoiceKey = 'tts_voice';
  static const String _bookVoiceKey = 'book_voice';

  SettingsLocalDataSourceImpl(this.prefs);

  @override
  Future<UserSettings> getSettings() async {
    final lang = prefs.getString(_langKey) ?? 'Arabic';
    final customKey = await secureStorage.read(key: _geminiKey);
    final openAIKey = await secureStorage.read(key: _openAIKey);
    final claudeKey = await secureStorage.read(key: _claudeKey);
    final eliteModel = prefs.getString(_eliteModelKey) ?? 'GPT-4o';
    final fontSize = prefs.getDouble(_readerFontSizeKey) ?? 18.0;
    final fontFamily = prefs.getString(_readerFontFamilyKey) ?? 'Merriweather';
    final bgColor = prefs.getString(_readerBgColorKey) ?? 'Dark';
    final ttsV = prefs.getString(_ttsVoiceKey);
    final bookV = prefs.getString(_bookVoiceKey);

    // Determine tier based on keys presence
    AppTier activeTier = AppTier.starter;
    if (openAIKey != null || claudeKey != null) {
      activeTier = AppTier.elite;
    } else if (customKey != null) {
      activeTier = AppTier.pro;
    }

    return UserSettings(
      tier: activeTier,
      targetLanguage: lang,
      customGeminiKey: customKey,
      customOpenAIKey: openAIKey,
      customClaudeKey: claudeKey,
      preferredEliteModel: eliteModel,
      readerFontSize: fontSize,
      readerFontFamily: fontFamily,
      readerBackgroundColor: bgColor,
      ttsVoice: ttsV,
      bookVoice: bookV,
    );
  }

  @override
  Future<void> cacheTargetLanguage(String language) async {
    await prefs.setString(_langKey, language);
  }

  @override
  Future<void> cacheCustomGeminiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await secureStorage.delete(key: _geminiKey);
    } else {
      await secureStorage.write(key: _geminiKey, value: key);
    }
  }

  @override
  Future<void> cacheCustomOpenAIKey(String? key) async {
    if (key == null || key.isEmpty) {
      await secureStorage.delete(key: _openAIKey);
    } else {
      await secureStorage.write(key: _openAIKey, value: key);
    }
  }

  @override
  Future<void> cacheCustomClaudeKey(String? key) async {
    if (key == null || key.isEmpty) {
      await secureStorage.delete(key: _claudeKey);
    } else {
      await secureStorage.write(key: _claudeKey, value: key);
    }
  }

  @override
  Future<void> cachePreferredEliteModel(String model) async {
    await prefs.setString(_eliteModelKey, model);
  }

  @override
  Future<void> cacheReaderFontSize(double size) async {
    await prefs.setDouble(_readerFontSizeKey, size);
  }

  @override
  Future<void> cacheReaderFontFamily(String family) async {
    await prefs.setString(_readerFontFamilyKey, family);
  }

  @override
  Future<void> cacheReaderBackgroundColor(String color) async {
    await prefs.setString(_readerBgColorKey, color);
  }

  @override
  Future<void> cacheTtsVoice(String voice) async {
    await prefs.setString(_ttsVoiceKey, voice);
  }

  @override
  Future<void> cacheBookVoice(String voice) async {
    await prefs.setString(_bookVoiceKey, voice);
  }
}
