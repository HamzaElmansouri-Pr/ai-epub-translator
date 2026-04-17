import 'package:flutter/material.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reader_entities.dart';

class ParagraphTile extends StatelessWidget {
  final Paragraph paragraph;
  final Function(Paragraph) onTranslate;

  const ParagraphTile({
    super.key,
    required this.paragraph,
    required this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    if (paragraph.imageBytes != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Image.memory(paragraph.imageBytes!),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // Trigger analyze callback through onTranslate or specific callback
                // As a quick fix we use onTranslate too but handle inside reader
                onTranslate(paragraph);
              },
              icon: const Icon(Icons.image_search),
              label: const Text('Describe Image (Accessibility)'),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => onTranslate(paragraph),
      highlightColor: AppColors.primary.withAlpha(26),
      splashColor: AppColors.primary.withAlpha(51),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          paragraph.text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
