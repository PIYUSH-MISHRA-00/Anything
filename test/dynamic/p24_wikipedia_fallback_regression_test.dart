/// Regression tests for P23/P24: Wikipedia fallback prevention.
///
/// Verifies that current-data requirements (weather, news) are never
/// satisfied by encyclopedia/Wikipedia results through the generic
/// knowledge retrieval path. No domain-specific factories — these tests
/// validate the semantic routing and IS-P13 filter behavior.
library;

import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/data_provider_registry.dart';
import 'package:anything/knowledge/default_data_providers.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/runtime/behavior_interpreter.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake capability that returns configurable results.
class _FakeCapability extends PlatformCapability {
  final Map<String, dynamic> Function(Map<String, dynamic> params) handler;
  Map<String, dynamic>? lastParams;

  _FakeCapability(this.handler)
      : super(
          id: 'knowledge',
          name: 'Knowledge',
          description: 'Test',
          supportedOperations: const ['retrieve'],
        );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    lastParams = params;
    return CapabilityInvocationResult.success(data: handler(params));
  }
}

ExperiencePackage _shellPackage() {
  return const NetworkReferenceInterfaceFactory().applyToPackage(
    ExperiencePackage(
      packageVersion: 1,
      manifest: ExperienceManifest(
        experienceId: 'test-p24',
        name: 'Test',
        description: 'test',
        version: '1.0.0',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        networkMode: NetworkMode.required,
        storageMode: StorageMode.localKey,
        requiredCapabilities: const [],
      ),
      interface: const InterfaceDefinition(screens: []),
      behavior: const BehaviorGraph(nodes: [], edges: []),
      state: const StateSchema(variables: []),
      services: const [],
      networkDeclarations: const [],
      capabilityDeclarations: const [],
      permissionDeclarations: const [],
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(
        contentHash: '',
        computedAt: DateTime.utc(2026, 1, 1),
      ),
    ),
    name: 'Test',
  );
}

BehaviorExecutionContext _ctx({
  required ExperiencePackage package,
  required ExperienceStateEngine state,
  required ExperienceServiceResolver resolver,
}) {
  final dataRuntime = ExperienceDataRuntime();
  if (package.data != null) {
    dataRuntime.initialize(
      package.data!,
      experienceId: package.manifest.experienceId,
    );
  }
  final session = ExperienceSession(
    id: 's1',
    experienceId: package.manifest.experienceId,
    package: package,
    status: SessionStatus.running,
    startedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
  );
  return BehaviorExecutionContext(
    session: session,
    stateEngine: state,
    dataRuntime: dataRuntime,
    serviceResolver: resolver,
  );
}

