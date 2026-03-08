import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final groqServiceProvider = Provider<GroqService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return GroqService(secureStorage);
});

class GroqService {
  final FlutterSecureStorage _secureStorage;
  static const String _groqApiKey = 'GROQ_API_KEY';
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  GroqService(this._secureStorage);

  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _groqApiKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _groqApiKey);
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: _groqApiKey);
  }

  Future<bool> testApiKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Sends a real test prompt to validate the API key works end-to-end.
  Future<String> testConnection(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gemma2-9b-it',
          'messages': [{'role': 'user', 'content': 'Connection test. Reply with: Connected successfully.'}],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Error: ${response.statusCode} — ${response.reasonPhrase}';
      }
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    String mainModel = 'openai/gpt-oss-120b',
    String fallbackModel = 'gemma2-9b-it',
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured. Please add it in settings.');
    }

    final messages = [];
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    Future<http.Response> attemptRequest(String modelToUse) {
      return http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelToUse,
          'messages': messages,
        }),
      );
    }

    var response = await attemptRequest(mainModel);

    // If the main model fails (e.g., 404 Model Not Found or other error), try fallback
    if (response.statusCode != 200) {
      response = await attemptRequest(fallbackModel);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to generate response using both models. Last error: ${response.body}');
    }
  }
}
