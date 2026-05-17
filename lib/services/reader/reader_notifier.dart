import 'dart:async';
import 'package:flutter/material.dart';
import 'package:epub_translate_meaning/models/parsed_book.dart';
import 'package:epub_translate_meaning/services/database/database_service.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/local_book_datasource.dart';
import 'package:epub_translate_meaning/features/reader/data/models/reading_progress_model.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderTheme { light, dark, sepia }

class ReaderNotifier extends ChangeNotifier {
  final Book book;
  final DatabaseService _db = DatabaseService();
  late final LocalBookDataSource _localDs;

  List<ParsedChapter> _chapters = [];
  List<ParsedParagraph> _paragraphs = [];
  int _currentChapterIndex = 0;
  int _currentParagraphIndex = 0;
  int _totalParagraphsAllChapters = 0;
  double _fontSize = 17.0;
  double _lineSpacing = 1.6;
  String _textAlign = 'left';
  String _fontFamily = 'Serif';
  ReaderTheme _theme = ReaderTheme.light;
  bool _isUIVisible = true;
  bool _isLoading = true;
  Timer? _autoSaveTimer;
  bool _disposed = false;

  final Map<int, List<ParsedParagraph>> _chapterCache = {};
  ScrollController? scrollController;

  ReaderNotifier({required this.book, this.scrollController}) {
    _localDs = getIt<LocalBookDataSource>();
    _init();
  }

  // Getters
  List<ParsedChapter> get chapters => _chapters;
  List<ParsedParagraph> get paragraphs => _paragraphs;
  int get currentChapterIndex => _currentChapterIndex;
  int get currentParagraphIndex => _currentParagraphIndex;
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  String get textAlign => _textAlign;
  String get fontFamily => _fontFamily;
  ReaderTheme get theme => _theme;
  bool get isUIVisible => _isUIVisible;
  bool get isLoading => _isLoading;

