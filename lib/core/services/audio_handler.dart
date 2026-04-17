import 'package:audio_service/audio_service.dart';
import 'package:epub_translate_meaning/core/services/tts_service.dart';

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
    mediaItem.add(MediaItem(
      id: bookTitle + chapterTitle,
      album: bookTitle,
      title: chapterTitle,
      artist: 'Epub Translate Meaning',
    ));
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
      await _ttsService.speak(_paragraphs[_currentIndex]);
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
  }
}
