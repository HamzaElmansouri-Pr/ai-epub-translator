import 'package:equatable/equatable.dart';

class DictionaryEntry extends Equatable {
  final String word;
  final String? phonetic;
  final List<Meaning> meanings;

  const DictionaryEntry({
    required this.word,
    this.phonetic,
    required this.meanings,
  });

  @override
  List<Object?> get props => [word, phonetic, meanings];

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
      meanings: (json['meanings'] as List<dynamic>?)
              ?.map((e) => Meaning.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Meaning extends Equatable {
  final String partOfSpeech;
  final List<Definition> definitions;

  const Meaning({
    required this.partOfSpeech,
    required this.definitions,
  });

  @override
  List<Object?> get props => [partOfSpeech, definitions];

  factory Meaning.fromJson(Map<String, dynamic> json) {
    return Meaning(
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      definitions: (json['definitions'] as List<dynamic>?)
              ?.map((e) => Definition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Definition extends Equatable {
  final String definition;
  final String? example;

  const Definition({
    required this.definition,
    this.example,
  });

  @override
  List<Object?> get props => [definition, example];

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      definition: json['definition'] as String? ?? '',
      example: json['example'] as String?,
    );
  }
}