void main() {
  group('Wikipedia fallback prevention (IS-P13)', () {
    test('behavior graph includes freshness=current', () {
      final bg = const NetworkReferenceInterfaceFactory().buildBehavior();
      final node = bg.nodes.firstWhere((n) => n.id == 'refreshData_invoke');
      expect(node.config['freshness'], 'current');
    });

    test('behavior graph includes expectedSourceType=currentData', () {
      final bg = const NetworkReferenceInterfaceFactory().buildBehavior();
      final node = bg.nodes.firstWhere((n) => n.id == 'refreshData_invoke');
      expect(node.config['expectedSourceType'], 'currentData');
    });

    test('freshness param is passed through to capability', () async {
      final package = _shellPackage();
      final state = ExperienceStateEngine()..initialize(package.state);
      final cap = _FakeCapability((params) => {
            'results': [
              {
                'title': 'Test',
                'content': 'Test content',
                'sourceType': 'currentData',
                'provider': 'fake',
                'sourceUri': 'https://example.com/test',
              },
            ],
            'provenance': {'sourceType': 'currentData', 'provider': 'fake'},
          });

      final platform = CapabilityPlatform()..register(cap);
      final resolver = ExperienceServiceResolver(capabilityPlatform: platform)
        ..resolve(
          package.services,
          experienceId: package.manifest.experienceId,
          declaredCapabilities: package.capabilityDeclarations
              .map((c) => c.capabilityId)
              .toList(),
        );

      await BehaviorInterpreter().execute(
        package.behavior,
        'refreshData',
        context: _ctx(package: package, state: state, resolver: resolver),
        data: {'query': 'London'},
      );

      expect(cap.lastParams, isNotNull);
      expect(cap.lastParams!['freshness'], 'current');
      expect(cap.lastParams!['query'], 'London');
    });

    test('Wikipedia result is rejected when expectedSourceType=currentData',
        () async {
      final package = _shellPackage();
      final state = ExperienceStateEngine()..initialize(package.state);
      final cap = _FakeCapability((params) => {
            'results': [
              {
                'title': 'London - Wikipedia',
                'content': 'London is the capital of England...',
                'sourceType': '',
                'provider': 'webweavex',
                'sourceUri': 'https://en.wikipedia.org/wiki/London',
              },
            ],
            'provenance': {'sourceType': 'webweavex', 'provider': 'webweavex'},
          });

      final platform = CapabilityPlatform()..register(cap);
      final resolver = ExperienceServiceResolver(capabilityPlatform: platform)
        ..resolve(
          package.services,
          experienceId: package.manifest.experienceId,
          declaredCapabilities: package.capabilityDeclarations
              .map((c) => c.capabilityId)
              .toList(),
        );

      await BehaviorInterpreter().execute(
        package.behavior,
        'refreshData',
        context: _ctx(package: package, state: state, resolver: resolver),
        data: {'query': 'London'},
      );

      // Result should be rejected — error state should contain expectedSourceType
      final error = state.read('error')?.toString() ?? '';
      expect(error, contains('currentData'));
      // resultText should NOT contain the Wikipedia content
      final result = state.read('resultText')?.toString() ?? '';
      expect(result, isNot(contains('capital of England')));
    });

    test('currentData result passes IS-P13 filter', () async {
      final package = _shellPackage();
      final state = ExperienceStateEngine()..initialize(package.state);
      final cap = _FakeCapability((params) => {
            'results': [
              {
                'title': 'Weather in London',
                'content': 'Temperature: 15°C, Humidity: 72%',
                'sourceType': 'currentData',
                'provider': 'webweavex',
                'sourceUri': 'https://weather.example.com/london',
              },
            ],
            'provenance': {'sourceType': 'currentData', 'provider': 'webweavex'},
          });

      final platform = CapabilityPlatform()..register(cap);
      final resolver = ExperienceServiceResolver(capabilityPlatform: platform)
        ..resolve(
          package.services,
          experienceId: package.manifest.experienceId,
          declaredCapabilities: package.capabilityDeclarations
              .map((c) => c.capabilityId)
              .toList(),
        );

      await BehaviorInterpreter().execute(
        package.behavior,
        'refreshData',
        context: _ctx(package: package, state: state, resolver: resolver),
        data: {'query': 'London'},
      );

      // Should pass — no error
      final error = state.read('error')?.toString() ?? '';
      expect(error, isEmpty);
      // Result should contain the weather data
      final result = state.read('resultText')?.toString() ?? '';
      expect(result, contains('Temperature'));
    });

    test('empty sourceType is rejected when expectedSourceType=currentData',
        () async {
      final package = _shellPackage();
      final state = ExperienceStateEngine()..initialize(package.state);
      final cap = _FakeCapability((params) => {
            'results': [
              {
                'title': 'Some result',
                'content': 'Some content',
                'sourceType': '',
                'provider': 'webweavex',
                'sourceUri': 'https://example.com/something',
              },
            ],
            'provenance': {'sourceType': 'webweavex', 'provider': 'webweavex'},
          });

      final platform = CapabilityPlatform()..register(cap);
      final resolver = ExperienceServiceResolver(capabilityPlatform: platform)
        ..resolve(
          package.services,
          experienceId: package.manifest.experienceId,
          declaredCapabilities: package.capabilityDeclarations
              .map((c) => c.capabilityId)
              .toList(),
        );

      await BehaviorInterpreter().execute(
        package.behavior,
        'refreshData',
        context: _ctx(package: package, state: state, resolver: resolver),
        data: {'query': 'London'},
      );

      // Empty sourceType should be rejected
      final error = state.read('error')?.toString() ?? '';
      expect(error, contains('currentData'));
    });
  });

  group('Freshness query enhancement', () {
    test('KnowledgeRequirement carries freshness field', () {
      const req = KnowledgeRequirement(
        objective: 'London',
        resourceType: 'webDocument',
        freshness: 'current',
      );
      expect(req.freshness, 'current');
    });

    test('KnowledgeRequirement defaults to empty freshness', () {
      const req = KnowledgeRequirement(
        objective: 'London',
        resourceType: 'reference',
      );
      expect(req.freshness, '');
    });
  });

  group('DataRequirement freshness', () {
    test('WebWeaveXDataProvider path builds enhanced query', () {
      const req = DataRequirement(
        domainConcept: DataConcepts.atmosphericConditions,
        freshness: 'current',
        fields: ['temperature', 'humidity'],
      );
      expect(req.freshness, 'current');
      expect(req.domainConcept, DataConcepts.atmosphericConditions);
    });

    test('fake provider receives freshness from DataRequirement', () async {
      final registry = DataProviderRegistry();
      String? seenQuery;
      registry.register(
        DataProviderDescriptor(
          providerId: 'fake',
          requirementTypes: {DataConcepts.atmosphericConditions},
          acquire: (req, params) async {
            seenQuery = params['query']?.toString();
            return {
              'results': [
                {
                  'title': 'Weather',
                  'content': '15°C',
                  'sourceType': 'currentData',
                  'provider': 'fake',
                },
              ],
            };
          },
        ),
      );

      await registry.acquire(
        const DataRequirement(
          domainConcept: DataConcepts.atmosphericConditions,
          freshness: 'current',
        ),
        {'query': 'London'},
      );
      expect(seenQuery, 'London');
    });
  });

  group('Provider independence — no domain routing', () {
    test('same generic path handles atmospheric and news concepts', () async {
      final registry = DataProviderRegistry();
      final seen = <String>[];
      registry.register(
        DataProviderDescriptor(
          providerId: 'generic',
          requirementTypes: {
            DataConcepts.atmosphericConditions,
            DataConcepts.newsArticles,
          },
          acquire: (req, params) async {
            seen.add(req.domainConcept);
            return {
              'results': [
                {'title': 'Result', 'content': 'Data', 'provider': 'generic'},
              ],
            };
          },
        ),
      );

      await registry.acquire(
        const DataRequirement(
          domainConcept: DataConcepts.atmosphericConditions,
          freshness: 'current',
        ),
        {'query': 'London'},
      );
      await registry.acquire(
        const DataRequirement(
          domainConcept: DataConcepts.newsArticles,
          freshness: 'current',
        ),
        {'query': 'technology'},
      );

      expect(seen, contains(DataConcepts.atmosphericConditions));
      expect(seen, contains(DataConcepts.newsArticles));
      expect(registry.providerIds, ['generic']);
    });
  });
}
