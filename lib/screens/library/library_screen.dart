import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/services/database/database_service.dart';
import 'package:epub_translate_meaning/services/import/import_service.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final DatabaseService _db = DatabaseService();
  final ImportService _importService = ImportService();
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final books = await _db.getAllBooks();
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  Future<void> _handleImport() async {
    await _importService.importPdf(
      context, 
      onComplete: (book) {
        _loadBooks();
        context.push('/pdf-reader', extra: book);
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My PDF Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _books.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadBooks,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 3 : 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _books.length,
                itemBuilder: (context, index) => BookCard(
                  book: _books[index],
                  onTap: () => context.push('/pdf-reader', extra: _books[index]),
                  onLongPress: () => _showBookOptions(_books[index]),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleImport,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No PDFs yet', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Tap the + button to import your first book', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }

  void _showBookOptions(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('Book Info', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text('Share PDF', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete Book', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await _db.deleteBook(book.id);
                if (await File(book.filePath).exists()) await File(book.filePath).delete();
                if (book.coverUrl != null && await File(book.coverUrl!).exists()) await File(book.coverUrl!).delete();
                _loadBooks();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BookCard({
    super.key, 
    required this.book, 
    required this.onTap, 
    required this.onLongPress
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Cover Image
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: book.coverUrl != null 
                      ? Container(
                          color: const Color(0xFF1A1A2E),
                          child: Image.file(
                            File(book.coverUrl!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            alignment: Alignment.center,
                          ),
                        )
                      : Container(
                          color: Colors.grey[800], 
                          child: const Icon(Icons.book, size: 40, color: Colors.white24)
                        ),
                  ),
                ),
                // Progress Bar at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: book.readingProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            book.author ?? 'Unknown Author',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
