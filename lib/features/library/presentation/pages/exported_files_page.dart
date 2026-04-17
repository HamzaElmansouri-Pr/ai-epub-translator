import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/export_service.dart';
import 'package:epub_translate_meaning/features/library/domain/usecases/import_book.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

class ExportedFilesPage extends StatefulWidget {
  const ExportedFilesPage({super.key});

  @override
  State<ExportedFilesPage> createState() => _ExportedFilesPageState();
}

class _ExportedFilesPageState extends State<ExportedFilesPage> {
  List<File> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final exportService = getIt<ExportService>();
      final directoryPath = await exportService.getExportDirectory();
      final dir = Directory(directoryPath);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();
        _files = entities.whereType<File>().toList();
        // Sort by most recently modified
        _files.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        });
      }
    } catch (e) {
      debugPrint('Error loading exported files: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      setState(() {
        _files.remove(file);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
    }
  }

  void _shareFile(File file) {
    Share.shareXFiles([XFile(file.path)], text: 'Exported Book');
  }

  Future<void> _importFile(File file) async {
    try {
      final importBook = getIt<ImportBook>();
      final result = await importBook(file.path);

      if (!mounted) return;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to import: ${failure.message}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        (book) {
          context.read<LibraryCubit>().loadBooks();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imported to library successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing file: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Exported Files'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _files.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                final fileName = file.uri.pathSegments.last;
                final isPdf = fileName.endsWith('.pdf');                  final isMd = fileName.endsWith('.md');                final fileSize = (file.lengthSync() / 1024 / 1024)
                    .toStringAsFixed(2);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    onTap: () {
                      if (isPdf) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please use the Share button to open PDF files in an external viewer.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      // Create a mock book object for the EPUB
                      final book = Book(
                        id: 'exported_${DateTime.now().millisecondsSinceEpoch}',
                        title: fileName.replaceAll('.epub', ''),
                        author: 'Exported Translation',
                        filePath: file.path,
                        addedAt: DateTime.now(),
                      );
                      context.push('/reader', extra: book);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPdf
                            ? Colors.red.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : isMd
                                ? Icons.description_rounded
                                : Icons.auto_stories_rounded,
                        color: isPdf
                            ? Colors.redAccent
                            : isMd
                                ? Colors.greenAccent
                                : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      key: Key(fileName),
                      '$fileSize MB • ${isPdf ? 'PDF Document' : 'EPUB eBook'}',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isPdf)
                          IconButton(
                            icon: const Icon(
                              Icons.library_add_rounded,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Import to Library',
                            onPressed: () => _importFile(file),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.share_rounded,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Share / Download',
                          onPressed: () => _shareFile(file),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: AppColors.error,
                          ),
                          tooltip: 'Delete',
                          onPressed: () => _deleteFile(file),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No exported files yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wait until a book is completely translated.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.library_books_rounded),
            label: const Text('Go to Library'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              elevation: 8,
              shadowColor: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
