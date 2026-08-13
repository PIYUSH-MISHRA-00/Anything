/// Implementation Specification IS-P07 — AI Runtime Integration &
/// End-to-End Creation Pipeline.
///
/// THE REPORTED DEFECT: a provider that configures, verifies and persists
/// correctly, and a Home screen that still answers "Connect an AI provider to
/// create new things."
///
/// THE ROOT CAUSE, found by tracing the call path rather than the symptom:
/// `AppComposition.production()` was a plain factory. Every caller built its
/// own object graph — its own `AnythingProviderRegistry`, its own
/// `SqliteExperienceRepository`, its own `EventBus`, its own Kernel. Six call
/// sites did so independently. Configuring a provider therefore wrote to the
/// Settings screen's registry while the Kernel read the shell's, which no
/// one had ever resolved an active provider into.
///
/// It survived restarts because each launch rebuilt the same disconnected
/// arrangement, and it was invisible to the certification layer because the
/// existing invariant asserted that repeated reads OF ONE INSTANCE were
/// stable — true, and beside the point.
///
/// These tests use real objects throughout. The only stand-in is the model
/// provider itself, because asserting on a network round-trip would prove
/// Groq's uptime rather than this repository's wiring.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/ai/openai_compatible_provider.dart';
import 'package:anything/ai/provider_catalogue.dart';
import 'package:anything/ai/provider_error.dart';
import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';

/// In-memory stand-in for the `flutter_secure_storage` platform channel —
/// the same approach `test/app/r1_composition_root_test.dart` established.
/// Real `CredentialVault` code runs unmodified.
void _mockSecureStorageChannel(Map<String, String> store) {
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
          case 'readAll':
            return store;
          default:
            return null;
        }
      });
}

/// A real `ModelProvider` that answers from memory instead of the network.
///
/// It branches on the system prompt because the pipeline makes two DIFFERENT
/// model calls — intent understanding, then application reasoning — and each
/// parses a different schema. Returning one shape for both would make the
/// understanding step fall back to heuristics and quietly weaken the test.
class _ScriptedModelProvider implements ModelProvider {
  final List<String> prompts = [];

  @override
  String get providerId => 'scripted';

  @override
  String get providerName => 'Scripted';

  @override
  bool get isConfigured => true;

  @override
  Future<List<ModelInfo>> listModels() async => const [
    ModelInfo(id: 'scripted-1', name: 'scripted-1', provider: 'scripted'),
  ];

  @override
  Future<bool> testConnection(String apiKey) async => true;

  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    final system = request.messages.first.content;
    prompts.add(system);
    final understanding = system.contains('Intent Understanding engine');
    return ModelResponse(
      text: understanding ? _understandingJson : _blueprintJson,
      modelId: 'scripted-1',
    );
  }

  @override
  Stream<String> generateStream(ModelRequest request) async* {
    yield (await generate(request)).text;
  }

  @override
  Future<void> saveApiKey(String apiKey) async {}

  @override
  Future<String?> getApiKey() async => 'scripted-key';

  @override
  Future<void> deleteApiKey() async {}

  static final String _understandingJson = jsonEncode({
    'objective': 'track puzzle game scores',
    'category': 'create',
    'desiredOutcome': 'a place to record puzzle scores',
    'constraints': <String>[],
    'requiredInputs': <String>[],
    'assumptions': <String>[],
    'confidence': 0.9,
    'networkNeed': 'none',
    'creationNeed': 'definitelyNeeded',
    'modificationNeed': 'notNeeded',
  });

  static final String _blueprintJson = jsonEncode({
    'name': 'Puzzle Scores',
    'purpose': 'Track puzzle game scores',
    'entities': [
      {
        'name': 'Score',
        'description': 'One recorded score',
        'displayField': 'label',
        'fields': [
          {'name': 'label', 'type': 'text', 'required': true},
          {'name': 'points', 'type': 'integer', 'required': true},
          {'name': 'playedAt', 'type': 'dateTime', 'required': true},
        ],
      },
    ],
    'actions': [
      {'name': 'addScore', 'type': 'create', 'targetEntity': 'Score'},
      {'name': 'deleteScore', 'type': 'delete', 'targetEntity': 'Score'},
    ],
    'derivedValues': [
      {
        'name': 'bestScore',
        'sourceEntity': 'Score',
        'operation': 'maximum',
        'fieldId': 'points',
      },
    ],
    'views': [
      {
        'name': 'All Scores',
        'purpose': 'Every recorded score',
        'type': 'list',
        'sourceEntity': 'Score',
        'isDefault': true,
        'sections': [
          {'purpose': 'scores', 'sourceEntity': 'Score', 'type': 'list'},
        ],
      },
      {
        'name': 'Add Score',
        'purpose': 'Record a score',
        'type': 'form',
        'sourceEntity': 'Score',
        'sections': <Map<String, dynamic>>[],
      },
    ],
    'tags': ['puzzle'],
    'archetypes': ['collection'],
    'requiredCapabilities': <String>[],
    'knowledgeNeeds': <String>[],
    'networkConfig': null,
  });
}

