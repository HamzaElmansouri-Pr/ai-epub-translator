import 'dart:io';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

void main() {
  final bytes = File('books epub/Thinking, Fast and Slow.epub').readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final List<String> allParagraphs = [];

  for (final file in archive) {
    if (file.isFile && (file.name.endsWith('.html') || file.name.endsWith('.xhtml'))) {
      try {
        String content = utf8.decode(file.content as List<int>);
        final document = html_parser.parse(content);
        final paragraphs = document.querySelectorAll('p, div');
        for (final p in paragraphs) {
          final text = p.text.trim();
          if (text.isNotEmpty) {
            allParagraphs.add(text);
          }
        }
      } catch (e) {
        print(e);
      }
    }
  }
  final unique = allParagraphs.toSet().toList();
  print('Extracted ${unique.length} paragraphs');
}
