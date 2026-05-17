import 'package:equatable/equatable.dart';

enum AppTier { starter, pro, elite }

class UserSettings extends Equatable {
  final AppTier tier;
  final String targetLanguage;
  final String? customGeminiKey;
  final String? customGroqKey;
  final String? customOpenAIKey;
  final String? customClaudeKey;
  final String preferredProService; // 'Gemini' or 'Groq'
  final String preferredEliteModel;
  final double readerFontSize;
  final String readerFontFamily;
  final String readerBackgroundColor;
  final String? ttsVoice;
  final String? bookVoice;
  final List<String> autoImportFolderPaths;
  final String? lastImportedPath; // Optional: track last used

  const UserSettings({
    required this.tier,
    required this.targetLanguage,
    this.customGeminiKey,
    this.customGroqKey,
    this.customOpenAIKey,
    this.customClaudeKey,
    this.preferredProService = 'Gemini',
    this.preferredEliteModel = 'GPT-4o',
    this.readerFontSize = 18.0,
    this.readerFontFamily = 'Merriweather',
    this.readerBackgroundColor = 'Dark',
    this.ttsVoice,
    this.bookVoice,
    this.autoImportFolderPaths = const [],
    this.lastImportedPath,
  });

  @override
  List<Object?> get props => [
    tier,
    targetLanguage,
    customGeminiKey,
    customGroqKey,
    customOpenAIKey,
    customClaudeKey,
    preferredProService,
    preferredEliteModel,
    readerFontSize,
    readerFontFamily,
    readerBackgroundColor,
    ttsVoice,
    bookVoice,
    autoImportFolderPaths,
    lastImportedPath,
  ];

  UserSettings copyWith({
    AppTier? tier,
    String? targetLanguage,
    String? customGeminiKey,
    String? customGroqKey,
    String? customOpenAIKey,
    String? customClaudeKey,
    String? preferredProService,
    String? preferredEliteModel,
    double? readerFontSize,
    String? readerFontFamily,
    String? readerBackgroundColor,
    String? ttsVoice,
    String? bookVoice,
    List<String>? autoImportFolderPaths,
    String? lastImportedPath,
  }) {
    return UserSettings(
      tier: tier ?? this.tier,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      customGeminiKey: customGeminiKey ?? this.customGeminiKey,
      customGroqKey: customGroqKey ?? this.customGroqKey,
      customOpenAIKey: customOpenAIKey ?? this.customOpenAIKey,
      customClaudeKey: customClaudeKey ?? this.customClaudeKey,
      preferredProService: preferredProService ?? this.preferredProService,
      preferredEliteModel: preferredEliteModel ?? this.preferredEliteModel,
      readerFontSize: readerFontSize ?? this.readerFontSize,
      readerFontFamily: readerFontFamily ?? this.readerFontFamily,
      readerBackgroundColor: readerBackgroundColor ?? this.readerBackgroundColor,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      bookVoice: bookVoice ?? this.bookVoice,
      autoImportFolderPaths: autoImportFolderPaths ?? this.autoImportFolderPaths,
      lastImportedPath: lastImportedPath ?? this.lastImportedPath,
    );
  }
}
