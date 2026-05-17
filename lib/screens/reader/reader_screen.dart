import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:epub_translate_meaning/models/parsed_book.dart';
import 'package:epub_translate_meaning/services/reader/reader_notifier.dart';
import 'package:epub_translate_meaning/widgets/reader/paragraph_item.dart';
import 'package:epub_translate_meaning/widgets/reader/chapter_drawer.dart';
import 'package:epub_translate_meaning/widgets/reader/customization_panel.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  Timer? _uiHideTimer;
  Timer? _scrollDebounce;
  double _baseFontSize = 17.0;
  ReaderNotifier? _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save progress when app goes to background or is about to be killed
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _notifier?.saveProgressNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiHideTimer?.cancel();
    _scrollDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _notifier == null) return;
      final notifier = _notifier!;
      if (notifier.paragraphs.isEmpty) return;
      // Estimate current paragraph based on scroll offset
      int estimatedIndex = (_scrollController.offset / 100).floor().clamp(0, notifier.paragraphs.length - 1);
      notifier.updateParagraphIndex(estimatedIndex);
    });
  }

  void _resetUIHideTimer() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _notifier != null) {
        _notifier!.setUIVisibility(false);
      }
    });
  }

  void _handleParagraphTap(int index) {
    _resetUIHideTimer();
  }

  void _handleLongPress(int index) {
    HapticFeedback.mediumImpact();
  }

  Color _getBackgroundColor(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.light: return const Color(0xFFFAFAFA);
      case ReaderTheme.dark: return const Color(0xFF1A1A2E);
      case ReaderTheme.sepia: return const Color(0xFFF5EDD6);
    }
  }

  Color _getAccentColor(ReaderTheme theme) {
    return theme == ReaderTheme.dark ? Colors.blueAccent : Colors.orangeAccent;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final notifier = ReaderNotifier(book: widget.book, scrollController: _scrollController);
        _notifier = notifier;
        return notifier;
      },
      child: Consumer<ReaderNotifier>(
        builder: (context, notifier, child) {
          if (notifier.isLoading) {
            return Scaffold(
              backgroundColor: _getBackgroundColor(notifier.theme),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
              backgroundColor: _getBackgroundColor(notifier.theme),
              extendBodyBehindAppBar: true,
              drawer: const ChapterDrawer(),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: notifier.isUIVisible ? 1.0 : 0.0,
                child: AppBar(
                  backgroundColor: _getBackgroundColor(notifier.theme).withOpacity(0.8),
                  elevation: 0,
                  title: Text(
                    notifier.chapters.isNotEmpty ? notifier.chapters[notifier.currentChapterIndex].title : widget.book.title,
                    style: TextStyle(color: notifier.theme == ReaderTheme.dark ? Colors.white : Colors.black87, fontSize: 16),
                  ),
                  actions: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          '${(notifier.progressPercent * 100).toInt()}%',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.grey), 
                      onPressed: () => _showCustomizationPanel(context),
                    ),
                  ],
                ),
              ),
            ),
            body: PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  notifier.saveProgressNow();
                }
              },
              child: GestureDetector(
              onTap: () {
                notifier.toggleUIVisibility();
                if (notifier.isUIVisible) _resetUIHideTimer();
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -300) {
                  notifier.nextChapter();
                } else if (details.primaryVelocity! > 300) {
                  notifier.prevChapter();
                }
              },
              onScaleStart: (_) => _baseFontSize = notifier.fontSize,
              onScaleUpdate: (details) {
                double newSize = (_baseFontSize * details.scale).roundToDouble();
                if (newSize != notifier.fontSize && newSize >= 14 && newSize <= 28) {
                  notifier.setFontSize(newSize);
                  HapticFeedback.lightImpact();
                }
              },
              child: Stack(
                children: [
                  // Reading Progress Indicator at the very top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: notifier.progressPercent,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(_getAccentColor(notifier.theme)),
                      ),
                    ),
                  ),

                  ListView.builder(
                    controller: _scrollController,
                    itemCount: notifier.paragraphs.length,
                    cacheExtent: 2000,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top + 60, 0, 100),
                    itemBuilder: (context, index) => ParagraphItem(
                      paragraph: notifier.paragraphs[index],
                      index: index,
                      fontSize: notifier.fontSize,
                      fontFamily: notifier.fontFamily,
                      lineSpacing: notifier.lineSpacing,
                      textAlign: notifier.textAlign,
                      theme: notifier.theme,
                      onTap: () => _handleParagraphTap(index),
                      onLongPress: () => _handleLongPress(index),
                    ),
                  ),

                  // Bottom HUD
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: notifier.isUIVisible ? 0 : -100,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: _getBackgroundColor(notifier.theme).withOpacity(0.9),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.palette_outlined),
                            onPressed: () {
                              final nextTheme = ReaderTheme.values[(notifier.theme.index + 1) % ReaderTheme.values.length];
                              notifier.setTheme(nextTheme);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.text_fields),
                            onPressed: () => _showCustomizationPanel(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.list),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: notifier.currentChapterIndex > 0 ? () => notifier.prevChapter() : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: notifier.currentChapterIndex < notifier.chapters.length - 1 ? () => notifier.nextChapter() : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  void _showCustomizationPanel(BuildContext context) {
    final notifier = _notifier!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: notifier,
        child: DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.6,
          builder: (_, controller) => CustomizationPanel(scrollController: controller),
        ),
      ),
    );
  }
}
