/// Voice input service for Anything.
///
/// Provides speech-to-text functionality using platform speech recognition.
/// On Android, uses the device's built-in speech recognition.
/// No audio is sent to AI providers — this is local speech recognition only.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';

/// State of the voice input system.
enum VoiceState { idle, listening, processing, error, unavailable }

/// Result of a voice recognition attempt.
class VoiceResult {
  final String text;
  final bool isFinal;
  final double confidence;

  const VoiceResult({
    required this.text,
    required this.isFinal,
    this.confidence = 0.0,
  });
}

/// Voice input service using platform speech recognition.
class VoiceInputService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  VoiceState _state = VoiceState.idle;
  String _currentText = '';
  String? _errorMessage;
  bool _isInitialized = false;

  VoiceState get state => _state;
  String get currentText => _currentText;
  String? get errorMessage => _errorMessage;
  bool get isListening => _state == VoiceState.listening;
  bool get isAvailable => _state != VoiceState.unavailable;

  /// Initialize the speech recognition system.
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!_isInitialized) {
        _setState(VoiceState.unavailable);
      }
      return _isInitialized;
    } catch (e) {
      _setState(VoiceState.unavailable);
      _errorMessage = 'Speech recognition unavailable';
      notifyListeners();
      return false;
    }
  }

  /// Request microphone permission.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start listening for speech.
  Future<void> startListening() async {
    if (_state == VoiceState.listening) return;

    // Check permission first
    if (!await requestPermission()) {
      _setState(VoiceState.error);
      _errorMessage = 'Microphone permission denied';
      notifyListeners();
      return;
    }

    // Initialize if needed
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) {
        _setState(VoiceState.unavailable);
        _errorMessage = 'Speech recognition unavailable on this device';
        notifyListeners();
        return;
      }
    }

    _currentText = '';
    _errorMessage = null;
    _setState(VoiceState.listening);

    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
        ),
      );
    } catch (e) {
      _setState(VoiceState.error);
      _errorMessage = 'Failed to start listening';
      notifyListeners();
    }
  }

  /// Stop listening and return the recognized text.
  Future<String> stopListening() async {
    if (_state != VoiceState.listening) return _currentText;

    _setState(VoiceState.processing);
    await _speech.stop();
    // Don't reset state to idle here — let the caller decide
    return _currentText;
  }

  /// Cancel listening and discard results.
  Future<void> cancel() async {
    await _speech.stop();
    _currentText = '';
    _errorMessage = null;
    _setState(VoiceState.idle);
  }

  void _onResult(SpeechRecognitionResult result) {
    _currentText = result.recognizedWords;
    notifyListeners();
  }

  void _onStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      if (_state == VoiceState.listening) {
        _setState(VoiceState.idle);
      }
    }
  }

  void _onError(dynamic error) {
    _setState(VoiceState.error);
    _errorMessage = 'Recognition error: ${error.errorMsg ?? 'unknown'}';
    notifyListeners();
  }

  void _setState(VoiceState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _speech.stop();
    super.dispose();
  }

  // Legacy compatibility methods
  Future<void> startRecording() => startListening();
  Future<String> stopAndTranscribe() => stopListening();
  Future<void> cancelRecording() => cancel();
}

/// Riverpod provider for VoiceInputService (legacy compatibility).
final voiceServiceProvider = Provider<VoiceInputService>((ref) {
  return VoiceInputService();
});
