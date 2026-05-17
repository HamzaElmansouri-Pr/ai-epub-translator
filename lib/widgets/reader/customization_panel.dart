import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:epub_translate_meaning/services/reader/reader_notifier.dart';

class CustomizationPanel extends StatelessWidget {
  final ScrollController scrollController;

  const CustomizationPanel({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ReaderNotifier>();
    final isDark = notifier.theme == ReaderTheme.dark;
    final bgColor = isDark ? const Color(0xFF25254B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        controller: scrollController,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sample Text Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'The quick brown fox jumps over the lazy dog.',
              textAlign: notifier.textAlign == 'justify' ? TextAlign.justify : TextAlign.left,
              style: _getReaderTextStyle(notifier),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Font Size
          _buildSectionHeader('Font Size', textColor),
          Row(
            children: [
              IconButton(
                onPressed: notifier.fontSize > 14 ? () => notifier.setFontSize(notifier.fontSize - 1) : null,
                icon: Icon(Icons.text_fields, size: 18, color: textColor),
              ),
              Expanded(
                child: Slider(
                  value: notifier.fontSize,
                  min: 14,
                  max: 28,
                  divisions: 14,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    notifier.setFontSize(val);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              IconButton(
                onPressed: notifier.fontSize < 28 ? () => notifier.setFontSize(notifier.fontSize + 1) : null,
                icon: Icon(Icons.text_fields, size: 28, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Font Family
          _buildSectionHeader('Font Family', textColor),
          Wrap(
            spacing: 8,
            children: [
              _buildFontChip(notifier, 'Sans', textColor),
              _buildFontChip(notifier, 'Serif', textColor),
              _buildFontChip(notifier, 'Dyslexic', textColor),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3: Line Spacing
          _buildSectionHeader('Line Spacing', textColor),
          Row(
            children: [
              Icon(Icons.format_line_spacing, size: 20, color: textColor.withOpacity(0.6)),
              Expanded(
                child: Slider(
                  value: notifier.lineSpacing,
                  min: 1.2,
                  max: 2.2,
                  divisions: 5,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    notifier.setLineSpacing(val);
                  },
                ),
              ),
              Text('${notifier.lineSpacing.toStringAsFixed(1)}x', style: TextStyle(color: textColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),

          // Section 4: Themes
          _buildSectionHeader('Theme', textColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildThemeCircle(notifier, ReaderTheme.light, Colors.white, Colors.black26),
              _buildThemeCircle(notifier, ReaderTheme.dark, const Color(0xFF1A1A2E), Colors.transparent),
              _buildThemeCircle(notifier, ReaderTheme.sepia, const Color(0xFFF5EDD6), Colors.orangeAccent.withOpacity(0.3)),
            ],
          ),
          const SizedBox(height: 24),

          // Section 5: Alignment
          _buildSectionHeader('Alignment', textColor),
          Row(
            children: [
              _buildAlignButton(notifier, 'left', Icons.format_align_left, textColor),
              const SizedBox(width: 12),
              _buildAlignButton(notifier, 'justify', Icons.format_align_justify, textColor),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildFontChip(ReaderNotifier notifier, String family, Color textColor) {
    final isSelected = notifier.fontFamily == family;
    return ChoiceChip(
      label: Text(family),
      selected: isSelected,
      onSelected: (val) {
        if (val) notifier.setFontFamily(family);
      },
      selectedColor: Colors.blueAccent,
      labelStyle: TextStyle(color: isSelected ? Colors.white : textColor),
      backgroundColor: textColor.withOpacity(0.05),
    );
  }

  Widget _buildThemeCircle(ReaderNotifier notifier, ReaderTheme theme, Color color, Color borderColor) {
    final isSelected = notifier.theme == theme;
    return GestureDetector(
      onTap: () => notifier.setTheme(theme),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.blueAccent : borderColor, width: isSelected ? 3 : 1),
          boxShadow: [
            if (isSelected) BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
          ],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : null,
      ),
    );
  }

  Widget _buildAlignButton(ReaderNotifier notifier, String align, IconData icon, Color textColor) {
    final isSelected = notifier.textAlign == align;
    return IconButton(
      onPressed: () => notifier.setTextAlign(align),
      icon: Icon(icon, color: isSelected ? Colors.blueAccent : textColor.withOpacity(0.4)),
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  TextStyle _getReaderTextStyle(ReaderNotifier notifier) {
    TextStyle style;
    switch (notifier.fontFamily) {
      case 'Sans': style = GoogleFonts.inter(); break;
      case 'Serif': style = GoogleFonts.merriweather(); break;
      case 'Dyslexic': style = const TextStyle(fontFamily: 'OpenDyslexic'); break;
      default: style = GoogleFonts.merriweather();
    }
    return style.copyWith(
      fontSize: notifier.fontSize,
      height: notifier.lineSpacing,
      color: notifier.theme == ReaderTheme.dark ? Colors.white : Colors.black87,
    );
  }
}
