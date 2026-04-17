import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/entities/dictionary_entry.dart';
import 'package:epub_translate_meaning/features/dictionary/presentation/cubit/dictionary_cubit.dart';
import 'package:epub_translate_meaning/features/dictionary/presentation/cubit/dictionary_state.dart';

class DictionaryBottomSheet extends StatelessWidget {
  final String selectedWord;

  const DictionaryBottomSheet({super.key, required this.selectedWord});

  static void show(BuildContext context, String word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DictionaryBottomSheet(selectedWord: word),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DictionaryCubit>()..lookupWord(selectedWord),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: BlocBuilder<DictionaryCubit, DictionaryState>(
                  builder: (context, state) {
                    if (state is DictionaryLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                      );
                    } else if (state is DictionaryError) {
                      return _buildMessage('Error: ${state.message}', Icons.error_outline);
                    } else if (state is DictionaryNotFound) {
                      return _buildMessage(
                        'No definition found for "${state.word}".',
                        Icons.search_off,
                      );
                    } else if (state is DictionaryLoaded) {
                      return _buildResultList(state.entries, scrollController);
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildMessage(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultList(List<DictionaryEntry> entries, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    entry.word,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (entry.phonetic != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      entry.phonetic!,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              ...entry.meanings.map((meaning) => _buildMeaning(meaning)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMeaning(Meaning meaning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              meaning.partOfSpeech,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...meaning.definitions.map((def) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      Expanded(
                        child: Text(
                          def.definition,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  if (def.example != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                      child: Text(
                        '"${def.example!}"',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
