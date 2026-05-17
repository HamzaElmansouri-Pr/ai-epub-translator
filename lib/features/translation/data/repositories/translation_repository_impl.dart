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

    final targetLangCode = _getLangCode(targetLanguage);
    final batchSize = useGoogleTranslate ? 10 : 20;

    for (int i = 0; i < texts.length; i += batchSize) {
      final chunk = texts.skip(i).take(batchSize).toList();
      bool successfulBatch = false;
      final chunkString = chunk.join('\n\n|||||||\n\n');
      
      try {
        final chunkRes = await translate(
          chunkString,
          targetLanguage: targetLanguage,
          bookId: bookId,
          useGoogleTranslate: useGoogleTranslate,
        ).timeout(const Duration(seconds: 45));

        chunkRes.fold(
          (failure) => lastFailure = failure,
          (Translation translatedBlock) {
            final splits = translatedBlock.translation.split(RegExp(r'\n*\s*\|{5,}\s*\n*'));
            if (splits.length == chunk.length) {
              successfulBatch = true;
              for (int j = 0; j < chunk.length; j++) {
                final t = Translation(original: chunk[j], translation: splits[j].trim());
                results.add(t);
                final hash = HashUtils.hashText(chunk[j]);
                final langPair = 'auto_$targetLangCode'.toLowerCase();
                cacheDataSource.cacheTranslation(bookId ?? 'global', hash, langPair, t, 'batch');
              }
            }
          },
        );
      } catch (e) {
        lastFailure = ServerFailure('Batch translation timed out at index $i');
      }

      if (!successfulBatch) {
        const int concurrentLimit = 5;
        for (int k = 0; k < chunk.length; k += concurrentLimit) {
          final subChunk = chunk.skip(k).take(concurrentLimit).toList();
          final futures = subChunk.map((text) => translate(text, targetLanguage: targetLanguage, bookId: bookId, useGoogleTranslate: useGoogleTranslate).timeout(const Duration(seconds: 30)));
          final subResults = await Future.wait(futures);
          for (var res in subResults) {
            res.fold((l) => lastFailure = l, (r) => results.add(r));
          }
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (results.isEmpty && texts.isNotEmpty) return Left(lastFailure ?? const ServerFailure("All translation attempts failed."));
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
      final trimmedText = text.trim();
      final hash = HashUtils.hashText(trimmedText);
      final targetLangCode = _getLangCode(targetLanguage);
      final langPair = 'auto_$targetLangCode'.toLowerCase();

      final cached = await cacheDataSource.getCachedTranslation(effectiveBookId, hash, langPair);
      if (cached != null && cached.translation.isNotEmpty) return Right(cached);

      if (useGoogleTranslate) return await _fallbackToGoogleTranslate(text, effectiveBookId, hash, langPair, targetLangCode);

      // Usage Check (Free tier only)
      if (settings.tier == AppTier.starter && (settings.customGeminiKey == null || settings.customGeminiKey!.isEmpty) && (settings.customGroqKey == null || settings.customGroqKey!.isEmpty)) {
        if (!await usageDataSource.canTranslate()) return await _fallbackToGoogleTranslate(text, effectiveBookId, hash, langPair, targetLangCode);
      }

      // Elite Tier Logic
      if (settings.tier == AppTier.elite) {
        try {
          if (settings.preferredEliteModel.startsWith('gpt') && settings.customOpenAIKey != null) {
            final res = await openAiDataSource.translate(text, targetLangCode, settings);
            final t = Translation(original: text, translation: res, provider: 'gpt');
            await cacheDataSource.cacheTranslation(effectiveBookId, hash, langPair, t, 'gpt');
            return Right(t);
          } else if (settings.preferredEliteModel.startsWith('claude') && settings.customClaudeKey != null) {
            final res = await claudeDataSource.translate(text, targetLangCode, settings);
            final t = Translation(original: text, translation: res, provider: 'claude');
            await cacheDataSource.cacheTranslation(effectiveBookId, hash, langPair, t, 'claude');
            return Right(t);
          }
        } catch (e) { /* fallback */ }
      }

      // Pro Tier Logic (Gemini or Groq)
      final preferred = settings.preferredProService;
      try {
        if (preferred == 'Groq') {
          final t = await groqDataSource.translate(text, targetLangCode);
          await cacheDataSource.cacheTranslation(effectiveBookId, hash, langPair, t, 'groq');
          return Right(t);
        } else {
          final t = await geminiDataSource.translate(text, targetLangCode);
          await cacheDataSource.cacheTranslation(effectiveBookId, hash, langPair, t, 'gemini');
          
          if (settings.tier == AppTier.starter && (settings.customGeminiKey == null || settings.customGeminiKey!.isEmpty)) {
            await usageDataSource.incrementUsage();
          }
          return Right(t);
        }
      } catch (e) {
        // Fallback to the other service if one fails
        try {
          if (preferred == 'Gemini') {
            final t = await groqDataSource.translate(text, targetLangCode);
            return Right(t);
          } else {
             final t = await geminiDataSource.translate(text, targetLangCode);
             return Right(t);
          }
        } catch (e2) {
          return await _fallbackToGoogleTranslate(text, effectiveBookId, hash, langPair, targetLangCode);
        }
      }
    } catch (e) {
      return const Left(ServerFailure('Translation service error.'));
    }
  }

  Future<Either<Failure, Translation>> _fallbackToGoogleTranslate(String text, String effectiveBookId, String hash, String langPair, String targetLangCode) async {
    int retries = 3;
    while (retries > 0) {
      try {
        final translator = gtrans.GoogleTranslator();
        final t = await translator.translate(text, to: targetLangCode);
        final trans = Translation(original: text, translation: t.text);
        await cacheDataSource.cacheTranslation(effectiveBookId, hash, langPair, trans, 'google');
        return Right(trans);
      } catch (e) {
        retries--;
        if (retries == 0) return const Left(ServerFailure('Free services failed. Check internet.'));
        await Future.delayed(const Duration(milliseconds: 2000));
      }
    }
    return const Left(ServerFailure('Connection error.'));
  }

  String _getLangCode(String targetLang) {
    final lower = targetLang.toLowerCase();
    if (lower.length == 2) return lower;
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
