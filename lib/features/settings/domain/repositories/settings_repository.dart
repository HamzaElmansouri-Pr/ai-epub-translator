import 'package:dartz/dartz.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';

abstract class SettingsRepository {
  Future<Either<Failure, UserSettings>> getSettings();
  Future<Either<Failure, Unit>> saveTargetLanguage(String language);
  Future<Either<Failure, Unit>> saveCustomGeminiKey(String key);
  Future<Either<Failure, Unit>> saveCustomOpenAIKey(String key);
  Future<Either<Failure, Unit>> saveCustomClaudeKey(String key);
  Future<Either<Failure, Unit>> savePreferredEliteModel(String model);
  Future<Either<Failure, Unit>> saveReaderFontSize(double size);
  Future<Either<Failure, Unit>> saveReaderFontFamily(String family);
  Future<Either<Failure, Unit>> saveReaderBackgroundColor(String color);
  Future<Either<Failure, Unit>> saveTtsVoice(String voice);
  Future<Either<Failure, Unit>> saveBookVoice(String voice);
}
