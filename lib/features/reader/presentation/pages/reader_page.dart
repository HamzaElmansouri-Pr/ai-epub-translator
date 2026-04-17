import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';
import 'dart:ui' hide Paragraph;
import 'package:epub_translate_meaning/features/library/data/repositories/file_reader_stub.dart'
    if (dart.library.io) 'package:epub_translate_meaning/core/utils/file_reader_native.dart'
    if (dart.library.html) 'package:epub_translate_meaning/core/utils/file_reader_web.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/bulk_translation_cubit.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/local_book_datasource.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_cubit.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_state.dart';
import 'package:epub_translate_meaning/core/storage/database_helper.dart';
import 'package:epub_translate_meaning/core/utils/hash_utils.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/core/services/tts_service.dart';
import 'package:epub_translate_meaning/core/services/audio_handler.dart';
import 'package:epub_view/epub_view.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_state.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:epub_translate_meaning/features/reader/presentation/widgets/inline_translation_paragraph.dart';
import 'package:epub_translate_meaning/features/reader/presentation/widgets/reader_drawer.dart';

class ReaderPage extends StatefulWidget {
  final Book book;

  const ReaderPage({super.key, required this.book});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  EpubController? _epubController;
  bool _isHudVisible = false;
  List<String> _currentChapterParagraphs = [];
  bool _autoExpandTranslations = false;
  bool _isPlayingTts = false;
  late final SettingsCubit _settingsCubit;

