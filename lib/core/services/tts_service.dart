import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class TtsService {
  final FlutterTts _flutterTts;
  
  bool _isInit = false;

  VoidCallback? _onComplete;
  VoidCallback? _onStart;

  TtsService() : _flutterTts = FlutterTts() {
    _initTts();
  }

  void setCallbacks({VoidCallback? onComplete, VoidCallback? onStart}) {
    _onComplete = onComplete;
    _onStart = onStart;
    _flutterTts.setCompletionHandler(() {
      _onComplete?.call();
    });
    _flutterTts.setStartHandler(() {
      _onStart?.call();
    });
  }

  Future<void> _initTts() async {
    if (kIsWeb) return;
    
    // Set up audio session to behave like a media player (audiobook/music)
    try {
      if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
      }
    } catch (e) {
      debugPrint('AudioSession configuration failed: $e');
    }
    
    if (Platform.isIOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ],
        IosTextToSpeechAudioMode.defaultMode
      );
    }
    
    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('awaitSpeakCompletion not supported: $e');
    }
    _isInit = true;
  }

  Future<void> speak(String text, {String? language}) async {
    if (!_isInit && !kIsWeb) {
      await _initTts();
    }
    
    // Activate audio session for background playback
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
        final session = await AudioSession.instance;
        await session.setActive(true);
      }
    } catch (e) {
      debugPrint('AudioSession setActive failed: $e');
    }
    
    if (language != null) {
      // Try to set language, ignoring errors if unsupported
      try {
        await _flutterTts.setLanguage(language);
      } catch (e) {
        debugPrint('Language $language not supported for TTS: $e');
      }
    }
    
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    // Deactivate audio session when stopped
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
        final session = await AudioSession.instance;
        await session.setActive(false);
      }
    } catch (e) {
      debugPrint('AudioSession setActive failed: $e');
    }
  }
}
