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

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isExporting = false;
  String _selectedTab = 'All';

  final List<String> _tabs = [
    'All',
    'Want to Read',
    'Reading',
    'Finished',
    'Favorites'
  ];

  @override
  void initState() {
    super.initState();
    context.read<LibraryCubit>().loadBooks();
  }

  void _runExport(Book book, int start, int end) async {
    setState(() => _isExporting = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text('Exporting ${book.title}... This may take a moment.'),
            ),
          ],
        ),
        duration: const Duration(minutes: 5), // Keep alive during export
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final exportService = getIt<ExportService>();
      final file = await exportService.generateBilingualEpub(
        book.id,
        book.title,
        book.filePath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export Complete! Saved as ${file.path.split(RegExp(r'[/\\]')).last}',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View Files',
            textColor: Colors.white,
            onPressed: () {
              context.push('/exported-files');
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportDialog(BuildContext context, Book book) {
    int startChapter = 1;
    int endChapter = 10;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text(
                'Export Translated EPUB',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Generate bilingual EPUB for: ${book.title}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Start Chapter: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: startChapter.toDouble(),
                          min: 1,
                          max: 100,
                          activeColor: const Color(0xFF3B82F6),
                          onChanged: (val) =>
                              setState(() => startChapter = val.toInt()),
                        ),
                      ),
                      Text(
                        '$startChapter',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'End Chapter: ',
                        style: TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: endChapter.toDouble(),
                          min: 1,
                          max: 100,
                          activeColor: const Color(0xFF3B82F6),
                          onChanged: (val) => setState(
                            () => endChapter = val.toInt() >= startChapter
                                ? val.toInt()
                                : startChapter,
                          ),
                        ),
                      ),
                      Text(
                        '$endChapter',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _runExport(book, startChapter, endChapter);
                  },
                  child: const Text(
                    'Export',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
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
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.background,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'EPub Translate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: AppColors.border,
                height: 1,
                indent: 24,
                endIndent: 24,
              ),
              const SizedBox(height: 16),
              _buildDrawerItem(
                icon: Icons.library_books_rounded,
                title: 'My Library',
                onTap: () => Navigator.pop(context),
                isSelected: true,
              ),
              _buildDrawerItem(
                icon: Icons.folder_open_rounded,
                title: 'Exported Files',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/exported-files');
                },
              ),
              const Spacer(),
              _buildDrawerItem(
                icon: Icons.settings_rounded,
                title: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
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
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.1),
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
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: IconButton(
                            tooltip: 'Menu',
                            icon: const Icon(
                              Icons.menu_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Library',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Dive into your next adventure',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: IconButton(
                                tooltip: 'Settings',
                                icon: const Icon(
                                  Icons.settings_rounded,
                                  size: 26,
                                  color: Colors.white,
                                ),
                                onPressed: () => context.push('/settings'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                tooltip: 'Add EPUB Book',
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 28,
                                  color: Colors.white,
                                ),
                                onPressed: () => context
                                    .read<LibraryCubit>()
                                    .pickAndImportBook(),
                              ),
                            ),
                          ],
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
                                        color: Colors.white
                                            .withValues(alpha: 0.1),
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
                      if (_selectedTab == 'Want to Read') {
                        filteredBooks = filteredBooks.where((b) => b.status == 'want_to_read').toList();
                      } else if (_selectedTab == 'Reading') {
                        filteredBooks = filteredBooks.where((b) => b.status == 'reading').toList();
                      } else if (_selectedTab == 'Finished') {
                        filteredBooks = filteredBooks.where((b) => b.status == 'finished').toList();
                      } else if (_selectedTab == 'Favorites') {
                        filteredBooks = filteredBooks.where((b) => b.isFavorite).toList();
                      }

                      if (filteredBooks.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No books in this category.',
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 30,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final book = filteredBooks[index];
                            return GestureDetector(
                              onTap: () => context.push('/reader', extra: book),
                              child: BookCard(
                                book: book,
                                onDelete:
                                    () {}, // TODO: Implement delete in Cubit
                                onExport: () =>
                                    _showExportDialog(context, book),
                                onStatusChanged: (status) => context.read<LibraryCubit>().changeBookStatus(book, status),
                                onToggleFavorite: () => context.read<LibraryCubit>().toggleFavorite(book),                                  onSearchCover: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CoverSearchPage(book: book)),
                                  ),                              ),
                            );
                          }, childCount: filteredBooks.length),
                        ),
                      );
                    } else if (state is LibraryError) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Error: \${state.message}',
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
