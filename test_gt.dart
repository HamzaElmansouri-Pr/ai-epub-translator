import "package:translator/translator.dart";
void main() async {
  final translator = GoogleTranslator();
  final texts = ["Hello world.", "This is a test.", "How are you?"];
  final joined = texts.join("\n\n|||\n\n");
  final t = await translator.translate(joined, to: "fr");
  print(t.text);
}
