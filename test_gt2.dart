import 'package:translator/translator.dart';

void main() async {
  final translator = GoogleTranslator();
  try {
    final t1 = await translator.translate('Hello\n\n|||||||\n\nWorld', to: 'ar');
    print(t1.text);
    final t2 = await translator.translate('This is a test.\n\n|||||||\n\nParagraph two.\n\n|||||||\n\nparagraph three.', to: 'es');
    print(t2.text);
  } catch (e) {
    print(e);
  }
}

