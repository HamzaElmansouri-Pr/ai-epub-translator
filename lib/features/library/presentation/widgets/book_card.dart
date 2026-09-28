import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'dart:ui';
import 'dart:io';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTogglePin;
  final VoidCallback? onSearchCover;
  final VoidCallback? onTapOverride;
  final VoidCallback? onLongPressOverride;

  const BookCard({
    super.key,
    required this.book,
    required this.onDelete,
    required this.onExport,
    this.onStatusChanged,
    this.onToggleFavorite,
    this.onTogglePin,
    this.onSearchCover,
    this.onTapOverride,
    this.onLongPressOverride,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapOverride ?? () {
        if (book.filePath.toLowerCase().endsWith('.pdf')) {
          context.push('/pdf-reader', extra: book);
        } else {
          context.push('/reader', extra: book);
        }
      },
      onLongPress: onLongPressOverride ?? onTogglePin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 15,
                    offset: const Offset(4, 8),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Book Cover Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                    child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                        ? (book.coverUrl!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: book.coverUrl!,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: (context, url, error) => _buildPlaceholderCover(),
                              )
                            : Container(
                                color: const Color(0xFF1A1A2E),
                                child: Image.file(
                                  File(book.coverUrl!),
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderCover(),
                                ),
                              ))
                        : _buildPlaceholderCover(),
                  ),
                  
                  // Pin Icon Badge
                  if (book.isPinned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: AppColors.background,
                        ),
                      ),
                    ),

                  // Book Spine Shadow (3D effect)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),

                  // Overlay Info (Subtle)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (book.status == 'reading')
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: 0.4,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                minHeight: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 16,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.author ?? "Unknown Author",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.secondary.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.1,
          child: Text(
            book.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
