import 'package:translator/translator.dart';
void main() async {
  final translator = GoogleTranslator();
  final texts = ['Hello world.', 'This is a test.', 'How are you?'];
  final joined = texts.join('\n\n---SPLIT---\n\n');
  print('Sending: $joined');
  final t = await translator.translate(joined, to: 'fr');
  print('Received: ${t.text}');
}
