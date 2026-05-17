import 'package:flutter_test/flutter_test.dart';
import 'package:epub_translate_meaning/core/utils/hash_utils.dart';

void main() {
  group('HashUtils - Hashing Consistency', () {
    test('Different whitespace variations should produce the same hash', () {
      final texts = [
        'Hello World',
        'hello world',
        '  Hello   World  ',
        'Hello\nWorld',
        'Hello\r\nWorld',
        'Hello\tWorld',
        'Hello \u00A0 World', // Non-breaking space
      ];

      final hashes = texts.map((t) => HashUtils.hashText(t)).toList();
      final firstHash = hashes[0];

      print('Testing text results:');
      for (int i = 0; i < texts.length; i++) {
        print('"${texts[i].replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t')}" -> ${hashes[i]}');
        expect(hashes[i], equals(firstHash), reason: 'Text variation $i failed');
      }
    });

    test('Normalization logic for fallback matching', () {
      final originalDbText = 'Original   Text\nWith Newline';
      final currentExportText = 'original text with newline';
      
      final normOriginal = originalDbText.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final normCurrent = currentExportText.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      
      expect(normOriginal, equals(normCurrent));
    });
  });
}
