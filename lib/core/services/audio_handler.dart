import 'package:audio_service/audio_service.dart';
import 'package:epub_translate_meaning/core/di/injection.dart';
import 'package:epub_translate_meaning/core/services/tts_service.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:epub_translate_meaning/features/settings/presentation/cubit/settings_state.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class EpubAudioHandler extends BaseAudioHandler with SeekHandler {
  final TtsService _ttsService;

  List<String> _paragraphs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  EpubAudioHandler(this._ttsService) {
    _ttsService.setCallbacks(
      onComplete: () {
        if (_isPlaying) _playNext();
      },
      onStart: () {
        _broadcastState();
      },
    );
  }

  void setAudiobookData(String bookTitle, String chapterTitle, List<String> paragraphs, int startIndex) {
    _paragraphs = paragraphs;
    _currentIndex = startIndex;
    try {
      mediaItem.add(MediaItem(
        id: bookTitle + chapterTitle,
        album: bookTitle,
        title: chapterTitle,
        artist: 'Epub Translate Meaning',
      ));
    } catch (e) {
      // Ignored for platforms with missing plugins
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < _paragraphs.length - 1) {
      _currentIndex++;
      await _playCurrent();
    } else {
      await stop();
    }
  }

  Future<void> _playCurrent() async {
    if (_currentIndex >= 0 && _currentIndex < _paragraphs.length) {
      _isPlaying = true;
      _broadcastState();
      // To get the book voice, we should ideally inject SettingsCubit or get the setting directly.
      // We will add it as an extension to EpubAudioHandler or read from service locator.
      String? bookVoice;
      try {
        final settingsState = getIt<SettingsCubit>().state;
        if (settingsState is SettingsLoaded) {
          bookVoice = settingsState.settings.bookVoice;
        }
      } catch (_) {}
      
      await _ttsService.speak(_paragraphs[_currentIndex], voice: bookVoice);
    }
  }

  @override
  Future<void> play() async {
    if (_paragraphs.isEmpty) return;
    _isPlaying = true;
    _broadcastState();
    await _playCurrent();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    await _ttsService.stop();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentIndex = 0;
    await _ttsService.stop();
    _broadcastState();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await _ttsService.stop();
    await _playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _ttsService.stop();
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
    }
  }

  void _broadcastState() {
    try {
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const [
          AudioProcessingState.idle,
          AudioProcessingState.ready,
          AudioProcessingState.buffering,
          AudioProcessingState.ready,
        ][_isPlaying ? 3 : 1],
        playing: _isPlaying,
      ));
    } catch (e) {
      // Ignored for platforms with missing plugins
    }
  }
}
