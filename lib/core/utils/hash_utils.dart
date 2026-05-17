import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtils {
  static String hashText(String text) {
    if (text.isEmpty) return '';
    // Normalize whitespace: replace any sequence of whitespace with a single space
    final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
