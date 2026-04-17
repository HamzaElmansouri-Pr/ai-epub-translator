import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'dart:ui';
import 'package:epub_translate_meaning/features/reader/presentation/pages/reader_page.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onSearchCover;

  const BookCard({
    super.key,
    required this.book,
    required this.onDelete,
    required this.onExport,
    this.onStatusChanged,
    this.onToggleFavorite,
    this.onSearchCover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => ReaderPage(book: book)));
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.background,
          builder: (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: Text(book.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () {
                    Navigator.pop(context);
                    if (onToggleFavorite != null) onToggleFavorite!();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('Reading'),
                  selected: book.status == 'reading',
                  onTap: () {
                    Navigator.pop(context);
                    if (onStatusChanged != null) onStatusChanged!('reading');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.library_books),
                  title: const Text('Want to Read'),
                  selected: book.status == 'want_to_read',
                  onTap: () {
                    Navigator.pop(context);
                    if (onStatusChanged != null) onStatusChanged!('want_to_read');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Finished'),
                  selected: book.status == 'finished',
                  onTap: () {
                    Navigator.pop(context);
                    if (onStatusChanged != null) onStatusChanged!('finished');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Book', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: book.coverUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF2D3748),
                    child: Center(
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                )
              else
                // Premium Base Gradient (Simulated Cover Color)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                ),
              
              // Dark Gradient Overlay for Text Readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              // Content Layout
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (book.status == 'finished' 
                                        ? Colors.greenAccent 
                                        : (book.status == 'want_to_read' ? Colors.blueAccent : Colors.orangeAccent))
                                      .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Text(
                                book.status == 'finished' ? 'Finished' : (book.status == 'want_to_read' ? 'Want to Read' : 'Reading'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: book.status == 'finished' 
                                          ? Colors.greenAccent 
                                          : (book.status == 'want_to_read' ? Colors.blueAccent : Colors.orangeAccent)
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Quick Actions
                        Row(
                          children: [
                            GestureDetector(
                              onTap: onToggleFavorite,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: book.isFavorite ? Colors.amber.withValues(alpha: 0.2) : Colors.black26,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Icon(
                                  book.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: book.isFavorite ? Colors.amber : Colors.white70,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    
                    // Title and Author
                    Hero(
                      tag: 'book_title_\${book.id}',
                      child: Text(
                        book.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author ?? "Unknown Author",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Bottom Progress & Context Menu
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: book.status == 'finished' ? 1.0 : (book.status == 'want_to_read' ? 0.0 : 0.4),
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                book.status == 'finished' ? Colors.greenAccent : const Color(0xFF3B82F6),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 16),
                          ),
                          padding: EdgeInsets.zero,
                          offset: const Offset(0, -120),
                          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (value) {
                            if (value == 'export') onExport();
                            if (value == 'delete') onDelete();
                              if (value == 'search_cover' && onSearchCover != null) onSearchCover!();
                            if (value == 'reading' || value == 'want_to_read' || value == 'finished') {
                              if (onStatusChanged != null) onStatusChanged!(value);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(value: 'want_to_read', child: ListTile(leading: Icon(Icons.bookmark_border, color: Colors.white70), title: Text('Want to Read', style: TextStyle(color: Colors.white)))),
                            const PopupMenuItem(value: 'reading', child: ListTile(leading: Icon(Icons.menu_book, color: Colors.white70), title: Text('Reading', style: TextStyle(color: Colors.white)))),
                            const PopupMenuItem(value: 'finished', child: ListTile(leading: Icon(Icons.check_circle_outline, color: Colors.white70), title: Text('Finished', style: TextStyle(color: Colors.white)))),
                            const PopupMenuDivider(),
                              const PopupMenuItem(value: 'search_cover', child: ListTile(leading: Icon(Icons.image_search, color: Colors.amber), title: Text('Search Cover', style: TextStyle(color: Colors.amber)))),
                            const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.reply_rounded, color: Colors.blueAccent), title: Text('Export', style: TextStyle(color: Colors.blueAccent)))),
                            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Delete', style: TextStyle(color: Colors.redAccent)))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
