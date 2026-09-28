import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_state.dart';
import 'package:epub_translate_meaning/features/library/presentation/widgets/book_card.dart';

class PdfLibraryPage extends StatefulWidget {
  const PdfLibraryPage({super.key});

  @override
  State<PdfLibraryPage> createState() => _PdfLibraryPageState();
}

class _PdfLibraryPageState extends State<PdfLibraryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.woodGradient,
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PDF Collection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage your independent PDF library',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: AppColors.background),
                            onPressed: () => context.read<LibraryCubit>().pickAndImportPdf(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                BlocBuilder<LibraryCubit, LibraryState>(
                  builder: (context, state) {
                    if (state is LibraryLoading) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      );
                    } else if (state is LibraryLoaded) {
                      final pdfBooks = state.books.where((b) => b.filePath.toLowerCase().endsWith('.pdf')).toList();

                      if (pdfBooks.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                                const SizedBox(height: 24),
                                const Text(
                                  'No PDF books found.',
                                  style: TextStyle(color: Colors.white70, fontSize: 18),
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton.icon(
                                  onPressed: () => context.read<LibraryCubit>().pickAndImportPdf(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Import PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.6,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 30,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final book = pdfBooks[index];
                              return BookCard(
                                book: book,
                                onDelete: () => context.read<LibraryCubit>().deleteBook(book.id),
                                onExport: () {}, // Not needed for pure PDF
                                onStatusChanged: (status) => context.read<LibraryCubit>().changeBookStatus(book, status),
                              );
                            },
                            childCount: pdfBooks.length,
                          ),
                        ),
                      );
                    }
                    return const SliverFillRemaining(child: SizedBox.shrink());
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
