import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_cubit.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_state.dart';
import 'package:epub_translate_meaning/features/settings/domain/entities/user_settings.dart';
import 'package:epub_translate_meaning/features/dictionary/presentation/widgets/dictionary_bottom_sheet.dart';
import 'package:epub_translate_meaning/core/services/tts_service.dart';

class InlineTranslationParagraph extends StatefulWidget {
  final String htmlData;
  final String rawText;
  final String bookId;
  final UserSettings settings;
  final bool autoExpand;
  final void Function(String)? onLinkTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;

  const InlineTranslationParagraph({
    super.key,
    required this.htmlData,
    required this.rawText,
    required this.bookId,
    required this.settings,
    this.autoExpand = false,
    this.onLinkTap,
    this.onLongPress,
    this.backgroundColor,
  });

  @override
  State<InlineTranslationParagraph> createState() =>
      _InlineTranslationParagraphState();
}

class _InlineTranslationParagraphState
    extends State<InlineTranslationParagraph> {
  bool _localExpanded = false;

  bool get _isExpanded => widget.autoExpand || _localExpanded;

  void _toggleTranslation() {
    if (widget.rawText.trim().isEmpty) return;
    if (widget.autoExpand) return; // Cannot collapse if globally expanded
    setState(() {
      _localExpanded = !_localExpanded;
    });
  }

  Color _getTextColor(String name) {
    switch (name) {
      case 'Light':
        return const Color(0xFF1E293B);
      case 'Sepia':
        return const Color(0xFF433422);
      case 'Dark':
      default:
        return Colors.white.withOpacity(0.9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleTranslation,
          onLongPress: widget.onLongPress,
          child: SelectionArea(
            contextMenuBuilder: (BuildContext context, SelectableRegionState selectableRegionState) {
              final List<ContextMenuButtonItem> buttonItems = selectableRegionState.contextMenuButtonItems;
              buttonItems.add(
                ContextMenuButtonItem(
                  label: 'Define',
                  onPressed: () {
                    final selection = selectableRegionState.textEditingValue.selection;
                    final text = selectableRegionState.textEditingValue.text;
                    if (selection.isValid && !selection.isCollapsed) {
                      final selectedText = selection.textInside(text);
                      ContextMenuController.removeAny();
                      DictionaryBottomSheet.show(context, selectedText);
                    }
                  },
                ),
              );
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: selectableRegionState.contextMenuAnchors,
                buttonItems: buttonItems,
              );
            },
            child: Html(
              data: widget.htmlData,
            onLinkTap: (String? url, Map<String, String> attributes, element) {
              if (url != null && widget.onLinkTap != null) {
                widget.onLinkTap!(url);
              }
            },
            style: {
              'html': Style(
                padding: HtmlPaddings.only(
                  top: 0,
                  right: 16,
                  bottom: _isExpanded ? 0 : 8,
                  left: 16,
                ),
                fontSize: FontSize(widget.settings.readerFontSize),
                lineHeight: LineHeight(1.6),
                fontFamily: widget.settings.readerFontFamily == 'OpenDyslexic'
                    ? null
                    : GoogleFonts.getFont(
                        widget.settings.readerFontFamily,
                      ).fontFamily,
                color: _getTextColor(widget.settings.readerBackgroundColor),
              ),
            },
          ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
              top: 8,
            ),
            child: BlocProvider<TranslationCubit>(
              create: (context) =>
                  getIt<TranslationCubit>()..translateParagraph(
                    widget.rawText.trim(),
                    widget.settings.targetLanguage,
                    bookId: widget.bookId,
                  ),
              child: BlocBuilder<TranslationCubit, TranslationState>(
                builder: (context, state) {
                  if (state is TranslationLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    );
                  } else if (state is TranslationSuccess) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up, color: Color(0xFF93C5FD), size: 20),
                                tooltip: 'Play Original',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () {
                                  getIt<TtsService>().speak(widget.rawText);
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.translate, color: Color(0xFF93C5FD), size: 20),
                                tooltip: 'Play Translation',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () {
                                  getIt<TtsService>().speak(state.translation.translation);
                                },
                              ),
                            ],
                          ),
                          Text(
                            state.translation.translation,
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (state is TranslationError ||
                      state is TranslationExhausted) {
                    final isQuota =
                        state is TranslationExhausted ||
                        (state is TranslationError &&
                            state.message.contains('exhausted'));
                    final message = isQuota
                        ? 'All literary APIs limit reached!'
                        : (state is TranslationError ? state.message : 'Error');

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              if (!isQuota)
                                IconButton(
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    context
                                        .read<TranslationCubit>()
                                        .translateParagraph(
                                          widget.rawText.trim(),
                                          widget.settings.targetLanguage,
                                          bookId: widget.bookId,
                                        );
                                  },
                                ),
                            ],
                          ),
                          if (isQuota) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // Normally we should push context to Settings
                                    // For now we'll do nothing, or pop back to library then settings
                                    // but let's just let it be descriptive
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Go to Settings to add an API key.',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.key, size: 16),
                                  label: const Text('Add API Key'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white30,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    context
                                        .read<TranslationCubit>()
                                        .translateParagraph(
                                          widget.rawText.trim(),
                                          widget.settings.targetLanguage,
                                          bookId: widget.bookId,
                                          useGoogleTranslate: true,
                                        );
                                  },
                                  icon: const Icon(Icons.g_translate, size: 16),
                                  label: const Text(
                                    'Use Free Google Translate',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
      ],
    );
  }
}

