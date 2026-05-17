import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_translate_meaning/models/parsed_book.dart';
import 'package:epub_translate_meaning/services/reader/reader_notifier.dart';

class ParagraphItem extends StatelessWidget {
  final ParsedParagraph paragraph;
  final int index;
  final double fontSize;
  final String fontFamily;
  final double lineSpacing;
  final String textAlign;
  final ReaderTheme theme;
  final bool isTranslated;
  final String? translationText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ParagraphItem({
    super.key,
    required this.paragraph,
    required this.index,
    required this.fontSize,
    required this.fontFamily,
    required this.lineSpacing,
    required this.textAlign,
    required this.theme,
    this.isTranslated = false,
    this.translationText,
    required this.onTap,
    required this.onLongPress,
  });

  Color _getTextColor() {
    switch (theme) {
      case ReaderTheme.light: return const Color(0xFF1A1A1A);
      case ReaderTheme.dark: return const Color(0xFFE8E8E8);
      case ReaderTheme.sepia: return const Color(0xFF3D2B1F);
    }
  }

  Color _getSecondaryTextColor() {
    switch (theme) {
      case ReaderTheme.light: return const Color(0xFF666666);
      case ReaderTheme.dark: return const Color(0xFF999999);
      case ReaderTheme.sepia: return const Color(0xFF7A5C44);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (paragraph.type == ParagraphType.image && paragraph.imagePath != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(paragraph.imagePath!),
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final bool isHeading = paragraph.type == ParagraphType.heading;
    final double effectiveFontSize = isHeading ? fontSize * 1.4 : fontSize;
    final FontWeight fontWeight = isHeading ? FontWeight.w700 : FontWeight.normal;
    final double topMargin = isHeading ? 32.0 : 10.0;

    final Widget mainContent = Column(
      crossAxisAlignment: paragraph.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isHeading && index == 0) ...[
          Divider(color: _getTextColor().withValues(alpha: 0.2), thickness: 1),
          const SizedBox(height: 16),
        ],
        SelectableText(
          paragraph.text,
          textAlign: textAlign == 'justify' ? TextAlign.justify : (paragraph.isRTL ? TextAlign.right : TextAlign.left),
          style: TextStyle(
            color: _getTextColor(),
            fontSize: effectiveFontSize,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            height: lineSpacing,
            fontStyle: paragraph.isOcrResult ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        if (isTranslated && translationText != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTextColor().withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: Colors.blueAccent, width: 3)),
              ),
              child: Text(
                translationText!,
                style: TextStyle(
                  color: _getSecondaryTextColor(),
                  fontSize: fontSize - 2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topMargin, 20, 10),
          child: Directionality(
            textDirection: paragraph.isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: mainContent,
          ),
        ),
      ),
    );
  }
}
