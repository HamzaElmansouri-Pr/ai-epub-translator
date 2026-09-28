import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';
import 'dart:ui' hide Paragraph;
import 'dart:async';
import 'dart:typed_data';
import 'package:epub_translate_meaning/features/library/data/repositories/file_reader_stub.dart'
    if (dart.library.io) 'package:epub_translate_meaning/core/utils/file_reader_native.dart'
    if (dart.library.html) 'package:epub_translate_meaning/core/utils/file_reader_web.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
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
import 'package:epub_translate_meaning/core/utils/app_logger.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_state.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/note.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reading_progress.dart';
import 'package:epub_translate_meaning/features/reader/data/models/reading_progress_model.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:epub_translate_meaning/features/reader/presentation/widgets/inline_translation_paragraph.dart';
import 'package:epub_translate_meaning/features/reader/presentation/widgets/reader_drawer.dart';
import 'package:epub_translate_meaning/features/reader/domain/repositories/reader_repository.dart';
import 'package:dartz/dartz.dart' hide Column, Stack, State;
import 'package:archive/archive.dart';
class ReaderPage extends StatefulWidget {
  final Book book;

  const ReaderPage({super.key, required this.book});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  EpubController? _epubController;
  bool _isHudVisible = false;
  final Map<String, GlobalKey> _paragraphKeys = {};
  List<String> _currentChapterParagraphs = [];
  bool _autoExpandTranslations = false;
  bool _isPlayingTts = false;
  int _totalChapters = 1;
  late final SettingsCubit _settingsCubit;
  Timer? _debounceTimer;
  bool _isSaving = false;
  bool _isRestoringPosition = true;
  bool _isDocumentLoaded = false;
  String? _savedCfi;
  int? _savedChapterIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsCubit = getIt<SettingsCubit>()..loadSettings();
    getIt<ReaderCubit>().loadBook(widget.book.filePath, widget.book.id);
    _initController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Flush any pending debounced save immediately instead of cancelling
    _debounceTimer?.cancel();
    if (_epubController != null) {
      // Capture all progress data BEFORE nulling the controller
      _saveProgressSync();
      final controller = _epubController;
      _epubController = null;
      Future.delayed(const Duration(milliseconds: 200), () {
        controller?.dispose();
      });
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveProgressDirect();
    }
  }

  // --- SAVE ---
  void _saveCurrentProgress() {
    if (_isRestoringPosition) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () => _saveProgressDirect());
  }

  /// Capture progress data synchronously from the controller and fire off a DB save.
  /// Used in dispose() where we must read controller state before it's nulled.
  void _saveProgressSync() {
    if (_isRestoringPosition) {
      AppLogger.log('_saveProgressSync aborted: currently restoring position');
      return;
    }
    AppLogger.log('_saveProgressSync called');
    if (_epubController == null) {
      AppLogger.log('_saveProgressSync aborted: _epubController is null');
      return;
    }
    final current = _epubController!.currentValue;
    if (current == null) {
      AppLogger.log('_saveProgressSync aborted: currentValue is null');
      return;
    }

    String? cfi;
    try {
      cfi = _epubController!.generateEpubCfi();
    } catch (e) {
      AppLogger.log('generateEpubCfi() failed during save: $e');
    }

    final progressPercent = _totalChapters > 1
        ? (current.chapterNumber / (_totalChapters - 1)).clamp(0.0, 1.0)
        : 0.0;

    final model = ReadingProgressModel(
      bookId: widget.book.id,
      chapterIndex: current.chapterNumber,
      paragraphIndex: current.paragraphNumber,
      scrollPosition: current.position.itemLeadingEdge,
      progressPercent: progressPercent,
      format: 'epub',
      epubCfi: cfi,
      updatedAt: DateTime.now(),
    );

    // Fire-and-forget — the data is already captured synchronously above
    _isSaving = true;
    getIt<LocalBookDataSource>().saveReadingProgress(model).then((_) {
      AppLogger.log('Progress saved: ch=${model.chapterIndex} p=${model.paragraphIndex} cfi=${cfi != null ? "yes" : "null"}');
      _isSaving = false;
    }).catchError((e) {
      AppLogger.log('ERROR saving progress: $e');
      _isSaving = false;
    });
  }

  /// Save progress directly to DB using the ePub CFI string for exact position.
  void _saveProgressDirect() {
    if (_isRestoringPosition) {
      AppLogger.log('_saveProgressDirect aborted: currently restoring position');
      return;
    }
    AppLogger.log('_saveProgressDirect called');
    if (_epubController == null) {
      AppLogger.log('_saveProgressDirect aborted: _epubController is null');
      return;
    }
    final current = _epubController!.currentValue;
    if (current == null) {
      AppLogger.log('_saveProgressDirect aborted: currentValue is null');
      return;
    }

    String? cfi;
    try {
      cfi = _epubController!.generateEpubCfi();
    } catch (e) {
      AppLogger.log('generateEpubCfi() failed: $e');
    }

    final progressPercent = _totalChapters > 1
        ? (current.chapterNumber / (_totalChapters - 1)).clamp(0.0, 1.0)
        : 0.0;

    final model = ReadingProgressModel(
      bookId: widget.book.id,
      chapterIndex: current.chapterNumber,
      paragraphIndex: current.paragraphNumber,
      scrollPosition: current.position.itemLeadingEdge,
      progressPercent: progressPercent,
      format: 'epub',
      epubCfi: cfi,
      updatedAt: DateTime.now(),
    );

    _isSaving = true;
    getIt<LocalBookDataSource>().saveReadingProgress(model).then((_) {
      AppLogger.log('Progress saved direct: ch=${model.chapterIndex} p=${model.paragraphIndex} cfi=${cfi != null ? "yes" : "null"}');
      _isSaving = false;
    }).catchError((e) {
      AppLogger.log('ERROR saving progress direct: $e');
      _isSaving = false;
    });
  }

  // --- RESTORE ---
  Future<void> _initController() async {
    final localDataSource = getIt<LocalBookDataSource>();
    Uint8List bookBytes;
    final cachedBytes = localDataSource.getEpubBytes(widget.book.id);
    if (cachedBytes == null) {
      final fileBytes = await readFileBytes(widget.book.filePath);
      await localDataSource.cacheEpubBytes(widget.book.id, fileBytes);
      bookBytes = fileBytes;
    } else {
      bookBytes = cachedBytes;
    }

    EpubBook? epubBook;
    Uint8List currentBytes = bookBytes;
    int maxRetries = 5;
    
    for (int i = 0; i < maxRetries; i++) {
      try {
        epubBook = await EpubReader.readBook(currentBytes);
        break; // Success!
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('not found in archive')) {
          final match = RegExp(r'file (.*?) not found').firstMatch(errorStr);
          if (match != null) {
            final missingFileName = match.group(1)!;
            debugPrint('Repairing EPUB: adding dummy file for $missingFileName');
            try {
              final archive = ZipDecoder().decodeBytes(currentBytes);
              archive.addFile(ArchiveFile(missingFileName, 0, <int>[]));
              currentBytes = Uint8List.fromList(ZipEncoder().encode(archive) ?? currentBytes);
              continue; // Retry with repaired bytes
            } catch (archiveErr) {
              debugPrint('Failed to repair EPUB archive: $archiveErr');
              break;
            }
          }
        }
        
        debugPrint('EpubReader failed in reader_page: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open this EPUB: ${errorStr.replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
            ),
          );
          if (context.canPop()) context.pop();
        }
        return;
      }
    }

    if (epubBook == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this EPUB after repair attempts.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        if (context.canPop()) context.pop();
      }
      return;
    }

    // Count total flattened chapters (including sub-chapters) for accurate progress
    int flattenedCount = 0;
    for (var ch in (epubBook.Chapters ?? [])) {
      flattenedCount++;
      flattenedCount += (ch.SubChapters?.length ?? 0) as int;
    }
    _totalChapters = flattenedCount > 0 ? flattenedCount : 1;

    _totalChapters = flattenedCount > 0 ? flattenedCount : 1;

    // Load saved progress for position restoration
    final savedProgress = await localDataSource.getReadingProgress(widget.book.id);
    _savedCfi = savedProgress?.epubCfi;
    _savedChapterIndex = savedProgress?.chapterIndex;

    AppLogger.log('Restoring progress: cfi=${_savedCfi != null ? "yes" : "null"}, ch=$_savedChapterIndex, totalChapters=$_totalChapters');

    if (mounted) {
      setState(() {
        // Pass the saved CFI to the controller — epub_view handles the rest
        // If CFI is null but we have a chapter index, we'll jump after document loads
        _epubController = EpubController(
          document: Future.value(epubBook),
          epubCfi: _savedCfi,
        );
        
        // Listen to actual controller value changes rather than relying on scroll notifications
        _epubController!.currentValueListenable.addListener(() {
           _saveCurrentProgress();
        });
      });

      // Fallback: we will handle jumps in onDocumentLoaded instead of here
    }
  }

  Color _getBackgroundColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'sepia': return const Color(0xFFF4ECD8);
      case 'dark': return const Color(0xFF0F172A);
      case 'grey': return const Color(0xFF262626);
      default: return Colors.white;
    }
  }

  TextStyle _getTextStyle(UserSettings settings) {
    return TextStyle(
      fontSize: settings.readerFontSize,
      fontFamily: settings.readerFontFamily,
      color: settings.readerBackgroundColor.toLowerCase() == 'dark' ? Colors.white : Colors.black87,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final settings = settingsState is SettingsLoaded ? settingsState.settings : const UserSettings(tier: AppTier.starter, targetLanguage: 'Arabic');
        final bgColor = _getBackgroundColor(settings.readerBackgroundColor);

        return Scaffold(
          backgroundColor: bgColor,
          endDrawer: _epubController == null ? null : ReaderDrawer(
            epubController: _epubController!,
            onJumpToParagraph: _scrollToParagraph,
          ),
          body: PopScope(
            canPop: !_isHudVisible,
            onPopInvokedWithResult: (didPop, result) {
              debugPrint('PopScope invoked, didPop=$didPop');
              if (didPop) {
                _saveProgressDirect();
                return;
              }
              if (_isHudVisible && mounted) {
                setState(() => _isHudVisible = false);
              }
            },
            child: Listener(
              onPointerDown: (_) {
                if (_isRestoringPosition && _isDocumentLoaded) {
                  _isRestoringPosition = false;
                  AppLogger.log('Restoration phase ended by user interaction');
                }
              },
              child: Stack(
                children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 300) {
                      if (!_isHudVisible && mounted) setState(() => _isHudVisible = true);
                    } else if (details.primaryVelocity! < -300) {
                      if (_isHudVisible && mounted) setState(() => _isHudVisible = false);
                    }
                  },
                  onDoubleTap: () {
                    if (_epubController == null) return;
                    setState(() => _isHudVisible = !_isHudVisible);
                  },
                  child: _epubController == null
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) _saveCurrentProgress();
                            return false;
                          },
                          child: EpubView(
                            controller: _epubController!,
                            onDocumentLoaded: (doc) {
                              AppLogger.log('onDocumentLoaded triggered');
                              if (mounted) setState(() => _isDocumentLoaded = true);
                              Future.delayed(const Duration(milliseconds: 400), () {
                                if (!mounted || _epubController == null) return;
                                if (_savedCfi != null && _savedCfi!.isNotEmpty) {
                                  AppLogger.log('Forcing gotoEpubCfi in onDocumentLoaded');
                                  try {
                                    _epubController!.gotoEpubCfi(_savedCfi!);
                                    
                                    // Verify if jump succeeded after a short delay
                                    Future.delayed(const Duration(milliseconds: 600), () {
                                      if (!mounted || _epubController == null) return;
                                      final currentCh = _epubController!.currentValue?.chapterNumber;
                                      
                                      // If we expected a chapter > 1, but we are still at chapter 1 or 0, the CFI silently failed
                                      if (_savedChapterIndex != null && _savedChapterIndex! > 1 && (currentCh == null || currentCh <= 1)) {
                                        AppLogger.log('gotoEpubCfi silently failed (expected $_savedChapterIndex, got $currentCh). Falling back to jumpTo');
                                        try {
                                          _epubController!.jumpTo(index: _savedChapterIndex!);
                                        } catch (_) {}
                                      }
                                    });
                                  } catch (e) {
                                    AppLogger.log('gotoEpubCfi failed: $e');
                                    if (_savedChapterIndex != null && _savedChapterIndex! > 0) {
                                      _epubController!.jumpTo(index: _savedChapterIndex!);
                                      AppLogger.log('Fell back to chapter index jump');
                                    }
                                  }
                                } else if (_savedChapterIndex != null && _savedChapterIndex! > 0) {
                                  try {
                                    _epubController!.jumpTo(index: _savedChapterIndex!);
                                    AppLogger.log('Jumped directly to chapter index');
                                  } catch (e) {
                                    AppLogger.log('jumpTo chapter index failed: $e');
                                  }
                                }
                              });
                            },
                            builders: EpubViewBuilders<DefaultBuilderOptions>(
                              options: const DefaultBuilderOptions(),
                              chapterBuilder: (context, builders, document, chapters, paragraphs, index, chapterIndex, paragraphIndex, onExternalLinkPressed) {
                                if (paragraphs.isEmpty) return Container();
                                if (index == 0 && mounted) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final currentTexts = paragraphs.map((p) => p.element.text).toList();
                                    if (_currentChapterParagraphs.length != currentTexts.length) {
                                      _currentChapterParagraphs = currentTexts;
                                    }
                                  });
                                }

                                return BlocBuilder<ReaderCubit, ReaderState>(
                                  builder: (context, readerState) {
                                    final rawTxt = paragraphs[index].element.text.trim();
                                    final hash = HashUtils.hashText(rawTxt);
                                    Color? highlightColor;
                                    bool isPinned = false;

                                    if (readerState is ReaderLoaded) {
                                      final note = readerState.notes.where((n) => n.paragraphHash == hash).firstOrNull;
                                      if (note != null) {
                                        switch (note.colorMark) {
                                          case 'yellow': highlightColor = const Color(0xFFFDE047).withValues(alpha: 0.3); break;
                                          case 'green': highlightColor = const Color(0xFF86EFAC).withValues(alpha: 0.3); break;
                                          case 'pink': highlightColor = const Color(0xFFF9A8D4).withValues(alpha: 0.3); break;
                                        }
                                      }
                                      isPinned = readerState.bookmarks.any((b) => b.chapterIndex == chapterIndex && b.paragraphIndex == paragraphIndex);
                                    }

                                    final pKey = _paragraphKeys.putIfAbsent('c${chapterIndex}p$paragraphIndex', () => GlobalKey());
                                    return Stack(
                                      key: pKey,
                                      children: [
                                        InlineTranslationParagraph(
                                          htmlData: paragraphs[index].element.outerHtml,
                                          rawText: paragraphs[index].element.text,
                                          bookId: widget.book.id,
                                          settings: settings,
                                          backgroundColor: highlightColor,
                                          epubBook: document,
                                          onLongPress: () => _showAnnotationMenu(context, widget.book.id, chapterIndex, paragraphIndex, rawTxt, hash, readerState is ReaderLoaded ? readerState.notes.where((n) => n.paragraphHash == hash).firstOrNull : null),
                                          autoExpand: _autoExpandTranslations,
                                          onLinkTap: (url) => onExternalLinkPressed(url),
                                        ),
                                        if (isPinned)
                                          Positioned(
                                            right: 0,
                                            top: 2,
                                            child: GestureDetector(
                                              onTap: () => context.read<ReaderCubit>().toggleBookmark(Bookmark(bookId: widget.book.id, chapterIndex: chapterIndex, paragraphIndex: paragraphIndex, title: 'Pinned Spot', createdAt: DateTime.now())),
                                              child: Column(
                                                children: [
                                                  Container(width: 14, height: 24, decoration: const BoxDecoration(color: Color(0xFFE23636), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4))), child: const Icon(Icons.bookmark, size: 10, color: Colors.white)),
                                                  const SizedBox(height: 2),
                                                  const Icon(Icons.close, size: 10, color: Colors.redAccent),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                ),

                // Top HUD
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
                            IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white), onPressed: () { _saveProgressDirect(); Navigator.pop(context); }),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.book.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), Text(widget.book.author ?? 'Unknown Author', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12))])),
                            IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () => context.push('/settings')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom HUD
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  bottom: _isHudVisible ? 0 : -140,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.8),
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildHudAction(icon: Icons.translate, label: 'Export', onTap: () => _showExportBottomSheet(context, settings, false, targetLanguage: settings.targetLanguage)),
                                _buildHudAction(icon: Icons.list, label: 'Chapters', onTap: () => Scaffold.of(context).openEndDrawer()),
                                _buildHudAction(icon: _isPlayingTts ? Icons.pause_circle : Icons.play_circle, label: 'Listen', onTap: () => _playTts()),
                                _buildHudAction(icon: _autoExpandTranslations ? Icons.visibility : Icons.visibility_off, label: 'Reveal', onTap: () => setState(() => _autoExpandTranslations = !_autoExpandTranslations)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_epubController != null)
                              ValueListenableBuilder(
                                valueListenable: _epubController!.currentValueListenable,
                                builder: (context, value, child) {
                                  final dynamic val = value;
                                  final currentChapter = (val?.chapterNumber as num?)?.toInt() ?? 0;
                                  final progress = _totalChapters > 1 ? currentChapter / (_totalChapters - 1) : 0.0;
                                  return Column(
                                    children: [
                                      LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: Colors.white.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6))),
                                      const SizedBox(height: 8),
                                      Text('Chapter ${currentChapter + 1} of $_totalChapters', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bookmark Ribbon
                if (_epubController != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 70,
                    right: 0,
                    child: ValueListenableBuilder(
                      valueListenable: _epubController!.currentValueListenable,
                      builder: (context, value, child) {
                        return BlocBuilder<ReaderCubit, ReaderState>(
                          builder: (context, state) {
                            if (state is! ReaderLoaded) return const SizedBox.shrink();
                            final dynamic val = value;
                            final currentChapter = (val?.chapterNumber as num?)?.toInt() ?? 0;
                            final currentParagraph = (val?.paragraphNumber as num?)?.toInt() ?? 0;
                            final hasBookmark = state.bookmarks.any((b) => b.chapterIndex == currentChapter && (b.paragraphIndex - currentParagraph).abs() < 5);
                            if (!hasBookmark) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.9),
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(-2, 4))],
                              ),
                              child: const Icon(Icons.bookmark, color: Colors.amberAccent, size: 28),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildHudAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  void _showExportBottomSheet(BuildContext context, UserSettings settings, bool isPdf, {bool isMd = false, required String targetLanguage}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export Options', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.file_download, color: Color(0xFF3B82F6)),
              title: const Text('Download Original', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                getIt<ExportService>().generateEpub(widget.book.id, widget.book.title, widget.book.filePath, targetLanguage: targetLanguage, isBilingual: true);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _playTts() async {
    if (_isPlayingTts) {
      await getIt<TtsService>().stop();
      setState(() => _isPlayingTts = false);
    } else {
      if (_currentChapterParagraphs.isEmpty) return;
      setState(() => _isPlayingTts = true);
      await getIt<TtsService>().speak(_currentChapterParagraphs.join(' '));
      setState(() => _isPlayingTts = false);
    }
  }

  void _scrollToParagraph(int chapterIndex, int paragraphIndex, {int retryCount = 0}) {
    if (_epubController == null || retryCount > 10 || !mounted) return;
    if (retryCount == 0) {
      try {
        _epubController!.jumpTo(index: chapterIndex);
      } catch (_) {
        // Scroll controller not yet attached — retry after delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _scrollToParagraph(chapterIndex, paragraphIndex, retryCount: retryCount + 1);
        });
        return;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 100 + (retryCount * 50)));
      if (!mounted) return;
      final key = _paragraphKeys['c${chapterIndex}p$paragraphIndex'];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
      } else if (mounted) {
        _scrollToParagraph(chapterIndex, paragraphIndex, retryCount: retryCount + 1);
      }
    });
  }

  void _showAnnotationMenu(BuildContext context, String bookId, int chapterIndex, int paragraphIndex, String text, String hash, Note? existingNote) {
    String selectedColor = existingNote?.colorMark ?? 'yellow';
    final TextEditingController noteController = TextEditingController(text: existingNote?.noteText ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Highlight & Note', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(bCtx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic))),
                  const SizedBox(height: 20),
                  const Text('Color', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildColorOption('yellow', const Color(0xFFFDE047), selectedColor, (c) => setModalState(() => selectedColor = c)),
                      _buildColorOption('green', const Color(0xFF86EFAC), selectedColor, (c) => setModalState(() => selectedColor = c)),
                      _buildColorOption('pink', const Color(0xFFF9A8D4), selectedColor, (c) => setModalState(() => selectedColor = c)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: noteController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Add a note...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (existingNote != null)
                        TextButton(onPressed: () { getIt<ReaderCubit>().removeNote(existingNote.id!, bookId); Navigator.pop(bCtx); }, child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                      ElevatedButton(
                        onPressed: () {
                          final note = Note(id: existingNote?.id, bookId: bookId, chapterIndex: chapterIndex, paragraphIndex: paragraphIndex, selectedText: text, noteText: noteController.text.trim().isEmpty ? null : noteController.text.trim(), colorMark: selectedColor, paragraphHash: hash, createdAt: existingNote?.createdAt ?? DateTime.now());
                          getIt<ReaderCubit>().addNote(note);
                          Navigator.pop(bCtx);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Save', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorOption(String color, Color value, String current, Function(String) onTap) {
    final isSelected = color == current;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32, height: 32,
        decoration: BoxDecoration(color: value, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 2) : null, boxShadow: isSelected ? [BoxShadow(color: value.withOpacity(0.4), blurRadius: 8)] : null),
      ),
    );
  }
}
