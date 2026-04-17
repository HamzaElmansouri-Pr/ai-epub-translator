import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:translator/translator.dart' as gtrans;
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/core/constants/app_constants.dart';
import 'package:epub_translate_meaning/core/utils/hash_utils.dart';
import 'package:epub_translate_meaning/features/translation/domain/entities/translation.dart';
import 'package:epub_translate_meaning/features/translation/domain/repositories/translation_repository.dart';
import 'package:epub_translate_meaning/features/translation/data/datasources/gemini_datasource.dart';
import 'package:epub_translate_meaning/features/translation/data/datasources/groq_datasource.dart';
import 'package:epub_translate_meaning/features/translation/data/datasources/openai_datasource.dart';
import 'package:epub_translate_meaning/features/translation/data/datasources/claude_datasource.dart';
import 'package:epub_translate_meaning/features/translation/data/datasources/translation_cache_datasource.dart';
import 'package:epub_translate_meaning/features/translation/data/datasources/usage_datasource.dart';
import 'package:epub_translate_meaning/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';

@LazySingleton(as: TranslationRepository)
class TranslationRepositoryImpl implements TranslationRepository {
  final GeminiDataSource geminiDataSource;
  final GroqDataSource groqDataSource;
  final OpenAiDataSource openAiDataSource;
  final ClaudeDataSource claudeDataSource;
  final TranslationCacheDataSource cacheDataSource;
  final UsageDataSource usageDataSource;
  final SettingsLocalDataSource settingsDataSource;

  TranslationRepositoryImpl(
    this.geminiDataSource,
    this.groqDataSource,
    this.openAiDataSource,
    this.claudeDataSource,
    this.cacheDataSource,
    this.usageDataSource,
    this.settingsDataSource,
  );

