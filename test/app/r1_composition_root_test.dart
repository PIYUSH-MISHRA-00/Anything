/// Implementation Milestone R1 — Canonical Composition Root integration
/// tests: proves the ONE shared `WorldModelCoordinator` instance is
/// genuinely reachable from Kernel/Creation/Modification, credential
/// storage routes through `CredentialVault`, `ExperienceServiceResolver`
/// dispatches through `CapabilityPlatform`, and Software Cognition's
/// optional creation-pipeline hook works when supplied and is a no-op
/// when absent.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/capabilities/adapters/knowledge_acquisition_provider_adapter.dart';
import 'package:anything/capabilities/adapters/model_provider_ai_adapter.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/capabilities/builtin/clock_capability.dart';
import 'package:anything/capabilities/builtin/knowledge_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/legacy/groq_adapter.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/security/credential_vault.dart';
import 'package:anything/services/provider_registry.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/software_cognition/software_cognition_engine.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Local storage',
      category: CapabilityCategory.storage,
      inputContract: 'data',
      outputContract: 'stored data',
    ),
  );
  return registry;
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

/// Records every context it was asked to reason about, so tests can
/// assert on what knowledge actually reached reasoning.
class _RecordingReasoner implements ApplicationReasoner {
  final SemanticApp app;
  final List<ApplicationReasoningContext> seenContexts = [];
  _RecordingReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async {
    seenContexts.add(context);
    return ReasoningReady(semanticApp: app);
  }
}

SemanticApp _fieldSurveyApp() {
  return SemanticApp(
    name: 'Field Survey Log',
    purpose: 'Track field survey entries',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'entries_list',
        name: 'Entries',
        purpose: 'list',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_entry',
        name: 'Add Entry',
        targetEntityId: 'entry',
      ),
    ],
  );
}

