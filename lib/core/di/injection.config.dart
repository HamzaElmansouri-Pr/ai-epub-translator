// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:epub_translate_meaning/core/di/register_module.dart' as _i887;
import 'package:epub_translate_meaning/core/services/audio_handler.dart'
    as _i949;
import 'package:epub_translate_meaning/core/services/tts_service.dart'
    as _i1004;
import 'package:epub_translate_meaning/core/storage/database_helper.dart'
    as _i964;
import 'package:epub_translate_meaning/core/storage/in_memory_book_store.dart'
    as _i370;
import 'package:epub_translate_meaning/features/dictionary/data/datasources/dictionary_api_datasource.dart'
    as _i258;
import 'package:epub_translate_meaning/features/dictionary/data/repositories/dictionary_repository_impl.dart'
    as _i969;
import 'package:epub_translate_meaning/features/dictionary/domain/repositories/dictionary_repository.dart'
    as _i262;
import 'package:epub_translate_meaning/features/dictionary/presentation/cubit/dictionary_cubit.dart'
    as _i92;
import 'package:epub_translate_meaning/features/library/data/datasources/local_book_datasource.dart'
    as _i315;
import 'package:epub_translate_meaning/features/library/data/repositories/library_repository_impl.dart'
    as _i670;
import 'package:epub_translate_meaning/features/library/domain/repositories/library_repository.dart'
    as _i523;
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart'
    as _i366;
import 'package:epub_translate_meaning/features/library/domain/usecases/get_books.dart'
    as _i303;
import 'package:epub_translate_meaning/features/library/domain/usecases/import_book.dart'
    as _i703;
import 'package:epub_translate_meaning/features/library/domain/usecases/update_book.dart'
    as _i1018;
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart'
    as _i280;
import 'package:epub_translate_meaning/features/reader/data/datasources/epub_parser_datasource.dart'
    as _i463;
import 'package:epub_translate_meaning/features/reader/data/repositories/reader_repository_impl.dart'
    as _i863;
import 'package:epub_translate_meaning/features/reader/domain/repositories/reader_repository.dart'
    as _i593;
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_cubit.dart'
    as _i216;
import 'package:epub_translate_meaning/features/settings/data/datasources/settings_local_datasource.dart'
    as _i473;
import 'package:epub_translate_meaning/features/settings/data/repositories/settings_repository_impl.dart'
    as _i1063;
import 'package:epub_translate_meaning/features/settings/domain/repositories/settings_repository.dart'
    as _i1052;
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart'
    as _i547;
import 'package:epub_translate_meaning/features/translation/data/datasources/claude_datasource.dart'
    as _i691;
import 'package:epub_translate_meaning/features/translation/data/datasources/gemini_datasource.dart'
    as _i325;
import 'package:epub_translate_meaning/features/translation/data/datasources/groq_datasource.dart'
    as _i38;
import 'package:epub_translate_meaning/features/translation/data/datasources/openai_datasource.dart'
    as _i439;
import 'package:epub_translate_meaning/features/translation/data/datasources/translation_cache_datasource.dart'
    as _i413;
import 'package:epub_translate_meaning/features/translation/data/datasources/usage_datasource.dart'
    as _i935;
import 'package:epub_translate_meaning/features/translation/data/repositories/translation_repository_impl.dart'
    as _i76;
import 'package:epub_translate_meaning/features/translation/domain/repositories/translation_repository.dart'
    as _i3;
