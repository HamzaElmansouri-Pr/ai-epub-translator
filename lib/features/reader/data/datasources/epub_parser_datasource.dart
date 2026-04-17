import 'package:flutter/foundation.dart';
import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/utils/hash_utils.dart';
import 'package:epub_translate_meaning/core/utils/isolate_utils.dart';
import 'package:epub_translate_meaning/core/storage/in_memory_book_store.dart';
import 'package:epub_translate_meaning/features/reader/domain/entities/reader_entities.dart';
import 'file_reader_stub.dart'
    if (dart.library.io) 'package:epub_translate_meaning/core/utils/file_reader_native.dart'
    if (dart.library.html) 'package:epub_translate_meaning/core/utils/file_reader_web.dart';

abstract class EpubParserDataSource {
  Future<List<Chapter>> parseEpub(String filePath);
  Future<List<Chapter>> parseEpubFromBytes(Uint8List bytes);
}

@LazySingleton(as: EpubParserDataSource)
class EpubParserDataSourceImpl implements EpubParserDataSource {
  final InMemoryBookStore memoryStore;

  EpubParserDataSourceImpl(this.memoryStore);

  @override
  Future<List<Chapter>> parseEpub(String filePath) async {
    if (kIsWeb || filePath.startsWith('memory://')) {
      final allBooks = memoryStore.getBooks();
      final match = allBooks.where((b) => b.filePath == filePath).firstOrNull;
      if (match != null) {
        final bytes = memoryStore.getBytes(match.id);
        if (bytes != null) return parseEpubFromBytes(bytes);
      }
      return const [];
    }

    try {
      final bytes = await readFileBytes(filePath);
      return parseEpubFromBytes(bytes);
    } catch (e) {
      return const [];
    }
  }

  @override
  Future<List<Chapter>> parseEpubFromBytes(Uint8List bytes) async {
    return await IsolateUtils.runInIsolate(() async {
      final epubBook = await EpubReader.readBook(bytes);
      final List<Chapter> chapters = [];
      int chapterIndex = 0;

      final chaptersList = epubBook.Chapters ?? [];
      for (var epubChapter in chaptersList) {
        final paragraphs = _extractParagraphsFromHtml(
          epubChapter.HtmlContent ?? '',
          epubBook,
        );
        if (paragraphs.isNotEmpty) {
          chapters.add(
            Chapter(
              index: chapterIndex++,
              title: epubChapter.Title ?? 'Chapter $chapterIndex',
              paragraphs: paragraphs,
            ),
          );
        }
        if (epubChapter.SubChapters != null) {
          for (var subChapter in epubChapter.SubChapters!) {
            final subParagraphs = _extractParagraphsFromHtml(
              subChapter.HtmlContent ?? '',
              epubBook,
            );
            if (subParagraphs.isNotEmpty) {
              chapters.add(
                Chapter(
                  index: chapterIndex++,
                  title: subChapter.Title ?? 'Subchapter $chapterIndex',
                  paragraphs: subParagraphs,
                ),
              );
            }
          }
        }
      }
      return chapters;
    });
  }

  static List<Paragraph> _extractParagraphsFromHtml(
    String htmlContent,
    EpubBook epubBook,
  ) {
    final document = html_parser.parse(htmlContent);
    final elements = document.body?.children ?? [];
    final List<Paragraph> paragraphs = [];
    int pIndex = 0;

    void processElement(html_dom.Element element) {
      if (element.localName == 'img') {
        final src = element.attributes['src'];
        if (src != null) {
          final fileName = src.split('/').last;
          if (epubBook.Content?.Images?.containsKey(fileName) == true) {
            final imageContent = epubBook.Content!.Images![fileName];
            if (imageContent != null && imageContent.Content != null) {
              paragraphs.add(
                Paragraph(
                  id: HashUtils.hashText('img_$fileName'),
                  text: '[Image: $fileName]',
                  imageBytes: Uint8List.fromList(imageContent.Content!),
                  index: pIndex++,
                ),
              );
            }
          }
        }
      } else if (element.localName == 'p' || element.localName == 'div') {
        final text = element.text.trim();
        if (text.isNotEmpty && text.length > 5) {
          paragraphs.add(
            Paragraph(
              id: HashUtils.hashText(text),
              text: text,
              index: pIndex++,
            ),
          );
        }
      }
      for (var child in element.children) {
        processElement(child);
      }
    }

    for (var element in elements) {
      processElement(element);
    }
    return paragraphs;
  }
}
