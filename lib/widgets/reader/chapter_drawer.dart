import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:epub_translate_meaning/models/parsed_book.dart';
import 'package:epub_translate_meaning/services/reader/reader_notifier.dart';
import 'package:epub_translate_meaning/services/database/database_service.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/bookmark.dart';
import 'package:intl/intl.dart';

class ChapterDrawer extends StatefulWidget {
  const ChapterDrawer({super.key});

  @override
  State<ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends State<ChapterDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();
  List<Bookmark> _bookmarks = [];
  Timer? _searchDebounce;
  List<ParsedParagraph> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final notifier = context.read<ReaderNotifier>();
    final bookmarks = await _db.getBookmarks(notifier.book.id);
    setState(() => _bookmarks = bookmarks);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final notifier = context.read<ReaderNotifier>();
      final results = await _db.searchInBook(notifier.book.id, query);
      setState(() => _searchResults = results);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ReaderNotifier>();
    final theme = Theme.of(context);
    final isDark = notifier.theme == ReaderTheme.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notifier.book.title,
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notifier.book.author != null)
                    Text(
                      notifier.book.author!,
                      style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
                    ),
                ],
              ),
            ),
            const Divider(),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search in book...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.6)),
                  filled: true,
                  fillColor: textColor.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final p = _searchResults[index];
                    return ListTile(
                      title: Text(p.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        notifier.goToParagraph(notifier.currentChapterIndex, p.index);
                      },
                    );
                  },
                ),
              )
            else ...[
              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: textColor.withOpacity(0.6),
                indicatorColor: Colors.blueAccent,
                tabs: const [Tab(text: 'Chapters'), Tab(text: 'Bookmarks')],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Chapters
                    _buildChapterList(notifier, textColor),
                    // Tab 2: Bookmarks
                    _buildBookmarkList(notifier, textColor),
                  ],
                ),
              ),
            ],

            // Statistics Section
            _buildStatsSection(textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterList(ReaderNotifier notifier, Color textColor) {
    return ListView.builder(
      itemCount: notifier.chapters.length,
      itemBuilder: (context, index) {
        final chapter = notifier.chapters[index];
        final isSelected = notifier.currentChapterIndex == index;
        return ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isSelected ? Colors.blueAccent : textColor.withOpacity(0.1),
            child: Text('${index + 1}', style: TextStyle(color: isSelected ? Colors.white : textColor, fontSize: 12)),
          ),
          title: Text(chapter.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text('~${(chapter.paragraphs.length * 10 / 200).ceil()} min read', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20) : null,
          tileColor: isSelected ? Colors.blueAccent.withOpacity(0.1) : null,
          onTap: () {
            Navigator.pop(context);
            notifier.goToChapter(index);
          },
        );
      },
    );
  }

  Widget _buildBookmarkList(ReaderNotifier notifier, Color textColor) {
    if (_bookmarks.isEmpty) {
      return Center(child: Text('No bookmarks yet', style: TextStyle(color: textColor.withOpacity(0.5))));
    }
    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final b = _bookmarks[index];
        return Dismissible(
          key: Key(b.id.toString()),
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) {
            _db.deleteBookmark(b.id.toString());
            _loadBookmarks();
          },
          child: ListTile(
            title: Text('Chapter ${b.chapterIndex + 1}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text('Added ${DateFormat.yMMMd().format(b.createdAt)}', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              notifier.goToParagraph(b.chapterIndex, b.paragraphIndex);
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: textColor.withOpacity(0.1)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Pages today', '12', Icons.today, textColor),
          _buildStatItem('Total pages', '450', Icons.auto_stories, textColor),
          _buildStatItem('Streak', '5d', Icons.local_fire_department, textColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color textColor) {
    return Column(
      children: [
        Icon(icon, color: Colors.orangeAccent, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }
}
