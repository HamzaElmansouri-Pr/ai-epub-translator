import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/services/background_service.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");
  AppConstants.defaultGeminiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
  AppConstants.defaultGroqKey = dotenv.get('GROQ_API_KEY', fallback: '');

  // Configure DI
  await configureDependencies();

  // Initialize background service
  await initializeService();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<LibraryCubit>()),
        BlocProvider(create: (context) => getIt<ReaderCubit>()),
        BlocProvider(create: (context) => getIt<SettingsCubit>()),
        BlocProvider(create: (context) => getIt<TranslationCubit>()),
      ],
      child: const EpubTranslateApp(),
    ),
  );
}