/// A model that returns a booking records app but ALSO asks for networkData /
/// a networkConfig — exactly the working-key output that used to be clobbered
/// into the "City or location" search shell by the repair pass (owner report).
class _BookingModelProvider implements ModelProvider {
  @override
  String get providerId => 'scripted';
  @override
  String get providerName => 'Scripted';
  @override
  bool get isConfigured => true;
  @override
  Future<List<ModelInfo>> listModels() async =>
      const [ModelInfo(id: 's', name: 's', provider: 'scripted')];
  @override
  Future<bool> testConnection(String apiKey) async => true;
  @override
  Future<ModelResponse> generate(ModelRequest request) async {
    final understanding =
        request.messages.first.content.contains('Intent Understanding engine');
    return ModelResponse(
      text: understanding ? _understanding : _booking,
      modelId: 's',
    );
  }

  @override
  Stream<String> generateStream(ModelRequest request) async* {
    yield (await generate(request)).text;
  }

  @override
  Future<void> saveApiKey(String apiKey) async {}
  @override
  Future<String?> getApiKey() async => 'k';
  @override
  Future<void> deleteApiKey() async {}

  static final String _understanding = jsonEncode({
    'objective': 'search, book and manage train tickets',
    'category': 'create',
    'desiredOutcome': 'book and manage train tickets',
    'constraints': <String>[],
    'requiredInputs': <String>[],
    'assumptions': <String>[],
    'confidence': 0.9,
    'networkNeed': 'realtime',
    'creationNeed': 'definitelyNeeded',
    'modificationNeed': 'notNeeded',
  });

  static final String _booking = jsonEncode({
    'name': 'Train Ticket Booking',
    'purpose': 'Search, book and manage train tickets',
    'entities': [
      {
        'name': 'Booking',
        'description': 'A train ticket booking',
        'displayField': 'route',
        'fields': [
          {'name': 'route', 'type': 'text', 'required': true},
          {'name': 'travelDate', 'type': 'dateTime', 'required': true},
          {'name': 'passengers', 'type': 'integer', 'required': true},
        ],
      },
    ],
    'actions': [
      {'name': 'addBooking', 'type': 'create', 'targetEntity': 'Booking'},
      {'name': 'cancelBooking', 'type': 'delete', 'targetEntity': 'Booking'},
    ],
    'views': [
      {
        'name': 'My Bookings',
        'purpose': 'All bookings',
        'type': 'list',
        'sourceEntity': 'Booking',
        'isDefault': true,
        'sections': [
          {'purpose': 'bookings', 'sourceEntity': 'Booking', 'type': 'list'},
        ],
      },
      {
        'name': 'New Booking',
        'purpose': 'Book a ticket',
        'type': 'form',
        'sourceEntity': 'Booking',
        'sections': <Map<String, dynamic>>[],
      },
    ],
    'tags': ['booking'],
    'archetypes': ['collection'],
    // The trigger: the model thinks live schedules are useful.
    'requiredCapabilities': ['networkData'],
    'knowledgeNeeds': <String>[],
    'networkConfig': {'purpose': 'live train schedules', 'allowedHosts': <String>[]},
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStore;

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    secureStore = <String, String>{};
    _mockSecureStorageChannel(secureStore);
  });

