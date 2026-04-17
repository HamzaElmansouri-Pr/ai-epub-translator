import 'dart:io';
import 'dart:typed_data';

/// Reads a file from the native file system using dart:io.
Future<Uint8List> readFileBytes(String path) async {
  return File(path).readAsBytes();
}
