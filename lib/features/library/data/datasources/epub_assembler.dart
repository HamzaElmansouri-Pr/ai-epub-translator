import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@lazySingleton
class EpubAssembler {
  final Uuid _uuid = const Uuid();

  /// Assembles an EPUB 3 file from a list of chapters (HTML content)
  Future<Uint8List> assembleEpub({
    required String title,
    required String author,
    required List<String> chapters, // Each string is HTML content for a chapter
    String language = 'en',
  }) async {
    final archive = Archive();
    final isRtl = language == 'ar' || language == 'he' || language == 'fa';

    // 1. mimetype (MUST be first and UNCOMPRESSED)
    final mimetypeBytes = utf8.encode('application/epub+zip');
    archive.addFile(
      ArchiveFile('mimetype', mimetypeBytes.length, mimetypeBytes)..compress = false,
    );

    // 2. META-INF/container.xml
    const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    _addFileToArchive(archive, 'META-INF/container.xml', containerXml);

    // 3. OEBPS/Styles/style.css
    final cssContent = '''
body { 
  font-family: sans-serif; 
  line-height: 1.5; 
  margin: 5%; 
  direction: ${isRtl ? 'rtl' : 'ltr'};
  text-align: ${isRtl ? 'right' : 'left'};
}
h1, h2, h3 { color: #2c3e50; }
p { margin-bottom: 1em; }
''';
    _addFileToArchive(archive, 'OEBPS/Styles/style.css', cssContent);

    // 4. OEBPS/Text/chapter_N.xhtml
    final List<String> chapterFiles = [];
    for (int i = 0; i < chapters.length; i++) {
      final fileName = 'chapter_${i + 1}.xhtml';
      chapterFiles.add(fileName);
      
      final xhtml = _wrapInXhtml(title, chapters[i], language: language, isRtl: isRtl);
      _addFileToArchive(archive, 'OEBPS/Text/$fileName', xhtml);
    }

    // 5. OEBPS/Text/nav.xhtml (REQUIRED for EPUB 3)
    final navXhtml = _generateNav(title, chapterFiles, language: language, isRtl: isRtl);
    _addFileToArchive(archive, 'OEBPS/Text/nav.xhtml', navXhtml);

    // 6. OEBPS/content.opf
    final opfContent = _generateOpf(
      title: title,
      author: author,
      chapterFiles: chapterFiles,
      language: language,
    );
    _addFileToArchive(archive, 'OEBPS/content.opf', opfContent);

    // Encode as ZIP
    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    return Uint8List.fromList(bytes!);
  }

  void _addFileToArchive(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _wrapInXhtml(String title, String bodyContent, {String language = 'en', bool isRtl = false}) {
    return '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="$language" xml:lang="$language" dir="${isRtl ? 'rtl' : 'ltr'}">
<head>
  <title>$title</title>
  <link rel="stylesheet" type="text/css" href="../Styles/style.css"/>
</head>
<body>
  $bodyContent
</body>
</html>''';
  }

  String _generateNav(String title, List<String> chapterFiles, {String language = 'en', bool isRtl = false}) {
    final navItems = StringBuffer();
    for (int i = 0; i < chapterFiles.length; i++) {
      navItems.writeln('        <li><a href="${chapterFiles[i]}">Chapter ${i + 1}</a></li>');
    }

    return '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="$language" xml:lang="$language" dir="${isRtl ? 'rtl' : 'ltr'}">
<head>
  <title>$title - Navigation</title>
</head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>${isRtl ? 'جدول المحتويات' : 'Table of Contents'}</h1>
    <ol>
$navItems    </ol>
  </nav>
</body>
</html>''';
  }

  String _generateOpf({
    required String title,
    required String author,
    required List<String> chapterFiles,
    String language = 'en',
  }) {
    final bookId = 'urn:uuid:${_uuid.v4()}';
    final manifestBuffer = StringBuffer();
    final spineBuffer = StringBuffer();

    // Add CSS to manifest
    manifestBuffer.writeln('    <item id="style" href="Styles/style.css" media-type="text/css"/>');
    
    // Add Nav to manifest (REQUIRED property)
    manifestBuffer.writeln('    <item id="nav" href="Text/nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>');

    for (int i = 0; i < chapterFiles.length; i++) {
      final id = 'ch${i + 1}';
      final href = 'Text/${chapterFiles[i]}';
      manifestBuffer.writeln('    <item id="$id" href="$href" media-type="application/xhtml+xml"/>');
      spineBuffer.writeln('    <itemref idref="$id"/>');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">$bookId</dc:identifier>
    <dc:title>$title</dc:title>
    <dc:language>$language</dc:language>
    <dc:creator>$author</dc:creator>
    <meta property="dcterms:modified">${DateTime.now().toUtc().toIso8601String().split('.')[0]}Z</meta>
  </metadata>
  <manifest>
${manifestBuffer.toString()}  </manifest>
  <spine>
${spineBuffer.toString()}  </spine>
</package>''';
  }
}
