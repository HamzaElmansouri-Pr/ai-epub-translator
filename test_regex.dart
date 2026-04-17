
void main() {
  final text = 'Bonjour\n\n||||||||||\n\nMonde\n \n ||||||| \n \nPárrafo dos';
  final splits = text.split(RegExp(r'\n*\s*\|{5,}\s*\n*'));
  print(splits.length);
  print(splits);
}

