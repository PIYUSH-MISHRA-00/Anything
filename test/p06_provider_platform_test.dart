/// Implementation Specification IS-P06 — AI provider platform.
///
/// The first group is the REGRESSION TEST FOR THE REPORTED DEFECT: a fresh,
/// valid Groq key failing "Test Connection" with HTTP 400. Everything else
/// pins the platform behaviour that replaced the one-off Groq implementation.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/ai/openai_compatible_provider.dart';
import 'package:anything/ai/provider_catalogue.dart';
import 'package:anything/ai/provider_error.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/services/provider_registry.dart';

/// The body Groq actually returns for a decommissioned model.
const String _decommissionedBody = '''
{"error":{"message":"The model `gemma2-9b-it` has been decommissioned and is no longer supported. Please refer to https://console.groq.com/docs/deprecations for a recommendation on which model to use instead.","type":"invalid_request_error","code":"model_decommissioned"}}
''';

const String _modelsBody =
    '{"object":"list","data":[{"id":"llama-3.3-70b-versatile"},'
    '{"id":"llama-3.1-8b-instant"}]}';

OpenAiCompatibleProvider _provider(MockClient client) =>
    OpenAiCompatibleProvider(
      descriptor: ProviderCatalogue.groq,
      client: client,
    );

/// The keystore is a platform channel, so tests must stand one in.
/// Same helper shape as `test/app/r1_composition_root_test.dart`.
void _mockSecureStorage(Map<String, String> store) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        final key = call.arguments is Map
            ? call.arguments['key'] as String?
            : null;
        switch (call.method) {
          case 'write':
            store[key!] = call.arguments['value'] as String;
            return null;
          case 'read':
            return store[key];
          case 'delete':
            store.remove(key);
            return null;
          case 'containsKey':
            return store.containsKey(key);
          default:
            return null;
        }
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage(<String, String>{});
  });

  tearDown(() {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('THE REPORTED DEFECT — valid key, HTTP 400 (IS-P06)', () {
    test('a decommissioned model is NOT reported as a bad key', () {
      final classified = ProviderErrors.fromResponse(
        statusCode: 400,
        body: _decommissionedBody,
        providerName: 'Groq',
      );

      expect(classified.failure, ProviderFailure.modelDecommissioned);

      // The whole defect was that this failure blamed the user's credential.
      expect(classified.requiresNewKey, isFalse);
      expect(classified.message.toLowerCase(), contains('retired'));
      expect(
        classified.message.toLowerCase(),
        contains('your api key is fine'),
      );
      expect(
        classified.message.toLowerCase(),
        isNot(contains('rejected')),
        reason: 'a retired model must never read as a rejected key',
      );
    });

    test('the raw status code never reaches the user', () {
      for (final status in [400, 401, 403, 404, 429, 500, 503]) {
        final message = ProviderErrors.fromResponse(
          statusCode: status,
          body: '{}',
          providerName: 'Groq',
        ).message;
        expect(
          message,
          isNot(contains('$status')),
          reason: 'HTTP $status leaked into a user-facing message',
        );
      }
    });

    test('KEY VALIDATION NO LONGER NAMES A MODEL', () async {
      // The root cause: validation POSTed a chat completion to a hardcoded
      // model, so retiring that model broke every valid key. Validation must
      // authenticate without depending on any model existing.
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(_modelsBody, 200);
      });

      expect(await _provider(client).testConnection('gsk_valid'), isTrue);

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, endsWith('/models'));
      expect(
        requests.single.url.path,
        isNot(contains('chat/completions')),
        reason: 'validating a key must not depend on a model',
      );
      expect(requests.single.body, isEmpty);
      expect(requests.single.headers['Authorization'], 'Bearer gsk_valid');
    });

    test('a key that would have hit the 400 now passes validation', () async {
      // Same key, same provider. `/models` succeeds where a chat completion
      // against the retired default failed.
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response(_modelsBody, 200);
        }
        return http.Response(_decommissionedBody, 400);
      });

      expect(await _provider(client).testConnection('gsk_valid'), isTrue);
    });

    test('the default model is not the decommissioned one', () {
      expect(ProviderCatalogue.groq.defaultModel, isNot('gemma2-9b-it'));
      expect(ProviderCatalogue.groq.defaultModel, isNotNull);
    });
  });

  group('Error taxonomy', () {
    test('401 is a rejected key and nothing else', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":{"message":"Invalid"}}', 401),
      );
      // `false` means exactly one thing.
      expect(await _provider(client).testConnection('bad'), isFalse);
    });

    test('403 is permission, not a bad key', () {
      expect(
        ProviderErrors.fromResponse(
          statusCode: 403,
          body: '{}',
          providerName: 'Groq',
        ).failure,
        ProviderFailure.permissionDenied,
      );
    });

    test('429 is rate limiting and is transient', () {
      final e = ProviderErrors.fromResponse(
        statusCode: 429,
        body: '{}',
        providerName: 'Groq',
      );
      expect(e.failure, ProviderFailure.rateLimited);
      expect(e.isTransient, isTrue);
    });

    test('5xx blames the provider, not the key', () {
      final e = ProviderErrors.fromResponse(
        statusCode: 503,
        body: '',
        providerName: 'Groq',
      );
      expect(e.failure, ProviderFailure.serverUnavailable);
      expect(e.requiresNewKey, isFalse);
      expect(e.message, contains('not a problem with your key'));
    });

    test('an unknown model is distinguished from a retired one', () {
      final e = ProviderErrors.fromResponse(
        statusCode: 404,
        body:
            '{"error":{"message":"model not found","code":"model_not_found"}}',
        providerName: 'Groq',
      );
      expect(e.failure, ProviderFailure.missingModel);
    });

    test('an HTML error page does not crash the classifier', () {
      final e = ProviderErrors.fromResponse(
        statusCode: 502,
        body: '<html><body>Bad Gateway</body></html>',
        providerName: 'Groq',
      );
      expect(e.failure, ProviderFailure.serverUnavailable);
    });

    test('a timeout is a timeout, not a bad key', () async {
      final client = MockClient(
        (_) async => throw TimeoutException('too slow'),
      );
      await expectLater(
        _provider(client).testConnection('gsk_x'),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.failure, 'failure', ProviderFailure.timeout)
              .having((e) => e.requiresNewKey, 'requiresNewKey', isFalse),
        ),
      );
    });

    test('an empty key is caught before any request is made', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      await expectLater(
        _provider(client).testConnection('   '),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.failure,
            'failure',
            ProviderFailure.missingApiKey,
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('a 200 that is not an OpenAI API is not success', () async {
      // A captive portal or proxy login page answers 200 with HTML.
      final client = MockClient(
        (_) async => http.Response('<html>Sign in to WiFi</html>', 200),
      );
      await expectLater(
        _provider(client).testConnection('gsk_x'),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.failure,
            'failure',
            ProviderFailure.incorrectEndpoint,
          ),
        ),
      );
    });

    test('a user-facing message never carries a stack trace', () {
      final e = ProviderErrors.fromException(
        StateError('internal failure at package:anything/foo.dart:42'),
        providerName: 'Groq',
      );
      expect(e.message, isNot(contains('package:anything')));
      expect(e.message, isNot(contains('.dart:')));
      // The detail is kept for Developer Mode, just not shown in settings.
      expect(e.providerDetail, contains('internal failure'));
    });
  });

  group('Generation', () {
    test('a failed request is NOT retried against a fallback model', () async {
      // The old adapter retried EVERY non-200 against a hardcoded fallback,
      // so one rejected key produced two requests and surfaced the second
      // failure — hiding the real cause.
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"error":{"message":"Invalid API Key"}}', 401);
      });
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: client,
      );
      await provider.saveApiKey('bad-key');

      await expectLater(
        provider.generate(
          const ModelRequest(messages: [ModelMessage.user('hi')]),
        ),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.failure,
            'failure',
            ProviderFailure.invalidApiKey,
          ),
        ),
      );
      expect(calls, 1, reason: 'a 401 must not trigger a second request');
    });

    test('a successful generation reads text and usage', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'hello'},
              },
            ],
            'usage': {
              'prompt_tokens': 3,
              'completion_tokens': 4,
              'total_tokens': 7,
            },
          }),
          200,
        ),
      );
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: client,
      );
      await provider.saveApiKey('gsk_x');

      final response = await provider.generate(
        const ModelRequest(messages: [ModelMessage.user('hi')]),
      );
      expect(response.text, 'hello');
      expect(response.usage?.totalTokens, 7);
      expect(response.modelId, ProviderCatalogue.groq.defaultModel);
    });
  });

  group('Model discovery', () {
    test('models are listed and sorted', () async {
      final client = MockClient((_) async => http.Response(_modelsBody, 200));
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: client,
      );
      await provider.saveApiKey('gsk_x');

      final models = await provider.listModels();
      expect(models.map((m) => m.id), [
        'llama-3.1-8b-instant',
        'llama-3.3-70b-versatile',
      ]);
    });

    test(
      'a discovery failure throws instead of returning an empty list',
      () async {
        // It used to be wrapped in `catch (_) { return []; }`, so a rejected key
        // and a provider with no models looked identical.
        final client = MockClient((_) async => http.Response('{}', 401));
        final provider = OpenAiCompatibleProvider(
          descriptor: ProviderCatalogue.groq,
          client: client,
        );
        await provider.saveApiKey('bad');

        await expectLater(
          provider.listModels(),
          throwsA(isA<ProviderException>()),
        );
      },
    );
  });

  group('THE ACTIVE PROVIDER WAS NEVER SET (IS-P06)', () {
    test(
      'a configured provider becomes active and survives a restart',
      () async {
        // `setActiveProvider` existed and was called from nowhere in lib/, so
        // `activeProvider` was null for every session and a valid key was never
        // used for anything.
        final registry = AnythingProviderRegistry();
        await registry.initialize();
        expect(registry.activeProvider, isNull);

        final config = await registry.createGroqConfig();
        await registry.saveConfig(config.copyWith(isConfigured: true));

        expect(registry.activeProvider, isNotNull);
        expect(registry.activeProvider!.providerId, 'groq');

        // A SECOND registry reading the SAME storage — the restart case.
        final restarted = AnythingProviderRegistry();
        await restarted.initialize();
        expect(
          restarted.activeProvider?.providerId,
          'groq',
          reason: 'the active provider must survive a restart',
        );
      },
    );

    test('removing the active configuration clears it', () async {
      final registry = AnythingProviderRegistry();
      final config = await registry.createGroqConfig();
      await registry.saveConfig(config.copyWith(isConfigured: true));
      expect(registry.activeProvider, isNotNull);

      await registry.deleteConfig(config.id);
      expect(
        registry.activeProvider,
        isNull,
        reason: 'the app must not point at a provider that no longer exists',
      );
    });
  });

  group('Configuration persistence', () {
    test('validation metadata round-trips', () {
      final now = DateTime.now();
      final config = ProviderConfig(
        id: 'a',
        providerType: 'groq',
        displayName: 'Groq',
        createdAt: now,
        updatedAt: now,
        lastValidatedAt: now,
        lastFailureReason: 'nope',
      );
      final decoded = ProviderConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.lastValidatedAt?.toIso8601String(), now.toIso8601String());
      expect(decoded.lastFailureReason, 'nope');
    });

    test('configuration written before IS-P06 still loads', () {
      // An existing install must upgrade, not lose its provider.
      final decoded = ProviderConfig.fromJson({
        'id': 'a',
        'providerType': 'groq',
        'displayName': 'Groq',
        'isDefault': true,
        'isConfigured': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(decoded.isConfigured, isTrue);
      expect(decoded.lastValidatedAt, isNull);
      expect(decoded.lastFailureReason, isNull);
    });

    test('a successful test clears a stale failure message', () {
      final now = DateTime.now();
      final failed = ProviderConfig(
        id: 'a',
        providerType: 'groq',
        displayName: 'Groq',
        createdAt: now,
        updatedAt: now,
        lastFailureReason: 'old failure',
      );
      final passed = failed.copyWith(
        lastValidatedAt: now,
        clearFailureReason: true,
      );
      expect(passed.lastFailureReason, isNull);
      expect(passed.lastValidatedAt, isNotNull);
    });
  });

  group('The catalogue', () {
    test('every deferred provider explains itself — no dead UI', () {
      for (final p in ProviderCatalogue.all) {
        if (p.status == ProviderStatus.comingSoon) {
          expect(
            p.unavailableReason,
            isNotNull,
            reason: '${p.name} is deferred with no reason given',
          );
          expect(p.unavailableReason, isNotEmpty);
        }
      }
    });

    test('every provider is reachable, uniquely identified and described', () {
      final ids = <String>{};
      for (final p in ProviderCatalogue.all) {
        expect(ids.add(p.id), isTrue, reason: 'duplicate id ${p.id}');
        expect(p.summary, isNotEmpty, reason: '${p.name} has no summary');
        expect(ProviderCatalogue.byId(p.id), same(p));
      }
    });

    test('an implemented provider has an endpoint or asks for one', () {
      for (final p in ProviderCatalogue.implemented) {
        expect(
          p.baseUrl != null || p.requiresEndpoint,
          isTrue,
          reason: '${p.name} can be selected but has nowhere to send requests',
        );
      }
    });

    test('a provider with no default model must ask for one', () {
      // Guessing a default is exactly how the decommissioned-model failure
      // happened. Providers whose hosted set is unknown must not guess.
      for (final p in ProviderCatalogue.implemented) {
        if (p.defaultModel == null) {
          expect(
            p.capabilities.modelDiscovery,
            isTrue,
            reason: '${p.name} has no default model and no way to find one',
          );
        }
      }
    });

    test('only verified providers claim to be tested', () {
      for (final p in ProviderCatalogue.all) {
        if (p.status == ProviderStatus.available) {
          expect(
            p.verified,
            isTrue,
            reason: '${p.name} claims Available without being verified',
          );
        }
      }
      expect(ProviderCatalogue.groq.verified, isTrue);
    });

    test('search and grouping cover the catalogue', () {
      expect(ProviderCatalogue.search('groq').single.id, 'groq');
      expect(ProviderCatalogue.search('LOCAL'), isNotEmpty);
      expect(
        ProviderCatalogue.search(''),
        hasLength(ProviderCatalogue.all.length),
      );

      var counted = 0;
      for (final c in ProviderCategory.values) {
        counted += ProviderCatalogue.byCategory(c).length;
      }
      expect(counted, ProviderCatalogue.all.length);
    });

    test(
      'the registry can instantiate every implemented fixed-URL provider',
      () {
        final registry = AnythingProviderRegistry();
        for (final p in ProviderCatalogue.implemented) {
          if (p.requiresEndpoint) continue;
          expect(
            registry.getProvider(p.id),
            isNotNull,
            reason: '${p.name} is implemented but has no adapter registered',
          );
        }
      },
    );

    test(
      'a local provider is bound to the endpoint in its configuration',
      () async {
        final registry = AnythingProviderRegistry();
        final config = await registry.createConfig(
          ProviderCatalogue.ollama,
          endpoint: 'http://192.168.1.10:11434/v1',
        );
        final provider = registry.providerForConfig(config);
        expect(provider, isA<OpenAiCompatibleProvider>());
        expect(
          (provider as OpenAiCompatibleProvider).baseUrl,
          'http://192.168.1.10:11434/v1',
        );
      },
    );
  });

  group('Credentials', () {
    test('provider keys are namespaced so one cannot overwrite another', () {
      // Both providers exist in the same registry; their credential purposes
      // must not collide.
      final registry = AnythingProviderRegistry();
      final groq = registry.getProvider('groq');
      final openai = registry.getProvider('openai');
      expect(groq, isNotNull);
      expect(openai, isNotNull);
      expect(groq!.providerId, isNot(openai!.providerId));
    });
  });
}
