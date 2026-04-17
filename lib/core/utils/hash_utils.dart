import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtils {
  static String hashText(String text) {
    if (text.isEmpty) return '';
    final bytes = utf8.encode(text.trim().toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
