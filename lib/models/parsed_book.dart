enum ParagraphType { text, heading, image, pageNumber }

class ParsedParagraph {
  final int index;
  final String text;
  final ParagraphType type;
  final String? imagePath;
  final bool isRTL;
  final bool isOcrResult;

  ParsedParagraph({
    required this.index,
    required this.text,
    required this.type,
    this.imagePath,
    required this.isRTL,
    required this.isOcrResult,
  });
}

class ParsedChapter {
  final int index;
  final String title;
  final List<ParsedParagraph> paragraphs;

  ParsedChapter({
    required this.index,
    required this.title,
    required this.paragraphs,
  });
}

class ParsedBook {
  final String title;
  final String? author;
  final String language;
  final bool isRTL;
  final List<ParsedChapter> chapters;

  ParsedBook({
    required this.title,
    this.author,
    required this.language,
    required this.isRTL,
    required this.chapters,
  });
}
