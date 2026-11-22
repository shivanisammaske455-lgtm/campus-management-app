import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Riverpod provider for SpeechService.
final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized;

  /// Initializes the speech recognition engine and handles permissions politely.
  Future<bool> initialize({
    required Function(String politeMessage) onError,
  }) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (SpeechRecognitionError error) {
          if (error.errorMsg == 'error_permission') {
            onError(
              'Microphone permission is needed for voice typing. You can still type your description manually.',
            );
          } else {
            onError(
              'Voice input paused: ${error.errorMsg}. You can try again or type manually.',
            );
          }
        },
        onStatus: (String status) {
          debugPrint('Speech status: $status');
        },
      );

      if (!_isInitialized) {
        onError(
          'Microphone permission was not granted. Please type your description or allow microphone access in settings.',
        );
      }
      return _isInitialized;
    } catch (e) {
      onError(
        'Speech recognition is not supported on this device. Please enter description manually.',
      );
      return false;
    }
  }

  /// Starts listening to voice input and streams recognized text.
  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    required Function(String politeMessage) onError,
  }) async {
    final hasInit = await initialize(onError: onError);
    if (!hasInit) return;

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.dictation,
    );
  }

  /// Stops active listening.
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
}
