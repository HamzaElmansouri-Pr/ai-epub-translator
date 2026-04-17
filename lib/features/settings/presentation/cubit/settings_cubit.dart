import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';

@lazySingleton
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository repository;

  SettingsCubit(this.repository) : super(SettingsInitial());

  Future<void> loadSettings() async {
    emit(SettingsLoading());
    final result = await repository.getSettings();
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (settings) => emit(SettingsLoaded(settings)),
    );
  }

  Future<void> updateLanguage(String language) async {
    final result = await repository.saveTargetLanguage(language);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updateGeminiKey(String key) async {
    final result = await repository.saveCustomGeminiKey(key);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updateOpenAIKey(String key) async {
    final result = await repository.saveCustomOpenAIKey(key);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updateClaudeKey(String key) async {
    final result = await repository.saveCustomClaudeKey(key);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updatePreferredEliteModel(String model) async {
    final result = await repository.savePreferredEliteModel(model);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updateReaderFontSize(double size) async {
    final result = await repository.saveReaderFontSize(size);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updateReaderFontFamily(String family) async {
    final result = await repository.saveReaderFontFamily(family);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }

  Future<void> updateReaderBackgroundColor(String color) async {
    final result = await repository.saveReaderBackgroundColor(color);
    result.fold(
      (failure) => emit(SettingsError(failure.message)),
      (_) => loadSettings(),
    );
  }
}
