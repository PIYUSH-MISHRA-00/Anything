/// Host-side Groq smoke test. Reads GROQ_API_KEY from the environment only.
/// Never prints the key or Authorization header.
///
/// Usage: dart run tool/groq_smoke.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final key = Platform.environment['GROQ_API_KEY']?.trim() ?? '';
  if (key.isEmpty) {
    stderr.writeln('FAIL: GROQ_API_KEY is not set in the environment.');
    exit(2);
  }
  if (!key.startsWith('gsk_')) {
    stderr.writeln('FAIL: GROQ_API_KEY has unexpected shape.');
    exit(2);
  }

  final client = http.Client();
  try {
    final models = await client
        .get(
          Uri.parse('https://api.groq.com/openai/v1/models'),
          headers: {
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));

    stdout.writeln('models_status=${models.statusCode}');
    if (models.statusCode != 200) {
      stderr.writeln('FAIL: /models rejected credential or network.');
      exit(1);
    }

    final body = jsonEncode({
      'model': 'llama-3.1-8b-instant',
      'messages': [
        {'role': 'user', 'content': 'Return exactly the word OK.'},
      ],
      'temperature': 0,
      'max_tokens': 8,
    });

    final chat = await client
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    stdout.writeln('chat_status=${chat.statusCode}');
    if (chat.statusCode != 200) {
      stderr.writeln('FAIL: chat completion failed.');
      exit(1);
    }

    final decoded = jsonDecode(chat.body);
    String? content;
    if (decoded is Map &&
        decoded['choices'] is List &&
        (decoded['choices'] as List).isNotEmpty) {
      final first = (decoded['choices'] as List).first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          content = message['content']?.toString();
        }
      }
    }
    final ok = content != null && content.toUpperCase().contains('OK');
    stdout.writeln('chat_contains_ok=$ok');
    if (!ok) {
      stderr.writeln('FAIL: unexpected chat content.');
      exit(1);
    }
    stdout.writeln('GROQ_SMOKE_PASS');
  } finally {
    client.close();
  }
}