  tearDown(() {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('THE ROOT CAUSE — one composition root, not one per caller', () {
    test(
      'two calls to AppComposition.production() return the IDENTICAL object',
      () {
        expect(
          identical(AppComposition.production(), AppComposition.production()),
          isTrue,
          reason:
              'Every screen resolves shared services from production(). If it '
              'builds a new graph per call, the Settings screen configures a '
              'registry the Kernel will never read.',
        );
      },
    );

    test(
      'every canonical service is the SAME instance across two production() calls',
      () {
        final a = AppComposition.production();
        final b = AppComposition.production();

        // The one that produced the reported bug.
        expect(identical(a.providerRegistry, b.providerRegistry), isTrue);
        // The rest of the family the same defect silently affected.
        expect(identical(a.kernel, b.kernel), isTrue);
        expect(
          identical(a.experienceRepository, b.experienceRepository),
          isTrue,
        );
        expect(identical(a.eventBus, b.eventBus), isTrue);
        expect(identical(a.workspaceManager, b.workspaceManager), isTrue);
        expect(identical(a.capabilityPlatform, b.capabilityPlatform), isTrue);
        expect(identical(a.credentialVault, b.credentialVault), isTrue);
      },
    );

    test(
      'freshForTesting() still returns an independent graph, so tests can own and close one',
      () {
        final shared = AppComposition.production();
        final fresh = AppComposition.freshForTesting();
        addTearDown(() => fresh.experienceRepository.close());

        expect(identical(shared, fresh), isFalse);
        expect(
          identical(shared.providerRegistry, fresh.providerRegistry),
          isFalse,
        );
      },
    );
  });

  group('The Kernel plans against capabilities that actually exist', () {
    test(
      'every capability the runtime platform dispatches is also one the Kernel can resolve',
      () {
        final c = AppComposition.freshForTesting();
        addTearDown(() => c.experienceRepository.close());

        final dispatchable = c.capabilityPlatform.all.map((p) => p.id).toSet();
        final plannable = c.capabilityRegistry.all.map((d) => d.id).toSet();

        expect(
          dispatchable.difference(plannable),
          isEmpty,
          reason:
              'A capability the runtime can execute but the Kernel cannot '
              'plan against is refused at Step 8 before it is ever reached.',
        );
      },
    );

    test('storage — required by every blueprint with an entity — resolves', () {
      final c = AppComposition.freshForTesting();
      addTearDown(() => c.experienceRepository.close());

      // `BlueprintToSpecConverter` adds this for any blueprint that
      // declares an entity, so an unresolvable `storage` fails everything.
      expect(c.capabilityRegistry.isAvailable('storage'), isTrue);
      final resolved = c.capabilityRegistry.resolve(['storage']).single;
      expect(resolved.isResolved, isTrue);
    });
  });

  group('Provider state reaches the runtime without a restart', () {
    test(
      'a provider activated through the registry a Settings screen resolves is visible to the Kernel’s registry — same object, no refresh',
      () async {
        // Exactly what `ProviderPreferencesScreen` does to obtain a registry.
        final fromSettings = AppComposition.production().providerRegistry;
        // Exactly what the Kernel was given at construction.
        final fromRuntime = AppComposition.production().providerRegistry;

        final provider = _ScriptedModelProvider();
        fromSettings.registerProvider(provider);
        await fromSettings.setActiveProvider('scripted');

        expect(
          identical(fromRuntime.activeProvider, provider),
          isTrue,
          reason:
              'This is the reported bug in one line: before IS-P07 these were '
              'two different registries and this read returned null.',
        );
        expect(fromRuntime.activeProvider!.isConfigured, isTrue);
      },
    );

    test(
      'initialize() resolves the active provider from configuration written by an earlier session',
      () async {
        final registry = AppComposition.freshForTesting().providerRegistry;

        // A configured Groq, exactly as the configuration sheet saves it.
        final config = await registry.createGroqConfig();
        await registry.getProvider('groq')!.saveApiKey('sk-persisted');
        await registry.saveConfig(config.copyWith(isConfigured: true));

        // A new registry over the SAME storage — a fresh launch.
        final relaunched = AppComposition.freshForTesting().providerRegistry;
        expect(
          relaunched.activeProvider,
          isNull,
          reason: 'Nothing has been read from storage yet.',
        );

        await relaunched.initialize();

        expect(relaunched.activeProvider, isNotNull);
        expect(relaunched.activeProvider!.providerId, 'groq');
        expect(
          relaunched.activeProvider!.isConfigured,
          isTrue,
          reason:
              'The key is primed during load, so the synchronous getter tells '
              'the truth on a cold start.',
        );
      },
    );
  });

  group('End-to-end — intent in, Experience out', () {
    test(
      'routing a real Intent with an active provider CREATES and PERSISTS an Experience, and never answers ProviderRequired',
      () async {
        final composition = AppComposition.freshForTesting();
        addTearDown(() => composition.experienceRepository.close());

        final provider = _ScriptedModelProvider();
        composition.providerRegistry.registerProvider(provider);
        await composition.providerRegistry.setActiveProvider('scripted');

        // Deliberately NOT a "list of X" phrasing: that is handled by
        // `DeterministicReasoner` without a model, which would prove nothing
        // about the provider path.
        final result = await composition.intentRouter.route(
          Intent.create(expression: 'a puzzle game that tracks my scores'),
        );

        expect(
          result.creationResult,
          isNot(isA<CreationProviderRequired>()),
          reason: 'The exact refusal this milestone exists to remove.',
        );
        final outcome = result.creationResult;
        expect(
          outcome,
          isA<CreationCreated>(),
          reason: outcome is CreationFailed
              ? 'creation failed: ${outcome.error} / ${outcome.message}'
              : 'got ${outcome.runtimeType}: ${outcome?.message}',
        );

        final created = result.creationResult as CreationCreated;
        expect(created.package.manifest.name, isNotEmpty);

        // It reached the repository, not just memory.
        final stored = await composition.experienceRepository.listAll();
        expect(stored.map((e) => e.id), contains(created.experienceId));

        // Both model calls really happened, in order.
        expect(provider.prompts, hasLength(greaterThanOrEqualTo(2)));
        expect(provider.prompts.first, contains('Intent Understanding engine'));
        expect(
          provider.prompts.any((p) => p.contains('application architect')),
          isTrue,
        );
      },
    );

    test(
      'with NO active provider the same route still answers ProviderRequired — the refusal is real, not removed',
      () async {
        final composition = AppComposition.freshForTesting();
        addTearDown(() => composition.experienceRepository.close());

        final result = await composition.intentRouter.route(
          Intent.create(expression: 'a puzzle game that tracks my scores'),
        );

        expect(result.creationResult, isA<CreationProviderRequired>());
      },
    );

    test(
      'the refusal names the recovery, because a dead end is not an error message',
      () async {
        final composition = AppComposition.freshForTesting();
        addTearDown(() => composition.experienceRepository.close());

        final result = await composition.intentRouter.route(
          Intent.create(expression: 'a puzzle game that tracks my scores'),
        );

        final refusal = result.creationResult as CreationProviderRequired;
        expect(
          refusal.message,
          contains('Settings'),
          reason:
              'Telling a user something is missing without telling them '
              'where to fix it is the defect, not the fix.',
        );
      },
    );

    // Owner report: with a working key, "train ticket booking app" rendered as
    // the "City or location" search shell. The model returns a proper booking
    // records app but also asks for networkData; the repair pass then replaced
    // the records UI with the reference shell. It must stay a records app.
    test(
      'a booking app from the model is NOT turned into a search shell',
      () async {
        final composition = AppComposition.freshForTesting();
        addTearDown(() => composition.experienceRepository.close());
        composition.providerRegistry.registerProvider(_BookingModelProvider());
        await composition.providerRegistry.setActiveProvider('scripted');

        final result = await composition.intentRouter.route(
          Intent.create(
            expression: 'Create a professional train ticket booking app.',
          ),
        );
        final outcome = result.creationResult;
        expect(outcome, isA<CreationCreated>(),
            reason: outcome is CreationFailed
                ? '${outcome.error} / ${outcome.message}'
                : 'got ${outcome.runtimeType}');
        final probe =
            PackageCapabilityProbe((outcome as CreationCreated).package);
        expect(probe.hasEntityList || probe.hasEntityForm, isTrue,
            reason: 'a booking app must keep its records UI');
        final screenIds = outcome.package.interface.screens.map((s) => s.id);
        expect(screenIds, isNot(contains('reference_main')),
            reason: 'must not be replaced by the City-or-location shell');
      },
    );
  });

  // --------------------------------------------------------------- streaming

  group('IS-P07 streaming — the adapter speaks real SSE', () {
    ProviderException? classifyOf(dynamic e) =>
        e is ProviderException ? e : null;

    test('yields each delta as it arrives and stops at [DONE]', () async {
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: MockClient.streaming((_, body) async {
          expect(
            jsonDecode(await body.bytesToString())['stream'],
            isTrue,
            reason:
                'A streaming call that does not ask for a stream is a '
                'non-streaming call.',
          );
          return http.StreamedResponse(
            Stream.fromIterable(
              [
                'data: ${jsonEncode({
                  'choices': [
                    {
                      'delta': {'content': 'Hel'},
                    },
                  ],
                })}\n',
                'data: {"not":"json"\n', // malformed frame, must be survived
                ': keep-alive\n', // comment frame, must be ignored
                'data: ${jsonEncode({
                  'choices': [
                    {
                      'delta': {'content': 'lo'},
                    },
                  ],
                })}\n',
                'data: [DONE]\n',
                'data: ${jsonEncode({
                  'choices': [
                    {
                      'delta': {'content': 'AFTER-DONE'},
                    },
                  ],
                })}\n',
              ].map(utf8.encode),
            ),
            200,
          );
        }),
      );
      await provider.saveApiKey('gsk_x');

      final chunks = await provider
          .generateStream(
            const ModelRequest(messages: [ModelMessage.user('hi')]),
          )
          .toList();

      expect(chunks, ['Hel', 'lo']);
    });

    test('a chunk is delivered before the response completes', () async {
      final tap = StreamController<List<int>>();
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(tap.stream, 200),
        ),
      );
      await provider.saveApiKey('gsk_x');

      final received = <String>[];
      final done = provider
          .generateStream(
            const ModelRequest(messages: [ModelMessage.user('hi')]),
          )
          .listen(received.add);

      tap.add(
        utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'first'},
              },
            ],
          })}\n',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        received,
        ['first'],
        reason:
            'Incremental output is the entire point; if this only arrives '
            'at close, the adapter is buffering, not streaming.',
      );

      // Not awaited: cancelling a subscription means the controller's `close`
      // future has nobody left to complete it.
      unawaited(done.cancel());
    });

    test('cancelling the subscription stops the transfer', () async {
      var closed = false;
      final tap = StreamController<List<int>>(onCancel: () => closed = true);
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(tap.stream, 200),
        ),
      );
      await provider.saveApiKey('gsk_x');

      final sub = provider
          .generateStream(
            const ModelRequest(messages: [ModelMessage.user('hi')]),
          )
          .listen((_) {});
      // Put the generator inside its read loop before cancelling; cancelling a
      // generator that has not yet started has nothing to propagate.
      tap.add(
        utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'first'},
              },
            ],
          })}\n',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await sub.cancel().timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('cancel() never completed — the transfer leaks.'),
      );

      expect(closed, isTrue, reason: 'Cancelling must reach the socket.');
    });

    test('a rejected stream surfaces the classified failure, not the status '
        'code', () async {
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.value(utf8.encode(_decommissionedStreamBody)),
            400,
          ),
        ),
      );
      await provider.saveApiKey('gsk_x');

      final error = await provider
          .generateStream(
            const ModelRequest(messages: [ModelMessage.user('hi')]),
          )
          .toList()
          .then<Object?>((_) => null, onError: (Object e) => e);

      final classified = classifyOf(error);
      expect(classified, isNotNull, reason: 'got $error');
      expect(classified!.failure, ProviderFailure.modelDecommissioned);
      expect(classified.message, isNot(contains('400')));
    });

    test(
      'streaming without a key refuses before any socket is opened',
      () async {
        var called = false;
        final provider = OpenAiCompatibleProvider(
          descriptor: ProviderCatalogue.groq,
          client: MockClient.streaming((_, _) async {
            called = true;
            return http.StreamedResponse(const Stream.empty(), 200);
          }),
        );

        await expectLater(
          provider.generateStream(
            const ModelRequest(messages: [ModelMessage.user('hi')]),
          ),
          emitsError(
            isA<ProviderException>().having(
              (e) => e.failure,
              'failure',
              ProviderFailure.missingApiKey,
            ),
          ),
        );
        expect(called, isFalse);
      },
    );
  });

  group('IS-P22 — a pasted key is trimmed so generation does not 401', () {
    test('trailing whitespace in the saved key never reaches the header', () async {
      String? sentAuth;
      final provider = OpenAiCompatibleProvider(
        descriptor: ProviderCatalogue.groq,
        client: MockClient((request) async {
          sentAuth = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'ok'},
                },
              ],
            }),
            200,
          );
        }),
      );

      // A paste commonly carries a trailing newline/space. testConnection trims,
      // so the user sees success; generation must send the SAME clean key.
      await provider.saveApiKey('gsk_realkey123\n ');

      await provider.generate(
        const ModelRequest(messages: [ModelMessage.user('hi')]),
      );

      expect(sentAuth, 'Bearer gsk_realkey123',
          reason: 'a whitespace-corrupted Bearer header is what Groq 401s on');
    });
  });
}

const String _decommissionedStreamBody =
    '{"error":{"message":"The model `gemma2-9b-it` has been decommissioned and '
    'is no longer supported.","type":"invalid_request_error",'
    '"code":"model_decommissioned"}}';