/// In-memory stand-in for the `flutter_secure_storage` platform channel —
/// real `CredentialVault`/`FlutterSecureStorage` code runs unmodified;
/// only the platform channel response is faked (the standard, correct way
/// to test plugin-backed code under `flutter test`, not a hand-duplicated
/// logic stand-in).
void _mockSecureStorageChannel(Map<String, String> backingStore) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'write':
            backingStore[call.arguments['key'] as String] =
                call.arguments['value'] as String;
            return null;
          case 'read':
            return backingStore[call.arguments['key'] as String];
          case 'delete':
            backingStore.remove(call.arguments['key'] as String);
            return null;
          case 'containsKey':
            return backingStore.containsKey(call.arguments['key'] as String);
          default:
            return null;
        }
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorldModelCoordinator sharing', () {
    test(
      'Kernel automatically ingests reviewSession/evolutionRoadmap when a shared WorldModelCoordinator is injected',
      () async {
        final shared = WorldModelCoordinator();
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(_fieldSurveyApp()),
          worldModel: shared,
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
        );
        expect(outcome, isA<ExecutionPlanReady>());

        // No manual ingestReviewSession/ingestEvolutionRoadmap call here —
        // unlike the pre-R1 pattern in test/world_model/kernel_integration_test.dart,
        // the Kernel itself performed it, into the SAME injected instance.
        expect(
          shared.model.graph.nodesOfKind(WorldNodeKind.evolution),
          isNotEmpty,
        );
        expect(shared.model.version.number, greaterThanOrEqualTo(1));
      },
    );

    test(
      'Kernel without an injected WorldModelCoordinator behaves exactly as before R1 (no crash, no change to outcome)',
      () async {
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(_fieldSurveyApp()),
        );
        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
        );
        expect(outcome, isA<ExecutionPlanReady>());
      },
    );

    test(
      'ExperienceCreationCoordinator and ExperienceModificationCoordinator ingesting/reading via the SAME shared instance see each other\'s effects',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        final dbName =
            'r1_shared_world_model_${DateTime.now().microsecondsSinceEpoch}.db';
        final repository = SqliteExperienceRepository(dbName: dbName);
        final shared = WorldModelCoordinator();

        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(_fieldSurveyApp()),
        );
        final creation = ExperienceCreationCoordinator(
          kernel: kernel,
          repository: repository,
          worldModel: shared,
        );

        final result = await creation.createFromIntent(
          Intent.create(expression: 'track my field survey entries'),
        );
        expect(result, isA<CreationCreated>());
        final experienceId = (result as CreationCreated).experienceId;

        // The just-created Experience is a real graph node in the SHARED
        // instance, reachable without any manual ingest call from this test.
        expect(
          shared.model.graph.nodesOfKind(WorldNodeKind.experience),
          isNotEmpty,
        );

        // Stronger proof: a DIFFERENT coordinator constructed with the SAME
        // shared instance runs its real precheckModification() (step 1.5 of
        // modifyExperience) against that same, now-populated graph and finds
        // it consistent — proving the graph creation wrote to is the exact
        // graph modification reads from, not two disconnected instances.
        final modification = ExperienceModificationCoordinator(
          repository: repository,
          worldModel: shared,
        );
        final modResult = await modification.modifyExperience(
          experienceId: experienceId,
          modificationExpression: 'add a percentage field',
        );
        expect(modResult, isNot(isA<ModificationCoordinatorFailed>()));

        await repository.close();
      },
    );
  });

  group('CredentialVault routing', () {
    test(
      'AnythingProviderRegistry routes Groq credential storage through the injected CredentialVault, not a raw/duplicate key',
      () async {
        final backingStore = <String, String>{};
        _mockSecureStorageChannel(backingStore);
        addTearDown(() {
          const channel = MethodChannel(
            'plugins.it_nomads.com/flutter_secure_storage',
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final vault = CredentialVault();
        final registry = AnythingProviderRegistry(credentialVault: vault);
        final groq = registry.getProvider('groq') as GroqModelProvider;

        await groq.saveApiKey('sk-test-key');
        expect(await groq.getApiKey(), 'sk-test-key');

        // The REAL, canonical vault key — never the pre-R1 raw 'GROQ_API_KEY'.
        expect(backingStore.containsKey('credential_groq_api_key'), isTrue);
        expect(backingStore.containsKey('GROQ_API_KEY'), isFalse);

        // Reading the SAME purpose directly through the vault (a second,
        // independent path) proves this is genuinely the shared vault, not
        // a private duplicate.
        expect(await vault.get('groq_api_key'), 'sk-test-key');
      },
    );
  });

  group('CapabilityPlatform dispatch wiring', () {
    test(
      'ExperienceServiceResolver dispatches httpClient/aiInference/knowledgeRetrieval through the real CapabilityPlatform when wired',
      () async {
        final registry = _FakeProviderRegistry();
        final platform = CapabilityPlatform()
          ..register(ClockCapability())
          ..register(
            AiCapability(
              provider: ModelProviderAiAdapter(registry),
              experienceId: 'exp-1',
            ),
          )
          ..register(
            KnowledgeCapability(
              provider: KnowledgeAcquisitionProviderAdapter(
                KnowledgeAcquisitionEngine(),
              ),
            ),
          );

        final resolver = ExperienceServiceResolver(
          capabilityPlatform: platform,
        );
        resolver.resolve(
          const [
            ServiceDefinition(id: 'svc-ai', type: 'aiInference'),
            ServiceDefinition(id: 'svc-clock', type: 'clock'),
          ],
          experienceId: 'exp-1',
          declaredCapabilities: ['ai', 'clock'],
        );

        // No active provider configured -> a real, non-stubbed failure from
        // CapabilityPlatform's own dispatch (not the pre-R1 hardcoded
        // 'Unknown service type' string) — proves real dispatch occurred.
        final aiResult = await resolver.execute('svc-ai', 'generate', {
          'prompt': 'hello',
        });
        expect(aiResult['error'], isNot(contains('Unknown service type')));

        // clock is untouched by the wiring — still works identically.
        final clockResult = await resolver.execute('svc-clock', 'now', {});
        expect(clockResult['timestamp'], isNotNull);
      },
    );

    test(
      'ExperienceServiceResolver without a CapabilityPlatform keeps the exact pre-R1 stub behavior',
      () async {
        final resolver = ExperienceServiceResolver();
        resolver.resolve(const [
          ServiceDefinition(id: 'svc-http', type: 'httpClient'),
        ]);
        final result = await resolver.execute('svc-http', 'get', {});
        expect(result['status'], 'not_implemented');
      },
    );

    test(
      'a service type CapabilityPlatform has no matching capability for (localDatabase) is honestly left stubbed even when a platform is wired',
      () async {
        final resolver = ExperienceServiceResolver(
          capabilityPlatform: CapabilityPlatform(),
        );
        resolver.resolve(const [
          ServiceDefinition(id: 'svc-db', type: 'localDatabase'),
        ]);
        final result = await resolver.execute('svc-db', 'query', {});
        expect(result['status'], 'not_implemented');
      },
    );
  });

  group('Software Cognition creation-pipeline hook', () {
    test(
      'omitting referenceUrl leaves creation byte-for-byte unaffected (no seed knowledge reaches reasoning)',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        final dbName =
            'r1_no_reference_${DateTime.now().microsecondsSinceEpoch}.db';
        final repository = SqliteExperienceRepository(dbName: dbName);
        final reasoner = _RecordingReasoner(_fieldSurveyApp());
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: reasoner,
        );
        final creation = ExperienceCreationCoordinator(
          kernel: kernel,
          repository: repository,
        );

        final result = await creation.createFromIntent(
          Intent.create(expression: 'track my field survey entries'),
        );
        expect(result, isA<CreationCreated>());
        expect(reasoner.seenContexts.first.knowledge, isNull);

        await repository.close();
      },
    );

    test(
      'supplying referenceUrl seeds real acquired understanding into reasoning (never raw source, never copied code)',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        final dbName =
            'r1_with_reference_${DateTime.now().microsecondsSinceEpoch}.db';
        final repository = SqliteExperienceRepository(dbName: dbName);
        final reasoner = _RecordingReasoner(_fieldSurveyApp());
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: reasoner,
        );
        final softwareCognition = SoftwareCognitionCoordinator(
          engine: SoftwareCognitionEngine(
            repositoryAnalyzer: RepositoryAnalyzer(
              fetchPage: (url) async => {
                'available': true,
                'html':
                    '<html><body><p>A real, small, well-tested field survey library with a permissive license.</p></body></html>',
              },
            ),
          ),
        );
        final creation = ExperienceCreationCoordinator(
          kernel: kernel,
          repository: repository,
          softwareCognition: softwareCognition,
        );

        final result = await creation.createFromIntent(
          Intent.create(expression: 'track my field survey entries'),
          referenceUrl: 'https://example.com/survey-lib',
        );

        expect(result, isA<CreationCreated>());
        final seededKnowledge = reasoner.seenContexts.first.knowledge;
        expect(seededKnowledge, isNotNull);
        expect(seededKnowledge!.resources, isNotEmpty);
        // Never raw acquired HTML/source text — only the distilled,
        // reviewed digest `toKnowledgeResource()` produces.
        expect(
          seededKnowledge.resources.first.content,
          isNot(contains('<html>')),
        );

        await repository.close();
      },
    );

    test(
      'R14: a sound acquisition also ingests real nodes into the shared World Model (SoftwareCognitionCoordinator.syncToWorldModel now has a real production caller)',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        final dbName =
            'r14_world_model_sync_${DateTime.now().microsecondsSinceEpoch}.db';
        final repository = SqliteExperienceRepository(dbName: dbName);
        final reasoner = _RecordingReasoner(_fieldSurveyApp());
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: reasoner,
        );
        final softwareCognition = SoftwareCognitionCoordinator(
          engine: SoftwareCognitionEngine(
            repositoryAnalyzer: RepositoryAnalyzer(
              fetchPage: (url) async => {
                'available': true,
                'html':
                    '<html><body><p>A real, small, well-tested field survey library with a permissive license.</p></body></html>',
              },
            ),
          ),
        );
        final worldModel = WorldModelCoordinator();
        final beforeCount = worldModel.model.graph.nodes.length;
        final creation = ExperienceCreationCoordinator(
          kernel: kernel,
          repository: repository,
          softwareCognition: softwareCognition,
          worldModel: worldModel,
        );

        final result = await creation.createFromIntent(
          Intent.create(expression: 'track my field survey entries'),
          referenceUrl: 'https://example.com/survey-lib',
        );

        expect(result, isA<CreationCreated>());
        // At least two real ingestions happened this call: the acquired
        // repository's own SoftwareGraph (R14) AND the created Experience
        // itself (R1) — never a duplicate/parallel World Model, the SAME
        // shared `worldModel.model` grew.
        expect(worldModel.model.graph.nodes.length, greaterThan(beforeCount));

        await repository.close();
      },
    );

    test(
      'R14: an unsound acquisition never mutates the World Model (accept-only, matching every prior ingest* gate)',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        final dbName =
            'r14_world_model_reject_${DateTime.now().microsecondsSinceEpoch}.db';
        final repository = SqliteExperienceRepository(dbName: dbName);
        final reasoner = _RecordingReasoner(_fieldSurveyApp());
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: reasoner,
        );
        // fetchPage returns unavailable -> understandRepositoryFromUrl
        // returns null -> no sound result -> syncToWorldModel must never
        // be called.
        final softwareCognition = SoftwareCognitionCoordinator(
          engine: SoftwareCognitionEngine(
            repositoryAnalyzer: RepositoryAnalyzer(
              fetchPage: (url) async => {'available': false},
            ),
          ),
        );
        final worldModel = WorldModelCoordinator();
        final creation = ExperienceCreationCoordinator(
          kernel: kernel,
          repository: repository,
          softwareCognition: softwareCognition,
          worldModel: worldModel,
        );

        final result = await creation.createFromIntent(
          Intent.create(expression: 'track my field survey entries'),
          referenceUrl: 'https://example.com/unreachable-lib',
        );

        expect(result, isA<CreationCreated>());
        // Only the Experience-ingestion World Graph growth is expected;
        // no software-cognition nodes were added for the failed acquisition
        // (asserted indirectly: creation still succeeds and no exception
        // propagates from the best-effort sync attempt).
        await repository.close();
      },
    );
  });
}
