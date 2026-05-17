import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:epub_translate_meaning/core/theme/app_theme.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/pages/library_page.dart';
import 'package:epub_translate_meaning/features/reader/presentation/pages/reader_page.dart';
import 'package:epub_translate_meaning/features/settings/presentation/pages/settings_page.dart';
import 'package:epub_translate_meaning/features/library/presentation/pages/exported_files_page.dart';
import 'package:epub_translate_meaning/features/library/presentation/pages/pdf_conversion_page.dart';
import 'package:epub_translate_meaning/screens/library/library_screen.dart';
import 'package:epub_translate_meaning/screens/reader/reader_screen.dart';

import 'package:epub_translate_meaning/features/library/presentation/pages/main_shell.dart';

class EpubTranslateApp extends StatelessWidget {
  const EpubTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const LibraryPage()),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
            GoRoute(
              path: '/exported-files',
              builder: (context, state) => const ExportedFilesPage(),
            ),
            GoRoute(
              path: '/pdf-convert',
              builder: (context, state) => const PdfConversionPage(),
            ),
            GoRoute(
              path: '/pdf-library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/reader',
          builder: (context, state) {
            final book = state.extra as Book;
            return ReaderPage(book: book);
          },
        ),
        GoRoute(
          path: '/pdf-reader',
          builder: (context, state) {
            final book = state.extra as Book;
            return ReaderScreen(book: book);
          },
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
