import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:epub_translate_meaning/features/library/data/datasources/epub_assembler.dart';
import 'package:archive/archive.dart';

void main() {
  late EpubAssembler assembler;

  setUp(() {
    assembler = EpubAssembler();
  });

  test('assembleEpub should create a valid EPUB structure', () async {
    final bytes = await assembler.assembleEpub(
      title: 'Test Book',
      author: 'Test Author',
      chapters: ['<h1>Chapter 1</h1><p>Hello world</p>'],
    );

    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Check mimetype (MUST be first)
    expect(archive.files.first.name, 'mimetype');
    expect(utf8.decode(archive.files.first.content as List<int>), 'application/epub+zip');

    // 2. Check container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    expect(containerFile, isNotNull);
    expect(utf8.decode(containerFile!.content as List<int>), contains('OEBPS/content.opf'));

    // 3. Check content.opf
    final opfFile = archive.findFile('OEBPS/content.opf');
    expect(opfFile, isNotNull);
    final opfContent = utf8.decode(opfFile!.content as List<int>);
    expect(opfContent, contains('<dc:title>Test Book</dc:title>'));
    expect(opfContent, contains('<dc:creator>Test Author</dc:creator>'));
    expect(opfContent, contains('chapter_1.xhtml'));

    // 4. Check chapter content
    final chapterFile = archive.findFile('OEBPS/Text/chapter_1.xhtml');
    expect(chapterFile, isNotNull);
    expect(utf8.decode(chapterFile!.content as List<int>), contains('<h1>Chapter 1</h1>'));
  });
}
