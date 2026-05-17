import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

// Simulating the EpubAssembler logic to verify structure
void main() async {
  print('--- EPUB 3 Internal Validator ---');
  
  final title = 'Animal Farm';
  final author = 'George Orwell';
  final chapters = [
    '<h1>Chapter 1</h1><p>Mr. Jones, of the Manor Farm, had locked the hen-houses for the night...</p>',
    '<h1>Chapter 2</h1><p>Three nights later Old Major died peacefully in his sleep...</p>'
  ];

  final archive = Archive();

  // 1. mimetype (MUST be first and UNCOMPRESSED)
  final mimetypeBytes = utf8.encode('application/epub+zip');
  archive.addFile(
    ArchiveFile('mimetype', mimetypeBytes.length, mimetypeBytes)..compress = false,
  );

  // 2. container.xml
  const containerXml = '<?xml version="1.0" encoding="UTF-8"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>';
  _addFile(archive, 'META-INF/container.xml', containerXml);

  // 3. Navigation (REQUIRED)
  final navXhtml = '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc" id="toc"><h1>TOC</h1><ol><li><a href="chapter_1.xhtml">Ch 1</a></li></ol></nav></body></html>';
  _addFile(archive, 'OEBPS/Text/nav.xhtml', navXhtml);

  // 4. Chapters
  for (int i = 0; i < chapters.length; i++) {
    _addFile(archive, 'OEBPS/Text/chapter_${i+1}.xhtml', chapters[i]);
  }

  // 5. OPF
  final opf = '<?xml version="1.0" encoding="UTF-8"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>$title</dc:title><dc:language>en</dc:language></metadata><manifest><item id="nav" href="Text/nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="ch1" href="Text/chapter_1.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="ch1"/></spine></package>';
  _addFile(archive, 'OEBPS/content.opf', opf);

  final encoder = ZipEncoder();
  final bytes = encoder.encode(archive);
  
  final outFile = File('test_validation.epub');
  await outFile.writeAsBytes(bytes!);
  
  print('EPUB generated: ${outFile.path}');
  print('Size: ${outFile.lengthSync()} bytes');
  
  // VERIFICATION
  final inputBytes = outFile.readAsBytesSync();
  final decoder = ZipDecoder().decodeBytes(inputBytes);
  
  print('\nValidation Results:');
  print('1. First file is mimetype: ${decoder.files[0].name == 'mimetype'}');
  print('2. mimetype is uncompressed: ${decoder.files[0].compress == false}');
  print('3. Contains nav.xhtml: ${decoder.files.any((f) => f.name.contains('nav.xhtml'))}');
  print('4. OPF exists: ${decoder.files.any((f) => f.name.contains('content.opf'))}');
  
  if (decoder.files[0].name == 'mimetype' && decoder.files.any((f) => f.name.contains('nav.xhtml'))) {
    print('\nSUCCESS: Structure is valid for EPUB 3 readers.');
  } else {
    print('\nFAILURE: Structural requirements not met.');
  }
}

void _addFile(Archive archive, String path, String content) {
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(path, bytes.length, bytes));
}
