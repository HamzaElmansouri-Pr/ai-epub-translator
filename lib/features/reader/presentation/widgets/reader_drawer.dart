import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:epub_translate_meaning/features/reader/presentation/cubit/reader_state.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReaderDrawer extends StatefulWidget {
  final EpubController epubController;
  
  const ReaderDrawer({super.key, required this.epubController});

  @override
  State<ReaderDrawer> createState() => _ReaderDrawerState();
}

class _ReaderDrawerState extends State<ReaderDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF3B82F6),
              labelColor: const Color(0xFF3B82F6),
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: 'TOC'),
                Tab(icon: Icon(Icons.bookmark), text: 'Bookmarks'),
                Tab(icon: Icon(Icons.edit_note), text: 'Notes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTocTab(context),
                  _buildBookmarksTab(context),
                  _buildNotesTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTocTab(BuildContext context) {
    return EpubViewTableOfContents(
      controller: widget.epubController,
      itemBuilder: (context, index, chapter, itemCount) {
        return ListTile(
          title: Text(
            chapter.title?.trim() ?? 'Chapter ${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            widget.epubController.scrollTo(index: chapter.startIndex ?? 0);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildBookmarksTab(BuildContext context) {
    return BlocBuilder<ReaderCubit, ReaderState>(
      builder: (context, state) {
        if (state is ReaderLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ReaderLoaded) {
          if (state.bookmarks.isEmpty) {
            return const Center(
              child: Text(
                'No bookmarks yet.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            itemCount: state.bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = state.bookmarks[index];
              return ListTile(
                title: Text(
                  (bookmark.title ?? 'Bookmark'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  bookmark.createdAt.toString().split('.')[0],
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    context.read<ReaderCubit>().removeBookmark(bookmark.id!, bookmark.bookId);
                  },
                ),
                onTap: () {
                  widget.epubController.jumpTo(
                    index: bookmark.paragraphIndex,
                    /* alignment: bookmark.scrollPosition... wait not supported */
                  );
                  Navigator.pop(context);
                },
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildNotesTab(BuildContext context) {
    return BlocBuilder<ReaderCubit, ReaderState>(
      builder: (context, state) {
        if (state is ReaderLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ReaderLoaded) {
          if (state.notes.isEmpty) {
            return const Center(
              child: Text(
                'No notes or highlights yet.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            itemCount: state.notes.length,
            itemBuilder: (context, index) {
              final note = state.notes[index];
              return ListTile(
                title: Text(
                  (note.noteText?.isEmpty ?? true) ? 'Highlight' : (note.noteText ?? ''),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Color: ${note.colorMark}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    context.read<ReaderCubit>().removeNote(note.id!, note.bookId);
                  },
                ),
                onTap: () {
                  widget.epubController.jumpTo(
                    index: note.paragraphIndex,
                  );
                  Navigator.pop(context);
                },
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }
}




