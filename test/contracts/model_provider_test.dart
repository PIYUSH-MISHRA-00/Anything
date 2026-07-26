/// Tests for ModelProvider boundary.
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/contracts/contracts.dart';

void main() {
  group('ModelMessage', () {
    test('system message factory', () {
      const msg = ModelMessage.system('You are a helpful assistant.');
      expect(msg.role, equals('system'));
      expect(msg.content, equals('You are a helpful assistant.'));
    });

    test('user message factory', () {
      const msg = ModelMessage.user('Hello');
      expect(msg.role, equals('user'));
      expect(msg.content, equals('Hello'));
    });

    test('assistant message factory', () {
      const msg = ModelMessage.assistant('Hi there!');
      expect(msg.role, equals('assistant'));
      expect(msg.content, equals('Hi there!'));
    });
  });

  group('ModelRequest', () {
    test('default values', () {
      const request = ModelRequest(messages: [ModelMessage.user('Test')]);

      expect(request.modelId, isNull);
      expect(request.maxTokens, isNull);
      expect(request.temperature, isNull);
      expect(request.stream, isFalse);
      expect(request.timeout, isNull);
    });
  });

  group('ModelResponse', () {
    test('create success response', () {
      const response = ModelResponse(text: 'Hello world');

      expect(response.text, equals('Hello world'));
      expect(response.usedFallback, isFalse);
      expect(response.usage, isNull);
    });

    test('create response with usage', () {
      const response = ModelResponse(
        text: 'Response',
        usage: ModelUsage(
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
        ),
        modelId: 'gemma2-9b-it',
        usedFallback: true,
      );

      expect(response.usage?.totalTokens, equals(30));
      expect(response.modelId, equals('gemma2-9b-it'));
      expect(response.usedFallback, isTrue);
    });
  });

  group('ModelInfo', () {
    test('create model info', () {
      const model = ModelInfo(
        id: 'gemma2-9b-it',
        name: 'Gemma 2 9B',
        provider: 'groq',
        modalities: [ModelModality.text],
        contextWindow: 8192,
        isAvailable: true,
      );

      expect(model.id, equals('gemma2-9b-it'));
      expect(model.modalities, contains(ModelModality.text));
      expect(model.isAvailable, isTrue);
    });
  });
}
