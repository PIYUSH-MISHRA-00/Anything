import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'groq_service.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final groqService = ref.watch(groqServiceProvider);
  return VoiceService(groqService);
});

class VoiceService {
  final GroqService _groqService;
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isRecording = false;

  VoiceService(this._groqService);

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPerms = await _recorder.hasPermission();
    if (!hasPerms) {
      throw Exception('Microphone permission not granted.');
    }

    final dir = await getTemporaryDirectory();
    _recordingPath = p.join(dir.path, 'voice_command_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
    _isRecording = true;
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    _isRecording = false;
    // Delete the temp file
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _recordingPath = null;
  }

  Future<String> stopAndTranscribe() async {
    if (!_isRecording) {
      throw Exception('Not currently recording.');
    }

    final path = await _recorder.stop();
    _isRecording = false;

    if (path == null || path.isEmpty) {
      throw Exception('Recording failed — no audio file produced.');
    }

    _recordingPath = path;

    // Send to Groq Whisper API
    final apiKey = await _groqService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured. Please add it in Settings.');
    }

    final file = File(_recordingPath!);
    if (!await file.exists()) {
      throw Exception('Audio file not found.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = 'whisper-large-v3';
    request.fields['language'] = 'en';
    request.files.add(await http.MultipartFile.fromPath('file', _recordingPath!));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    // Clean up temp file
    await file.delete();
    _recordingPath = null;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] ?? '';
    } else {
      throw Exception('Whisper transcription failed: ${response.body}');
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
