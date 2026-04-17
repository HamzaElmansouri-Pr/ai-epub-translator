import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';
import 'package:epub_translate_meaning/features/translation/presentation/cubit/translation_state.dart';
import 'package:shimmer/shimmer.dart';

class TranslationBubble extends StatelessWidget {
  final TranslationState state;
  final VoidCallback onClose;

  const TranslationBubble({
    super.key,
    required this.state,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(204), // 0.8 * 255
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.border.withAlpha(128),
            ), // 0.5 * 255
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Translation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state is TranslationLoading) _buildLoading(),
              if (state is TranslationSuccess)
                _buildContent(
                  (state as TranslationSuccess).translation.translation,
                ),
              if (state is TranslationError)
                _buildError((state as TranslationError).message),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String translation) {
    return Text(
      translation,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildError(String message) {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 32),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: AppColors.error)),
      ],
    );
  }
}
