import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:epub_translate_meaning/core/theme/app_theme.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/pages/library_page.dart';
import 'package:epub_translate_meaning/features/reader/presentation/pages/reader_page.dart';
import 'package:epub_translate_meaning/features/settings/presentation/pages/settings_page.dart';
import 'package:epub_translate_meaning/features/library/presentation/pages/exported_files_page.dart';

class EpubTranslateApp extends StatelessWidget {
  const EpubTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LibraryPage()),
        GoRoute(
          path: '/reader',
          builder: (context, state) {
            final book = state.extra as Book;
            return ReaderPage(book: book);
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/exported-files',
          builder: (context, state) => const ExportedFilesPage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'EPub Translate Meaning',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
