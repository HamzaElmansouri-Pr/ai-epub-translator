$content = Get-Content -Path 'lib\features\library\presentation\widgets\book_card.dart' -Raw
$oldString = @"
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Placeholder for cover
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.surface, AppColors.background],
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 60,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              // Main content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (book.status == 'want_to_read')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Want to Read', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                            )
                          else if (book.status == 'finished')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Finished', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Reading', style: TextStyle(fontSize: 10, color: Colors.orangeAccent)),
                            ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: onToggleFavorite,
                                child: Icon(
                                  book.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: book.isFavorite ? Colors.amber : Colors.white.withValues(alpha: 0.4),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: Colors.white.withValues(alpha: 0.6), size: 20),
                                onSelected: onStatusChanged,
                                color: AppColors.background,
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(value: 'want_to_read', child: Text('Want to Read', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'reading', child: Text('Reading', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'finished', child: Text('Finished', style: TextStyle(color: Colors.white))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        book.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.author ?? "Unknown Author",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              // Frosted glass overlay actions
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.0,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onExport,
                            child: Icon(
                              Icons.share_rounded,
                              size: 20,
                              color: AppColors.primary.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onDelete,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
