import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_state.dart';
import 'package:epub_translate_meaning/features/library/presentation/widgets/book_card.dart';
import 'package:epub_translate_meaning/features/library/presentation/pages/cover_search_page.dart';

import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isExporting = false;
  String _selectedTab = 'All';
  bool _showOnlyGenerated = false;

  String _sortOption = 'newest';
  bool _exportIsBilingual = true;
  bool _skipTranslation = true;

  final List<String> _tabs = [
    'All',
    'Want to Read',
    'Reading',
    'Finished',
    'Favorites',
  ];

  @override
  void initState() {
    super.initState();
    final settingsState = context.read<SettingsCubit>().state;
    List<String>? scanPaths;
    if (settingsState is SettingsLoaded) {
      scanPaths = settingsState.settings.autoImportFolderPaths;
    }
    context.read<LibraryCubit>().loadBooks(autoScanPaths: scanPaths);
  }

  void _runExport(Book book, {bool isBilingual = true, bool skipTranslation = true}) async {
    final state = context.read<SettingsCubit>().state;
    final targetLang = state is SettingsLoaded ? state.settings.targetLanguage : 'Arabic';
    final service = FlutterBackgroundService();

    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }

    service.invoke("startExport", {
      "bookId": book.id,
      "bookTitle": book.title,
      "originalFilePath": book.filePath,
      "targetLanguage": targetLang,
      "isPdf": false,
      "isMd": false,
      "useGoogle": false, // Default to Gemini for library instant export
      "isBilingual": isBilingual,
      "skipTranslation": skipTranslation, // Context: Library export is usually "As-Is"
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exporting in the background... check notifications for progress.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showExportDialog(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (ctx) {
        return BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settingsState) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text(
                    'Export EPUB',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Generate EPUB for: ${book.title}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Translate & Export (Quality Mode)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: !_skipTranslation,
                                  activeColor: const Color(0xFF3B82F6),
                                  onChanged: (val) => setState(() => _skipTranslation = !val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _skipTranslation 
                                ? 'Quickly packages existing translations (Fastest).'
                                : 'Scans and fixes missing or broken paragraphs (Best Quality).',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Bilingual (Original + ${settingsState is SettingsLoaded ? settingsState.settings.targetLanguage : "Arabic"}):',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Switch(
                            value: _exportIsBilingual,
                            activeColor: const Color(0xFF3B82F6),
                            onChanged: (val) => setState(() => _exportIsBilingual = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _runExport(
                          book, 
                          isBilingual: _exportIsBilingual,
                          skipTranslation: _skipTranslation,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _skipTranslation ? 'Quick Export' : 'Translate & Export',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBookItem(BuildContext context, Book book) {
    return AspectRatio(
      aspectRatio: 0.65,
      child: BookCard(
        book: book,
        onDelete: () => context.read<LibraryCubit>().deleteBook(book.id),
        onExport: () => _showExportDialog(context, book),
        onStatusChanged: (status) =>
            context.read<LibraryCubit>().changeBookStatus(book, status),
        onToggleFavorite: () =>
            context.read<LibraryCubit>().toggleFavorite(book),
        onTogglePin: () => context.read<LibraryCubit>().togglePin(book),
        onSearchCover: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CoverSearchPage(book: book),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 26,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Wood Texture/Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.woodGradient,
            ),
          ),

          Positioned(
            top: -150,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'The Grand Library',
                                style: Theme.of(context).textTheme.displayLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Curating your digital literary collection',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: AppColors.background),
                            onPressed: () => context.read<LibraryCubit>().pickAndImportBook(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final tab = _tabs[index];
                        final isSelected = tab == _selectedTab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = tab),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tab,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white60,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                BlocBuilder<LibraryCubit, LibraryState>(
                  builder: (context, state) {
                    if (state is LibraryLoading) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    } else if (state is LibraryLoaded) {
                      if (state.books.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 64,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Your library is empty.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap the + button to import an EPUB.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton.icon(
                                  onPressed: () => context
                                      .read<LibraryCubit>()
                                      .pickAndImportBook(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Book'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      List<Book> filteredBooks = state.books;
                      
                      if (_showOnlyGenerated) {
                        filteredBooks = filteredBooks.where((b) => b.filePath.contains('/converted/')).toList();
                      }

                      if (_selectedTab == 'Want to Read') {
                        filteredBooks = filteredBooks
                            .where((b) => b.status == 'want_to_read')
                            .toList();
                      } else if (_selectedTab == 'Reading') {
                        filteredBooks = filteredBooks
                            .where((b) => b.status == 'reading')
                            .toList();
                      } else if (_selectedTab == 'Finished') {
                        filteredBooks = filteredBooks
                            .where((b) => b.status == 'finished')
                            .toList();
                      } else if (_selectedTab == 'Favorites') {
                        filteredBooks = filteredBooks
                            .where((b) => b.isFavorite)
                            .toList();
                      }
                      if (_sortOption == 'title') {
                        filteredBooks.sort(
                          (a, b) => a.title.toLowerCase().compareTo(
                            b.title.toLowerCase(),
                          ),
                        );
                      } else if (_sortOption == 'author') {
                        filteredBooks.sort(
                          (a, b) => (a.author ?? 'Unknown')
                              .toLowerCase()
                              .compareTo((b.author ?? 'Unknown').toLowerCase()),
                        );
                      }

                      if (filteredBooks.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No books in this category.',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      final rowCount = (filteredBooks.length / 2).ceil();
                      
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, rowIndex) {
                              final firstBookIndex = rowIndex * 2;
                              final secondBookIndex = firstBookIndex + 1;
                              
                              return Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildBookItem(context, filteredBooks[firstBookIndex]),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: secondBookIndex < filteredBooks.length
                                            ? _buildBookItem(context, filteredBooks[secondBookIndex])
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // The Shelf
                                  Container(
                                    height: 12,
                                    margin: const EdgeInsets.only(bottom: 30),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3D2B1F),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF4D3B2F),
                                          const Color(0xFF2D1B10),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                            childCount: rowCount,
                          ),
                        ),
                      );
                    } else if (state is LibraryError) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Error: ${state.message}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      );
                    }
                    return const SliverFillRemaining(child: SizedBox.shrink());
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