  double get progressPercent {
    if (_totalParagraphsAllChapters == 0) return 0.0;
    int paragraphsBefore = 0;
    for (int i = 0; i < _currentChapterIndex && i < _chapters.length; i++) {
      paragraphsBefore += _chapters[i].paragraphs.length;
    }
    return ((paragraphsBefore + _currentParagraphIndex) / _totalParagraphsAllChapters).clamp(0.0, 1.0);
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('reader_font_size') ?? 17.0;
    _lineSpacing = prefs.getDouble('reader_line_spacing') ?? 1.6;
    _textAlign = prefs.getString('reader_text_align') ?? 'left';
    _fontFamily = prefs.getString('reader_font_family') ?? 'Serif';
    _theme = ReaderTheme.values[prefs.getInt('reader_theme') ?? 0];
    
    _chapters = await _db.getChapters(book.id);
    _totalParagraphsAllChapters = _chapters.fold(0, (sum, c) => sum + c.paragraphs.length);
    
    // If chapter metadata is empty (paragraphs count = 0), estimate from DB
    if (_totalParagraphsAllChapters == 0 && _chapters.isNotEmpty) {
      // Load paragraph counts from DB for each chapter
      int total = 0;
      for (int i = 0; i < _chapters.length; i++) {
        final chapterId = '${book.id}_$i';
        final paras = await _db.getParagraphsForChapter(chapterId);
        total += paras.length;
        // Update the chapter's paragraph list for count reference
        _chapters[i] = ParsedChapter(
          index: _chapters[i].index,
          title: _chapters[i].title,
          paragraphs: paras,
        );
      }
      _totalParagraphsAllChapters = total;
    }
    
    // Restore position from shared DB
    final savedProgress = await _localDs.getReadingProgress(book.id);
    if (savedProgress != null) {
      _currentChapterIndex = savedProgress.chapterIndex;
      _currentParagraphIndex = savedProgress.paragraphIndex;
    } else {
      // Fall back to PDF-specific DB
      final pos = await _db.getReadingPosition(book.id);
      if (pos != null) {
        _currentChapterIndex = pos['chapterIndex'] ?? 0;
        _currentParagraphIndex = pos['paragraphIndex'] ?? 0;
      }
    }

    if (_chapters.isNotEmpty) {
      await goToChapter(_currentChapterIndex, scrollToIndex: _currentParagraphIndex);
    } else {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> goToChapter(int index, {int scrollToIndex = 0}) async {
    if (index < 0 || index >= _chapters.length) return;
    
    _currentChapterIndex = index;
    _currentParagraphIndex = scrollToIndex;

    if (!_chapterCache.containsKey(index)) {
      _isLoading = true;
      _safeNotify();
      final chapterId = '${book.id}_$index';
      _paragraphs = await _db.getParagraphsForChapter(chapterId);
      _chapterCache[index] = _paragraphs;
      _isLoading = false;
    } else {
      _paragraphs = _chapterCache[index]!;
    }

    _updateCache(index);
    _safeNotify();

    _safeScrollTo(scrollToIndex);

    _scheduleAutoSave();
  }

  void _safeScrollTo(int scrollToIndex, {int retries = 0}) {
    if (scrollController == null || retries > 10) return;
    if (scrollController!.hasClients) {
      try {
        scrollController!.jumpTo(scrollToIndex * 100.0);
      } catch (_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _safeScrollTo(scrollToIndex, retries: retries + 1);
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        _safeScrollTo(scrollToIndex, retries: retries + 1);
      });
    }
  }

  void _updateCache(int currentIndex) {
    // Keep N-1, N, N+1
    final keysToRemove = _chapterCache.keys.where((k) => (k - currentIndex).abs() > 1).toList();
    for (var k in keysToRemove) _chapterCache.remove(k);

    // Preload neighbors
    if (currentIndex > 0 && !_chapterCache.containsKey(currentIndex - 1)) {
      _preloadChapter(currentIndex - 1);
    }
    if (currentIndex < _chapters.length - 1 && !_chapterCache.containsKey(currentIndex + 1)) {
      _preloadChapter(currentIndex + 1);
    }
  }

  Future<void> _preloadChapter(int index) async {
    final chapterId = '${book.id}_$index';
    final paras = await _db.getParagraphsForChapter(chapterId);
    _chapterCache[index] = paras;
  }

  Future<void> goToParagraph(int chapterIndex, int paragraphIndex) async {
    await goToChapter(chapterIndex, scrollToIndex: paragraphIndex);
  }

  Future<void> goToNextChapter() => goToChapter(_currentChapterIndex + 1);
  Future<void> goToPreviousChapter() => goToChapter(_currentChapterIndex - 1);

  // --- Progress Saving ---

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 5), () {
      saveProgressNow();
    });
  }

  /// Force-save current progress to shared DB. Call on dispose/lifecycle.
  Future<void> saveProgressNow() async {
    if (_disposed) return;
    try {
      final progress = ReadingProgressModel(
        bookId: book.id,
        chapterIndex: _currentChapterIndex,
        paragraphIndex: _currentParagraphIndex,
        scrollPosition: scrollController?.hasClients == true ? scrollController!.offset : 0.0,
        progressPercent: progressPercent,
        format: 'pdf',
        updatedAt: DateTime.now(),
      );
      await _localDs.saveReadingProgress(progress);
      // Also save to PDF-specific DB for backward compat
      await _db.saveReadingPosition(book.id, _currentChapterIndex, _currentParagraphIndex);
    } catch (e) {
      debugPrint('ReaderNotifier.saveProgressNow ERROR: $e');
    }
  }

  // --- Preference Setters ---

  void setFontSize(double size) {
    _fontSize = size.clamp(14.0, 28.0);
    SharedPreferences.getInstance().then((prefs) => prefs.setDouble('reader_font_size', _fontSize));
    _safeNotify();
  }

  void setLineSpacing(double spacing) {
    _lineSpacing = spacing.clamp(1.2, 2.2);
    SharedPreferences.getInstance().then((prefs) => prefs.setDouble('reader_line_spacing', _lineSpacing));
    _safeNotify();
  }

  void setTextAlign(String align) {
    _textAlign = align;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('reader_text_align', _textAlign));
    _safeNotify();
  }

  void setFontFamily(String family) {
    _fontFamily = family;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('reader_font_family', _fontFamily));
    _safeNotify();
  }

  void setTheme(ReaderTheme theme) {
    _theme = theme;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('reader_theme', _theme.index));
    _safeNotify();
  }

  void toggleUIVisibility() {
    _isUIVisible = !_isUIVisible;
    _safeNotify();
  }

  void setUIVisibility(bool visible) {
    _isUIVisible = visible;
    _safeNotify();
  }

  void updateParagraphIndex(int index) {
    if (_currentParagraphIndex != index) {
      _currentParagraphIndex = index;
      _scheduleAutoSave();
      _safeNotify();
    }
  }

  Future<void> nextChapter() async {
    if (_currentChapterIndex < _chapters.length - 1) {
      _currentParagraphIndex = 0;
      await goToChapter(_currentChapterIndex + 1);
    }
  }

  Future<void> prevChapter() async {
    if (_currentChapterIndex > 0) {
      _currentParagraphIndex = 0;
      await goToChapter(_currentChapterIndex - 1);
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoSaveTimer?.cancel();
    // Fire-and-forget final save
    saveProgressNow();
    super.dispose();
  }
}