import 'package:epub_translate_meaning/features/translation/presentation/cubit/bulk_translation_cubit.dart'
    as _i594;
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_cubit.dart'
    as _i409;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i361.Dio>(() => registerModule.dio);
    gh.lazySingleton<_i1004.TtsService>(() => _i1004.TtsService());
    gh.lazySingleton<_i964.DatabaseHelper>(() => _i964.DatabaseHelper());
    gh.lazySingleton<_i370.InMemoryBookStore>(() => _i370.InMemoryBookStore());
    gh.lazySingleton<_i691.ClaudeDataSource>(() => _i691.ClaudeDataSource());
    gh.lazySingleton<_i439.OpenAiDataSource>(() => _i439.OpenAiDataSource());
    gh.lazySingleton<_i935.UsageDataSource>(
      () => _i935.UsageDataSourceImpl(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i463.EpubParserDataSource>(
      () => _i463.EpubParserDataSourceImpl(gh<_i370.InMemoryBookStore>()),
    );
    gh.lazySingleton<_i473.SettingsLocalDataSource>(
      () => _i473.SettingsLocalDataSourceImpl(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i325.GeminiDataSource>(
      () => _i325.GeminiDataSourceImpl(),
    );
    gh.lazySingleton<_i258.DictionaryApiDataSource>(
      () => _i258.DictionaryApiDataSourceImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i315.LocalBookDataSource>(
      () => _i315.LocalBookDataSourceImpl(
        gh<_i964.DatabaseHelper>(),
        gh<_i370.InMemoryBookStore>(),
      ),
    );
    gh.lazySingleton<_i593.ReaderRepository>(
      () => _i863.ReaderRepositoryImpl(
        gh<_i463.EpubParserDataSource>(),
        gh<_i315.LocalBookDataSource>(),
      ),
    );
    gh.lazySingleton<_i216.ReaderCubit>(
      () => _i216.ReaderCubit(gh<_i593.ReaderRepository>()),
    );
    gh.lazySingleton<_i949.EpubAudioHandler>(
      () => _i949.EpubAudioHandler(gh<_i1004.TtsService>()),
    );
    gh.lazySingleton<_i38.GroqDataSource>(
      () => _i38.GroqDataSourceImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i523.LibraryRepository>(
      () => _i670.LibraryRepositoryImpl(gh<_i315.LocalBookDataSource>()),
    );
    gh.lazySingleton<_i262.DictionaryRepository>(
      () => _i969.DictionaryRepositoryImpl(gh<_i258.DictionaryApiDataSource>()),
    );
    gh.lazySingleton<_i366.ExportService>(
      () => _i366.ExportService(gh<_i964.DatabaseHelper>()),
    );
    gh.lazySingleton<_i413.TranslationCacheDataSource>(
      () => _i413.TranslationCacheDataSourceImpl(gh<_i964.DatabaseHelper>()),
    );
    gh.lazySingleton<_i1052.SettingsRepository>(
      () => _i1063.SettingsRepositoryImpl(gh<_i473.SettingsLocalDataSource>()),
    );
    gh.lazySingleton<_i303.GetBooks>(
      () => _i303.GetBooks(gh<_i523.LibraryRepository>()),
    );
    gh.lazySingleton<_i703.ImportBook>(
      () => _i703.ImportBook(gh<_i523.LibraryRepository>()),
    );
    gh.lazySingleton<_i1018.UpdateBook>(
      () => _i1018.UpdateBook(gh<_i523.LibraryRepository>()),
    );
    gh.factory<_i92.DictionaryCubit>(
      () => _i92.DictionaryCubit(gh<_i262.DictionaryRepository>()),
    );
    gh.lazySingleton<_i547.SettingsCubit>(
      () => _i547.SettingsCubit(gh<_i1052.SettingsRepository>()),
    );
    gh.factory<_i280.LibraryCubit>(
      () => _i280.LibraryCubit(
        getBooks: gh<_i303.GetBooks>(),
        importBook: gh<_i703.ImportBook>(),
        updateBook: gh<_i1018.UpdateBook>(),
      ),
    );
    gh.lazySingleton<_i3.TranslationRepository>(
      () => _i76.TranslationRepositoryImpl(
        gh<_i325.GeminiDataSource>(),
        gh<_i38.GroqDataSource>(),
        gh<_i439.OpenAiDataSource>(),
        gh<_i691.ClaudeDataSource>(),
        gh<_i413.TranslationCacheDataSource>(),
        gh<_i935.UsageDataSource>(),
        gh<_i473.SettingsLocalDataSource>(),
      ),
    );
    gh.lazySingleton<_i409.TranslationCubit>(
      () => _i409.TranslationCubit(gh<_i3.TranslationRepository>()),
    );
    gh.lazySingleton<_i594.BulkTranslationCubit>(
      () => _i594.BulkTranslationCubit(gh<_i3.TranslationRepository>()),
    );
    return this;
  }
}

class _$RegisterModule extends _i887.RegisterModule {}
