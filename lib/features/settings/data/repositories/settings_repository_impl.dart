import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart';
import 'package:epub_translate_meaning/features/settings/data/datasources/settings_local_datasource.dart';

@LazySingleton(as: SettingsRepository)
class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource dataSource;

  SettingsRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, UserSettings>> getSettings() async {
    try {
      final settings = await dataSource.getSettings();
      return Right(settings);
    } catch (e) {
      return const Left(CacheFailure('Failed to load settings'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveCustomGeminiKey(String key) async {
    try {
      await dataSource.cacheCustomGeminiKey(key);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save API key'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveCustomOpenAIKey(String key) async {
    try {
      await dataSource.cacheCustomOpenAIKey(key);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save OpenAI key'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveCustomClaudeKey(String key) async {
    try {
      await dataSource.cacheCustomClaudeKey(key);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save Claude key'));
    }
  }

  @override
  Future<Either<Failure, Unit>> savePreferredEliteModel(String model) async {
    try {
      await dataSource.cachePreferredEliteModel(model);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save preferred elite model'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveTargetLanguage(String language) async {
    try {
      await dataSource.cacheTargetLanguage(language);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save language preference'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveReaderFontSize(double size) async {
    try {
      await dataSource.cacheReaderFontSize(size);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save font size'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveReaderFontFamily(String family) async {
    try {
      await dataSource.cacheReaderFontFamily(family);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save font family'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveReaderBackgroundColor(String color) async {
    try {
      await dataSource.cacheReaderBackgroundColor(color);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save background color'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveTtsVoice(String voice) async {
    try {
      await dataSource.cacheTtsVoice(voice);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save TTS voice'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveBookVoice(String voice) async {
    try {
      await dataSource.cacheBookVoice(voice);
      return const Right(unit);
    } catch (e) {
      return const Left(CacheFailure('Failed to save Book voice'));
    }
  }
}