  @override
  void dispose() {
    if (_epubController != null) {
      try {
        final current = _epubController!.currentValue;
        if (current != null) {
          final cubit = getIt<ReaderCubit>();
          cubit.updateReadingProgress(
            ReadingProgress(
              bookId: widget.book.id,
              chapterIndex: current.chapterNumber,
              paragraphIndex: current.paragraphNumber,
              scrollPosition: current.position.itemLeadingEdge,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } catch (_) {}
    }
    _epubController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _settingsCubit = getIt<SettingsCubit>()..loadSettings();
    _initController();
  }

  Future<void> _initController() async {
    final localDataSource = getIt<LocalBookDataSource>();
    var bytes = localDataSource.getEpubBytes(widget.book.id);
    final progress = await getIt<LocalBookDataSource>().getReadingProgress(widget.book.id);

    bytes ??= await readFileBytes(widget.book.filePath);

    if (!mounted) return;

    
    setState(() {
      _epubController = EpubController(document: EpubDocument.openData(bytes!));
      if(progress != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _epubController?.jumpTo(index: progress.paragraphIndex, alignment: progress.scrollPosition);
        });
      }
    });
  }

  Future<void> _exportExecute(BuildContext context, bool isPdf) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting ${isPdf ? "PDF" : "EPUB"}...')),
    );
    try {
      final exportService = getIt<ExportService>();
      final dynamic file = isPdf
          ? await exportService.generateBilingualPdf(
              widget.book.id,
              widget.book.title,
              widget.book.filePath,
            )
          : await exportService.generateBilingualEpub(
              widget.book.id,
              widget.book.title,
              widget.book.filePath,
            );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export Failed')));
    }
  }

  bool _isTranslatingForExport = false;
  final bool _exportIsPdf = false;
  final bool _isExtractingParagraphs = false;

  void _showExportBottomSheet(
    BuildContext ctx,
    UserSettings settings,
    bool isPdf,
    {bool isMd = false}
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bCtx) {
        return BlocProvider<BulkTranslationCubit>.value(
          value: getIt<BulkTranslationCubit>(),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              Future<void> handleExportTranslation(bool useGoogle) async {
                final service = FlutterBackgroundService();

                var isRunning = await service.isRunning();
                if (!isRunning) {
                  await service.startService();
                }

                service.invoke("startExport", {
                  "bookId": widget.book.id,
                  "bookTitle": widget.book.title,
                  "originalFilePath": widget.book.filePath,
                  "targetLanguage": settings.targetLanguage,
                  "isPdf": isPdf,
                  "isMd": isMd,
                  "useGoogle": useGoogle,
                });

                if (context.mounted) {
                  Navigator.pop(bCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Translation started in background mode! You can close the app.',
                      ),
                    ),
                  );
                }
              }

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Export ${isPdf ? "PDF" : "EPUB"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Do you want to translate the entire book before exporting? This may take several minutes if the book has many untranslated paragraphs.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    BlocConsumer<BulkTranslationCubit, BulkTranslationState>(
                      listener: (context, state) {
                        if (state is BulkTranslationCompleted &&
                            _isTranslatingForExport) {
                          _isTranslatingForExport = false;
                          Navigator.pop(bCtx);
                          _exportExecute(context, _exportIsPdf);
                        }
                      },
                      builder: (context, state) {
                        if (_isExtractingParagraphs) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          );
                        }

                        if (state is BulkTranslationInProgress &&
                            _isTranslatingForExport) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Translating Book: ${state.current} / ${state.total}',
                                style: const TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: state.total == 0
                                    ? 0
                                    : state.current / state.total,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                color: const Color(0xFF3B82F6),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _isTranslatingForExport = false;
                                    getIt<BulkTranslationCubit>().stop();
                                  },
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Stop Translation'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent
                                        .withOpacity(0.2),
                                    foregroundColor: Colors.redAccent,
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        if (state is BulkTranslationError &&
                            _isTranslatingForExport) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  state.message,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(bCtx);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Add API key in Settings.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.key, size: 16),
                                      label: const Text('Add Key'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white30,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          handleExportTranslation(true),
                                      icon: const Icon(
                                        Icons.g_translate,
                                        size: 16,
                                      ),
                                      label: const Text('Free Translate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF3B82F6,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        // Idle state or translating the chapter (not the book)
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(bCtx);
                                  _exportExecute(context, isPdf);
                                },
                                icon: const Icon(Icons.bolt),
                                label: const Text('Export As-Is (Instant)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.2),
                                  foregroundColor: const Color(0xFF3B82F6),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => handleExportTranslation(false),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text(
                                  'Translate All Then Export (Gemini)',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    149,
                                    117,
                                    230,
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => handleExportTranslation(true),
                                icon: const Icon(Icons.g_translate),
                                label: const Text(
                                  'Translate All Then Export (Google)',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(String name) {
    switch (name) {
      case 'Light':
        return const Color(0xFFF8F9FA);
      case 'Sepia':
        return const Color(0xFFF4ECD8);
      case 'Dark':
      default:
        return const Color(0xFF0F172A);
    }
  }

  Color _getTextColor(String name) {
    switch (name) {
      case 'Light':
        return const Color(0xFF1E293B);
      case 'Sepia':
        return const Color(0xFF433422);
      case 'Dark':
      default:
        return Colors.white.withOpacity(0.9);
    }
  }

  void _showAppearanceBottomSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reading Appearance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Theme',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildThemeOption(
                    'Light',
                    const Color(0xFFF8F9FA),
                    const Color(0xFF1E293B),
                  ),
                  _buildThemeOption(
                    'Sepia',
                    const Color(0xFFF4ECD8),
                    const Color(0xFF433422),
                  ),
                  _buildThemeOption(
                    'Dark',
                    const Color(0xFF0F172A),
                    Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Font Family',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFontOption('Merriweather'),
                  _buildFontOption('Inter'),
                  _buildFontOption('OpenDyslexic'),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Font Size',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) {
                  if (state is! SettingsLoaded) return const SizedBox();
                  return Slider(
                    value: state.settings.readerFontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 10,
                    activeColor: const Color(0xFF3B82F6),
                    inactiveColor: Colors.white.withOpacity(0.1),
                    onChanged: (val) {
                      getIt<SettingsCubit>().updateReaderFontSize(val);
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(String name, Color bg, Color fg) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final isSelected =
            state is SettingsLoaded &&
            state.settings.readerBackgroundColor == name;
        return GestureDetector(
          onTap: () {
            getIt<SettingsCubit>().updateReaderBackgroundColor(name);
          },
          child: Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: fg,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontOption(String family) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final isSelected =
            state is SettingsLoaded &&
            state.settings.readerFontFamily == family;
        return GestureDetector(
          onTap: () {
            getIt<SettingsCubit>().updateReaderFontFamily(family);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              family,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontFamily: family == 'OpenDyslexic' ? null : family,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTranslationOverlay(BuildContext context, String text) {
    if (text.trim().isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BlocProvider<TranslationCubit>.value(
          value: getIt<TranslationCubit>()
            ..translateParagraph(text.trim(), 'es', bookId: widget.book.id),
          child: Builder(
            builder: (context) {
              return Wrap(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Original',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Translation',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        BlocBuilder<TranslationCubit, TranslationState>(
                          builder: (context, state) {
                            if (state is TranslationLoading) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              );
                            } else if (state is TranslationSuccess) {
                              return Text(
                                state.translation.translation,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            } else if (state is TranslationError) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Error: \${state.message}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              );
                            } else if (state is TranslationExhausted) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Free API limit reached. The default key is exhausted for now.',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context); // Close the sheet
                                      context.push(
                                        '/settings',
                                      ); // Go to settings
                                    },
                                    icon: const Icon(Icons.settings),
                                    label: const Text(
                                      'Enter Custom Gemini Key',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showAutoTranslateBottomSheet(BuildContext ctx, UserSettings settings) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return BlocProvider<BulkTranslationCubit>.value(
          value: getIt<BulkTranslationCubit>(),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Auto-Translate Chapter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Automatically translate all ${_currentChapterParagraphs.length} paragraphs in this chapter. Translations will generate in the background without interrupting your reading.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                BlocBuilder<BulkTranslationCubit, BulkTranslationState>(
                  builder: (context, state) {
                    if (state is BulkTranslationInProgress) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Translating: \${state.current} / \${state.total}',
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: state.total == 0
                                ? 0
                                : state.current / state.total,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                getIt<BulkTranslationCubit>().stop();
                              },
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(
                                  0.2,
                                ),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (state is BulkTranslationError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              state.message,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(
                                      bCtx,
                                    ); // just close the bottom sheet
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Add API key in Settings.',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.key, size: 16),
                                  label: const Text('Add Key'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white30,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    getIt<BulkTranslationCubit>()
                                        .translateParagraphs(
                                          _currentChapterParagraphs,
                                          settings.targetLanguage,
                                          widget.book.id,
                                          useGoogleTranslate: true,
                                        );
                                  },
                                  icon: const Icon(Icons.g_translate, size: 16),
                                  label: const Text('Free Translate'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white30,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        CheckboxListTile(
                          value: _autoExpandTranslations,
                          onChanged: (val) {
                            
    setState(() {
                              _autoExpandTranslations = val ?? false;
                            });
                            if (mounted) Navigator.pop(bCtx);
                          },
                          title: const Text(
                            'Show inline translations by default',
                            style: TextStyle(color: Colors.white),
                          ),
                          activeColor: const Color(0xFF3B82F6),
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _currentChapterParagraphs.isEmpty
                                ? null
                                : () {
                                    getIt<BulkTranslationCubit>()
                                        .translateParagraphs(
                                          _currentChapterParagraphs,
                                          settings.targetLanguage,
                                          widget.book.id,
                                        );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Start Bulk Translation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>.value(
      value: _settingsCubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is! SettingsLoaded) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              ),
            );
          }
          final settings = state.settings;
          final bgColor = _getBackgroundColor(settings.readerBackgroundColor);

          return Scaffold(
            backgroundColor: bgColor,
            body: Stack(
              children: [
                Listener(
                  onPointerMove: (event) {
                    if (event.delta.dx > 12) {
                      // Swipe right -> Show HUD
                      if (!_isHudVisible && mounted) {
                        
    setState(() {
                          _isHudVisible = true;
                        });
                      }
                    } else if (event.delta.dx < -12) {
                      // Swipe left -> Hide HUD
                      if (_isHudVisible && mounted) {
                        
    setState(() {
                          _isHudVisible = false;
                        });
                      }
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      
    setState(() {
                        _isHudVisible = !_isHudVisible;
                      });
                    },
                    child: _epubController == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          )
                        : EpubView(
                            controller: _epubController!,
                            onDocumentLoaded: (doc) {},
                            builders: EpubViewBuilders<DefaultBuilderOptions>(
                              options: const DefaultBuilderOptions(),
                              chapterBuilder:
                                  (
                                    context,
                                    builders,
                                    document,
                                    chapters,
                                    paragraphs,
                                    index,
                                    chapterIndex,
                                    paragraphIndex,
                                    onExternalLinkPressed,
                                  ) {
                                    if (paragraphs.isEmpty) {
                                      return Container();
                                    }

                                    if (index == 0) {
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        if (mounted) {
                                          final currentTexts = paragraphs
                                              .map((p) => p.element.text)
                                              .toList();
                                          if (_currentChapterParagraphs
                                                  .length !=
                                              currentTexts.length) {
                                            // Do NOT call setState() here, as it forces EpubView to rebuild completely causing jump-to-top bugs!
                                            // We only need this variable purely for the 'stars icon' translations anyway.
                                            _currentChapterParagraphs =
                                                currentTexts;
                                          }
                                        }
                                      });
                                    }

                                    return BlocBuilder<
                                      SettingsCubit,
                                      SettingsState
                                    >(
                                      builder: (context, state) {
                                        final paragraphSettings =
                                            state is SettingsLoaded
                                            ? state.settings
                                            : settings;
                                        final rawTxt =
                                            paragraphs[index].element.text;
                                        final hash = HashUtils.hashText(rawTxt);
                                        Color? bgColor;

                                        Note? existingNote;
                                        if (context.read<ReaderCubit>().state is ReaderLoaded) {
                                          existingNote = (context.read<ReaderCubit>().state as ReaderLoaded).notes
                                              .where(
                                                (n) => n.paragraphHash == hash,
                                              )
                                              .firstOrNull;
                                        }

                                        if (existingNote != null) {
                                          switch (existingNote.colorMark) {
                                            case 'yellow':
                                              bgColor = const Color(
                                                0xFFFDE047,
                                              ).withValues(alpha: 0.3);
                                              break;
                                            case 'green':
                                              bgColor = const Color(
                                                0xFF86EFAC,
                                              ).withValues(alpha: 0.3);
                                              break;
                                            case 'pink':
                                              bgColor = const Color(
                                                0xFFF9A8D4,
                                              ).withValues(alpha: 0.3);
                                              break;
                                          }
                                        }

                                        return InlineTranslationParagraph(
                                          htmlData: paragraphs[index]
                                              .element
                                              .outerHtml,
                                          rawText:
                                              paragraphs[index].element.text,
                                          bookId: widget.book.id,
                                          settings: paragraphSettings,
                                          backgroundColor: bgColor,
                                          onLongPress: () {
                                            _showAnnotationMenu(
                                              context,
                                              widget.book.id,
                                              chapterIndex,
                                              paragraphIndex,
                                              rawTxt,
                                              hash,
                                              existingNote,
                                            );
                                          },
                                          autoExpand: _autoExpandTranslations,
                                          onLinkTap: (url) {
                                            onExternalLinkPressed(url);
                                          },
                                        );
                                      },
                                    );
                                  },
                            ),
                          ),
                  ),
                ),

                // Top Minimalist HUD
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  top: _isHudVisible ? 0 : -120,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 16, left: 16, right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.5),
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.black26, 
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.book.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w600, 
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    widget.book.author ?? 'Unknown Author',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6), 
                                      fontSize: 12, 
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              color: const Color(0xFF1E293B).withOpacity(0.95),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (value) {
                                if (value == 'export_md') _showExportBottomSheet(context, settings, false, isMd: true);
                                if (value == 'export_pdf') _showExportBottomSheet(context, settings, true);
                                if (value == 'export_epub') _showExportBottomSheet(context, settings, false);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'export_md', 
                                  child: ListTile(
                                    leading: Icon(Icons.description, color: Colors.white70), 
                                    title: Text('Export Markdown', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'export_pdf', 
                                  child: ListTile(
                                    leading: Icon(Icons.picture_as_pdf, color: Colors.white70), 
                                    title: Text('Export PDF', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'export_epub', 
                                  child: ListTile(
                                    leading: Icon(Icons.book, color: Colors.white70), 
                                    title: Text('Export EPUB', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Floating Pill Player
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  bottom: _isHudVisible ? 40 : -100,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: 64,
                          constraints: const BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3), 
                                blurRadius: 20, 
                                offset: const Offset(0, 10),
                              )
                            ]
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.text_format, color: Colors.white),
                                onPressed: () => _showAppearanceBottomSheet(context),
                              ),
                              IconButton(
                                icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                                onPressed: () => _showAutoTranslateBottomSheet(context, settings),
                              ),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6), 
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isPlayingTts ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    if (_isPlayingTts) {
                                      getIt<EpubAudioHandler>().pause();
                                      if (mounted) setState(() => _isPlayingTts = false);
                                    } else {
                                      if (_currentChapterParagraphs.isEmpty) return;
                                      setState(() => _isPlayingTts = true);
                                      getIt<EpubAudioHandler>().setAudiobookData(
                                        widget.book.title, 
                                        'Chapter', 
                                        _currentChapterParagraphs, 
                                        0,
                                      );
                                      getIt<EpubAudioHandler>().play().then((_) {
                                        if (mounted) setState(() => _isPlayingTts = false);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAnnotationMenu(
    BuildContext context,
    String bookId,
    int chapterIndex,
    int paragraphIndex,
    String text,
    String hash,
    Note? existingNote,
  ) {
    String selectedColor = existingNote?.colorMark ?? 'yellow';
    final TextEditingController noteController = TextEditingController(
      text: existingNote?.noteText,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Highlight & Note',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: ['yellow', 'green', 'pink'].map((color) {
                      Color c;
                      if (color == 'yellow') {
                        c = const Color(0xFFFDE047);
                      } else if (color == 'green')
                        c = const Color(0xFF86EFAC);
                      else
                        c = const Color(0xFFF9A8D4);

                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a note here (optional)...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (existingNote != null)
                        TextButton(
                          onPressed: () {
                            getIt<ReaderCubit>().removeNote(
                              existingNote.id!,
                              bookId,
                            );
                            Navigator.pop(bCtx);
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: () {
                          final note = Note(
                            id: existingNote?.id,
                            bookId: bookId,
                            chapterIndex: chapterIndex,
                            paragraphIndex: paragraphIndex,
                            selectedText: text,
                            noteText: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                            colorMark: selectedColor,
                            paragraphHash: hash,
                            createdAt:
                                existingNote?.createdAt ?? DateTime.now(),
                          );
                          getIt<ReaderCubit>().addNote(note);
                          Navigator.pop(bCtx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}









