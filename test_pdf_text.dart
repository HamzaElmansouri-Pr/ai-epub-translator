import 'dart:io';
import 'package:pdfx/pdfx.dart';

void main() async {
  final pdfPath = r'c:\Users\profa\OneDrive\Desktop\Project\Epub Translat App\Noor-Book.com  تاريخ المغرب تحيين وتركيب 2 .pdf';
  try {
    final document = await PdfDocument.openFile(pdfPath);
    print('Pages: \${document.pagesCount}');
    // pdfx does not support direct text extraction. We might need a different package like `syncfusion_flutter_pdf` or `pdf_text`.
    // Wait, let's see if we can use a command line tool like pdftotext.
  } catch (e) {
    print('Error: \$e');
  }
}