  @override
  Future<Either<Failure, List<Translation>>> translateBatch(
    List<String> texts, {
    required String targetLanguage,
    String? bookId,
    bool useGoogleTranslate = false,
  }) async {
    List<Translation> results = [];
    Failure? lastFailure;

    // Batch translations into groups of 10 to avoid limits and token saturation
    final batchSize = 10;

    for (int i = 0; i < texts.length; i += batchSize) {
      final chunk = texts.skip(i).take(batchSize).toList();

      bool successfulBatch = false;

      final chunkString = chunk.join('\n\n|||||||\n\n');
      final chunkRes = await translate(
        chunkString,
        targetLanguage: targetLanguage,
        bookId: bookId,
        useGoogleTranslate:
            useGoogleTranslate, // Apply batching to Google Translate too
      );

      chunkRes.fold(
        (failure) {
          lastFailure = failure;
        },
        (Translation translatedBlock) {
          // Google Translate or Gemini might slightly modify spacing around the separator
          final splits = translatedBlock.translation.split(
            RegExp(r'\n*\s*\|{5,}\s*\n*'),
          );
          if (splits.length == chunk.length) {
            successfulBatch = true;
            for (int j = 0; j < chunk.length; j++) {
              final originalText = chunk[j];
              final translatedText = splits[j].trim();

              final t = Translation(
                original: originalText,
                translation: translatedText,
              );
              results.add(t);

              final hash = HashUtils.hashText(originalText);
              final langPair = 'auto_$targetLanguage'.toLowerCase();
              final effectiveBookId = bookId ?? 'global';
              cacheDataSource.cacheTranslation(
                effectiveBookId,
                hash,
                langPair,
                t,
                'batch',
              );
            }
          } else {
            // If batch splitting failed, fallback to individual items
            successfulBatch = false;
          }
        },
      );

      if (!successfulBatch) {
        // If fallback is triggered, do them individually (and DO NOT abort if one fails)
        for (final text in chunk) {
          final res = await translate(
            text,
            targetLanguage: targetLanguage,
            bookId: bookId,
            useGoogleTranslate: useGoogleTranslate,
          );

          res.fold((l) {
            lastFailure = l;
          }, (r) => results.add(r));

          // Wait to prevent 429 errors from APIs
          if (useGoogleTranslate) {
            await Future.delayed(const Duration(milliseconds: 1500));
          } else {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      } else {
        // Add a brief delay between successful LLM/Google batches
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    if (results.isEmpty && texts.isNotEmpty) {
      return Left(
        lastFailure ?? const ServerFailure("All batch APIs limit reached."),
      );
    }
    return Right(results);
  }

  @override
  Future<Either<Failure, Translation>> translate(
    String text, {
    required String targetLanguage,
    String? bookId,
    bool useGoogleTranslate = false,
  }) async {
    try {
      final settings = await settingsDataSource.getSettings();
      final effectiveBookId = bookId ?? 'global';
      final hash = HashUtils.hashText(text);
      final langPair = 'auto_${settings.targetLanguage}'.toLowerCase();

      // 1. Check cache
      final cached = await cacheDataSource.getCachedTranslation(
        effectiveBookId,
        hash,
        langPair,
      );
      if (cached != null) {
        return Right(cached);
      }

      // If user explicitly requested simple Google Translate (free fallback)
      if (useGoogleTranslate) {
        return await _fallbackToGoogleTranslate(
          text,
          effectiveBookId,
          hash,
          langPair,
          settings.targetLanguage,
        );
      }

      // 2. Check daily limit (Only if NOT Pro)
      if (settings.customGeminiKey == null ||
          settings.customGeminiKey!.isEmpty) {
        if (!await usageDataSource.canTranslate()) {
          return await _fallbackToGoogleTranslate(
            text,
            effectiveBookId,
            hash,
            langPair,
            settings.targetLanguage,
          );
        }
      }

      if (useGoogleTranslate) {
        final res = await _translateWithGoogle(text, settings.targetLanguage);
        final translation = Translation(
          original: text,
          translation: res,
          provider: 'google',
        );
        await cacheDataSource.cacheTranslation(
          effectiveBookId,
          hash,
          langPair,
          translation,
          'google',
        );
        return Right(translation);
      }

      if (settings.tier == AppTier.elite) {
        try {
          if (settings.preferredEliteModel.startsWith('gpt') &&
              settings.customOpenAIKey != null) {
            final res = await openAiDataSource.translate(
              text,
              settings.targetLanguage,
              settings,
            );
            final translation = Translation(
              original: text,
              translation: res,
              provider: 'gpt',
            );
            await cacheDataSource.cacheTranslation(
              effectiveBookId,
              hash,
              langPair,
              translation,
              'gpt',
            );
            return Right(translation);
          } else if (settings.preferredEliteModel.startsWith('claude') &&
              settings.customClaudeKey != null) {
            final res = await claudeDataSource.translate(
              text,
              settings.targetLanguage,
              settings,
            );
            final translation = Translation(
              original: text,
              translation: res,
              provider: 'claude',
            );
            await cacheDataSource.cacheTranslation(
              effectiveBookId,
              hash,
              langPair,
              translation,
              'claude',
            );
            return Right(translation);
          }
        } catch (e) {
          // fallback to gemini
        }
      }

      // 3. Fallback or Standard translation (Priority 1)
      try {
        final translation = await _translateWithKey(
          text,
          settings.targetLanguage,
          settings.customGeminiKey,
        );
        await cacheDataSource.cacheTranslation(
          effectiveBookId,
          hash,
          langPair,
          translation,
          'gemini',
        );

        if (settings.customGeminiKey == null ||
            settings.customGeminiKey!.isEmpty) {
          await usageDataSource.incrementUsage();
        }

        return Right(translation);
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        final isQuotaError =
            errorString.contains('quota') || errorString.contains('429');

        if (isQuotaError &&
            (settings.customGeminiKey == null ||
                settings.customGeminiKey!.isEmpty)) {
          return await _fallbackToGoogleTranslate(
            text,
            effectiveBookId,
            hash,
            langPair,
            settings.targetLanguage,
          );
        }

        // 4. Fallback to Groq (Priority 2)
        try {
          final translation = await groqDataSource.translate(
            text,
            settings.targetLanguage,
          );
          await cacheDataSource.cacheTranslation(
            effectiveBookId,
            hash,
            langPair,
            translation,
            'groq',
          );

          if (settings.customGeminiKey == null ||
              settings.customGeminiKey!.isEmpty) {
            await usageDataSource.incrementUsage();
          }

          return Right(translation);
        } catch (e2) {
          return await _fallbackToGoogleTranslate(
            text,
            effectiveBookId,
            hash,
            langPair,
            settings.targetLanguage,
          );
        }
      }
    } catch (e) {
      return const Left(
        ServerFailure('Translation failed. Please try again later.'),
      );
    }
  }

  Future<Translation> _translateWithKey(
    String text,
    String targetLanguage,
    String? customKey,
  ) async {
    final model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: customKey ?? AppConstants.defaultGeminiKey,
    );

    final systemPrompt =
        """
You are a professional literary translator. Translate the following paragraph into $targetLanguage.
Maintain the soul and emotional tone of the text, use natural linguistic flow, and strictly avoid literal translation.
Return ONLY the translated text. Do not use JSON, do not add introductory text, do not add quotes around the output unless they are part of the translation.
""";

    final content = [
      Content.text("$systemPrompt\n\nParagraph to translate:\n$text"),
    ];
    final response = await model.generateContent(content);

    final responseText = response.text?.trim();
    if (responseText == null || responseText.isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    return Translation(original: text, translation: responseText);
  }

  Future<Either<Failure, Translation>> _fallbackToGoogleTranslate(
    String text,
    String effectiveBookId,
    String hash,
    String langPair,
    String targetLanguage,
  ) async {
    int retries = 3;
    while (retries > 0) {
      try {
        final translator = gtrans.GoogleTranslator();
        String destCode = _getLangCode(targetLanguage);
        final t = await translator.translate(text, to: destCode);
        final trans = Translation(original: text, translation: t.text);
        await cacheDataSource.cacheTranslation(
          effectiveBookId,
          hash,
          langPair,
          trans,
          'google',
        );
        return Right(trans);
      } catch (e) {
        retries--;
        if (retries == 0) {
          return const Left(
            ServerFailure(
              'All services and Free Google Translate failed. Please check your connection.',
            ),
          );
        }
        await Future.delayed(const Duration(milliseconds: 2000));
      }
    }
    return const Left(
      ServerFailure(
        'All services and Free Google Translate failed. Please check your connection.',
      ),
    );
  }

  Future<String> _translateWithGoogle(String text, String targetLanguage) async {
    final translator = gtrans.GoogleTranslator();
    String destCode = _getLangCode(targetLanguage);
    final t = await translator.translate(text, to: destCode);
    return t.text;
  }

  String _getLangCode(String targetLang) {
    final lower = targetLang.toLowerCase();
    if (lower.contains('arabic')) return 'ar';
    if (lower.contains('spanish')) return 'es';
    if (lower.contains('french')) return 'fr';
    if (lower.contains('german')) return 'de';
    if (lower.contains('chinese')) return 'zh-cn';
    if (lower.contains('japanese')) return 'ja';
    if (lower.contains('russian')) return 'ru';
    if (lower.contains('portuguese')) return 'pt';
    if (lower.contains('italian')) return 'it';
    if (lower.contains('korean')) return 'ko';
    if (lower.contains('hindi')) return 'hi';
    if (lower.contains('turkish')) return 'tr';
    if (lower.contains('dutch')) return 'nl';
    return 'en';
  }
}
