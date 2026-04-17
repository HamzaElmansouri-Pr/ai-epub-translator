import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epub_translate_meaning/features/library/presentation/cubit/library_cubit.dart';
import 'package:epub_translate_meaning/core/theme/app_colors.dart';

class TestImportButton extends StatelessWidget {
  const TestImportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _testImport(context),
        icon: const Icon(Icons.science_rounded),
        label: const Text('Test Import: Thinking, Fast and Slow'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _testImport(BuildContext context) async {
    try {
      final cubit = context.read<LibraryCubit>();

      // Load from assets
      final data = await rootBundle.load(
        'books epub/Thinking, Fast and Slow.epub',
      );
      final bytes = data.buffer.asUint8List();

      // Import directly from bytes
      await cubit.importBookFromBytes('Thinking, Fast and Slow', bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test import successful!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test import failed: $e')));
      }
    }
  }
}
