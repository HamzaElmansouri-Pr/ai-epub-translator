import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;
  static bool _isInit = false;

  static Future<void> _init() async {
    if (_isInit || kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/app_debug_log.txt');
      
      // Keep file from growing indefinitely (1MB limit)
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > 1024 * 1024) { 
          await _logFile!.delete();
        }
      }
      _isInit = true;
      debugPrint('AppLogger initialized at ${_logFile!.path}');
    } catch (e) {
      debugPrint('Failed to init logger: $e');
    }
  }

  static Future<void> log(String message) async {
    debugPrint(message);
    if (kIsWeb) return;
    
    if (!_isInit) {
      await _init();
    }

    if (_logFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
        await _logFile!.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('AppLogger failed to write: $e');
      }
    }
  }
}
