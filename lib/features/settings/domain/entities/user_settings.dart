import 'package:equatable/equatable.dart';

enum AppTier { starter, pro, elite }

class UserSettings extends Equatable {
  final AppTier tier;
  final String targetLanguage;
  final String? customGeminiKey;
  final String? customOpenAIKey;
  final String? customClaudeKey;
  final String preferredEliteModel;
  final double readerFontSize;
  final String readerFontFamily;
  final String readerBackgroundColor;

  const UserSettings({
    required this.tier,
    required this.targetLanguage,
    this.customGeminiKey,
    this.customOpenAIKey,
    this.customClaudeKey,
    this.preferredEliteModel = 'GPT-4o',
    this.readerFontSize = 18.0,
    this.readerFontFamily = 'Merriweather',
    this.readerBackgroundColor = 'Dark',
  });

  @override
  List<Object?> get props => [
    tier,
    targetLanguage,
    customGeminiKey,
    customOpenAIKey,
    customClaudeKey,
    preferredEliteModel,
    readerFontSize,
    readerFontFamily,
    readerBackgroundColor,
  ];

  UserSettings copyWith({
    AppTier? tier,
    String? targetLanguage,
    String? customGeminiKey,
    String? customOpenAIKey,
    String? customClaudeKey,
    String? preferredEliteModel,
    double? readerFontSize,
    String? readerFontFamily,
    String? readerBackgroundColor,
  }) {
    return UserSettings(
      tier: tier ?? this.tier,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      customGeminiKey: customGeminiKey ?? this.customGeminiKey,
      customOpenAIKey: customOpenAIKey ?? this.customOpenAIKey,
      customClaudeKey: customClaudeKey ?? this.customClaudeKey,
      preferredEliteModel: preferredEliteModel ?? this.preferredEliteModel,
      readerFontSize: readerFontSize ?? this.readerFontSize,
      readerFontFamily: readerFontFamily ?? this.readerFontFamily,
      readerBackgroundColor:
          readerBackgroundColor ?? this.readerBackgroundColor,
    );
  }
}
