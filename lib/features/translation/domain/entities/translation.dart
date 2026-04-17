import 'package:equatable/equatable.dart';

class Translation extends Equatable {
  final String original;
  final String translation;
  final String? provider;

  const Translation({
    required this.original,
    required this.translation,
    this.provider,
  });

  @override
  List<Object?> get props => [original, translation, provider];
}
