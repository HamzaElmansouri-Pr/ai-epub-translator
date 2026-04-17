$content = Get-Content -Path 'lib\features\reader\presentation\pages\reader_page.dart' -Raw
$oldString = @"
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  top: _isHudVisible ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        height: 100,
                        padding: const EdgeInsets.only(
                          top: 40,
                          left: 16,
                          right: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.6),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.book.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlayingTts ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                color: _isPlayingTts ? Colors.redAccent : Colors.white,
                              ),
                              onPressed: () {
                                if (_isPlayingTts) {
                                  getIt<EpubAudioHandler>().pause();
                                  if (mounted) setState(() => _isPlayingTts = false);
                                } else {
                                  if (_currentChapterParagraphs.isEmpty) return;
                                  setState(() => _isPlayingTts = true);
                                  getIt<EpubAudioHandler>().setAudiobookData(widget.book.title, 'Chapter', _currentChapterParagraphs, 0); getIt<EpubAudioHandler>().play().then((_) {
                                    if (mounted) setState(() => _isPlayingTts = false);
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => _showExportBottomSheet(
                                context,
                                settings,
                                true,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.description_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => _showExportBottomSheet(
                                context,
                                settings,
                                false,
                                isMd: true,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.auto_awesome,
                                color: Colors.amberAccent,
                              ),
                              onPressed: () => _showAutoTranslateBottomSheet(
                                context,
                                settings,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.text_format,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _showAppearanceBottomSheet(context),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.book_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () => _showExportBottomSheet(
                                context,
                                settings,
                                false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
