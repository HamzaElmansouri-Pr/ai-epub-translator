import 'dart:typed_data';

/// Reads a file from the native file system.
/// This stub is used on Web where dart:io is unavailable.
Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('File system access is not supported on Web.');
}
