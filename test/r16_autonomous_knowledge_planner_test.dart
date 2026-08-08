/// Implementation Milestone R16 — Autonomous Knowledge Acquisition
/// Planner, Intent-Driven Software Discovery. Proves the real gap this
/// milestone closes: `SemanticApp.knowledgeNeeds` (a real field the SINGLE
/// existing reasoning call already populates on its final result) was
/// never read by anything downstream before this milestone — confirmed by
/// repository-wide grep. R16 adds a deterministic
/// `AutonomousKnowledgeAcquisitionPlanner` that turns that already-real
/// signal into real `SearchProvider` lookups and real Software Cognition
/// acquisitions, opt-in via `autoDiscoverKnowledge`, with zero new LLM
/// calls and zero human-supplied reference URLs required — never a second
/// Knowledge Engine, SearchProvider, Software Cognition Engine, World
/// Model, AI Boundary, or Compiler.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/knowledge/autonomous_knowledge_planner.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/software_cognition/software_cognition_engine.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';

// ── Shared fixtures (mirroring test/r15_multi_source_software_cognition_test.dart's
// established shape — a test file cannot import another test file's
// private helpers, so equivalents are redeclared minimally). ─────────────

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

class _RecordingReasoner implements ApplicationReasoner {
  final SemanticApp app;
  _RecordingReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(
    ApplicationReasoningContext context,
  ) async => ReasoningReady(semanticApp: app);
}

SemanticApp _fieldSurveyApp({
  List<SynthesisKnowledgeRequirement> knowledgeNeeds = const [],
}) => SemanticApp(
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
    SemanticAction(id: 'add_entry', name: 'Add Entry', targetEntityId: 'entry'),
  ],
  knowledgeNeeds: knowledgeNeeds,
);

void _mockSecureStorageChannel() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'read':
          case 'containsKey':
            return null;
          default:
            return null;
        }
      });
}

RepositoryAnalyzer _analyzerFor(Map<String, List<String>> dependenciesByUrl) =>
    RepositoryAnalyzer(
      fetchPage: (url) async {
        final deps = dependenciesByUrl[url];
        if (deps == null) return {'available': false};
        final html =
            '<html><body>${deps.map((d) => '<p>$d</p>').join()}</body></html>';
        return {'available': true, 'html': html};
      },
    );

/// A fake `SearchProvider` mapping a fixed set of queries to candidate
/// URLs — never real network I/O, matching every prior milestone's
/// test-fixture convention.
class _FakeSearchProvider implements SearchProvider {
  final Map<String, List<String>> urlsByQuery;
  int callCount = 0;
  _FakeSearchProvider(this.urlsByQuery);

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    callCount++;
    final urls = urlsByQuery[query] ?? const [];
    return urls.take(maxResults).map((u) => SearchResult(url: u)).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'AutonomousKnowledgeAcquisitionPlanner (R16) — deterministic, zero new LLM calls',
    () {
      test(
        'an app with no knowledgeNeeds produces an empty plan, never fabricated targets',
        () {
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(
            _fieldSurveyApp(),
          );
          expect(plan.targets, isEmpty);
          expect(plan.actionableTargets, isEmpty);
        },
      );

      test(
        'a single-domain intent (one repository need) produces one actionable target',
        () {
          final app = _fieldSurveyApp(
            knowledgeNeeds: const [
              SynthesisKnowledgeRequirement(
                id: 'k1',
                purpose: 'find a similar survey app',
                query: 'field survey app',
                required: true,
                resourceType: 'repository',
              ),
            ],
          );
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
          expect(plan.actionableTargets, hasLength(1));
          expect(
            plan.actionableTargets.single.sourceCategory,
            KnowledgeSourceCategory.repository,
          );
          expect(plan.actionableTargets.single.evidenceRequirement, isTrue);
          expect(
            plan.actionableTargets.single.confidence,
            closeTo(0.8, 0.0001),
          );
        },
      );

      test(
        'a cross-domain intent (repository + package needs) produces two distinct actionable targets, required first',
        () {
          final app = _fieldSurveyApp(
            knowledgeNeeds: const [
              SynthesisKnowledgeRequirement(
                id: 'k1',
                purpose: 'optional helper package',
                query: 'survey form widgets',
                required: false,
                resourceType: 'package',
              ),
              SynthesisKnowledgeRequirement(
                id: 'k2',
                purpose: 'core reference app',
                query: 'field survey app',
                required: true,
                resourceType: 'repository',
              ),
            ],
          );
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
          expect(plan.actionableTargets, hasLength(2));
          // Required (k2) must be ranked before optional (k1) regardless of
          // original list order.
          expect(plan.targets.first.id, 'k2');
          expect(plan.targets.last.id, 'k1');
          expect(plan.targets.map((t) => t.sourceCategory).toSet(), {
            KnowledgeSourceCategory.repository,
            KnowledgeSourceCategory.package,
          });
        },
      );

      test(
        'an ambiguous need (resourceType the reasoner never actually emits per model_reasoner.dart\'s prompt) is planned but NOT actionable — never fabricates a repository search for generic domain knowledge',
        () {
          final app = _fieldSurveyApp(
            knowledgeNeeds: const [
              SynthesisKnowledgeRequirement(
                id: 'k1',
                purpose: 'general context',
                query: 'field survey best practices',
                required: false,
              ),
            ],
          );
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
          expect(plan.targets, hasLength(1));
          expect(
            plan.targets.single.sourceCategory,
            KnowledgeSourceCategory.general,
          );
          expect(
            plan.actionableTargets,
            isEmpty,
            reason:
                'domainKnowledge/general targets are named but never actioned by this milestone',
          );
        },
      );

      test(
        'a need with an empty query is honestly dropped, never turned into an empty-string search',
        () {
          final app = _fieldSurveyApp(
            knowledgeNeeds: const [
              SynthesisKnowledgeRequirement(
                id: 'k1',
                purpose: 'x',
                query: '  ',
                required: true,
                resourceType: 'repository',
              ),
            ],
          );
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
          expect(plan.targets, isEmpty);
        },
      );

      test(
        'documentation/api categories are recognized but never actionable (Software Cognition understands repositories, not arbitrary docs)',
        () {
          final app = _fieldSurveyApp(
            knowledgeNeeds: const [
              SynthesisKnowledgeRequirement(
                id: 'k1',
                purpose: 'p1',
                query: 'q1',
                required: true,
                resourceType: 'externalApi',
              ),
              SynthesisKnowledgeRequirement(
                id: 'k2',
                purpose: 'p2',
                query: 'q2',
                required: true,
                resourceType: 'technicalReference',
              ),
            ],
          );
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
          expect(plan.targets.map((t) => t.sourceCategory).toSet(), {
            KnowledgeSourceCategory.api,
            KnowledgeSourceCategory.documentation,
          });
          expect(plan.actionableTargets, isEmpty);
        },
      );
    },
  );

  group('KnowledgeAcquisitionEngine.searchProvider getter (R16)', () {
    test(
      'exposes the SAME provider instance passed to the constructor — never a second one',
      () {
        final provider = _FakeSearchProvider(const {});
        final engine = KnowledgeAcquisitionEngine(searchProvider: provider);
        expect(identical(engine.searchProvider, provider), isTrue);
      },
    );

    test(
      'a bare engine (no provider configured) exposes null, never a fabricated default',
      () {
        expect(KnowledgeAcquisitionEngine().searchProvider, isNull);
      },
    );
  });

  group('AnythingKernel autonomous discovery (R16 centerpiece)', () {
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      SharedPreferences.setMockInitialValues({});
      _mockSecureStorageChannel();
    });

    test(
      'autoDiscoverKnowledge:true with a real repository need corroborates across search results end-to-end into corroboratedPatterns, with NO human-supplied reference URL',
      () async {
        final app = _fieldSurveyApp(
          knowledgeNeeds: const [
            SynthesisKnowledgeRequirement(
              id: 'k1',
              purpose: 'similar survey apps',
              query: 'field survey tracker',
              required: true,
              resourceType: 'repository',
            ),
          ],
        );
        final searchProvider = _FakeSearchProvider({
          'field survey tracker': [
            'https://example-a.com/repo',
            'https://example-b.com/repo',
          ],
        });
        final softwareCognition = SoftwareCognitionCoordinator(
          engine: SoftwareCognitionEngine(
            repositoryAnalyzer: _analyzerFor({
              'https://example-a.com/repo': ['flutter', 'sqflite'],
              'https://example-b.com/repo': ['flutter', 'http'],
            }),
          ),
        );
        final worldModel = WorldModelCoordinator();
        final beforeCount = worldModel.model.graph.nodes.length;
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(app),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: searchProvider,
          ),
          softwareCognition: softwareCognition,
          worldModel: worldModel,
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
          autoDiscoverKnowledge: true,
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final model =
            (outcome as ExecutionPlanReady).canonicalImplementationModel!;
        expect(
          model.corroboratedPatterns,
          isNotEmpty,
          reason:
              'two search results corroborating "flutter" must reach corroboratedPatterns with zero human-supplied URLs',
        );
        expect(
          model.corroboratedPatterns.any((p) => p.name == 'flutter'),
          isTrue,
        );
        expect(
          model.corroboratedPatterns
              .firstWhere((p) => p.name == 'flutter')
              .supportingSourceCount,
          2,
        );
        expect(searchProvider.callCount, 1);
        expect(
          worldModel.model.graph.nodes.length,
          greaterThan(beforeCount),
          reason:
              'autonomously-discovered repositories must sync into the shared World Model',
        );
      },
    );

    test(
      'autoDiscoverKnowledge:false (the default) never calls search, even with real actionable knowledgeNeeds present — byte-for-byte backward compatible',
      () async {
        final app = _fieldSurveyApp(
          knowledgeNeeds: const [
            SynthesisKnowledgeRequirement(
              id: 'k1',
              purpose: 'p',
              query: 'field survey tracker',
              required: true,
              resourceType: 'repository',
            ),
          ],
        );
        final searchProvider = _FakeSearchProvider({
          'field survey tracker': [
            'https://example-a.com/repo',
            'https://example-b.com/repo',
          ],
        });
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(app),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: searchProvider,
          ),
          softwareCognition: SoftwareCognitionCoordinator(),
        );

        // autoDiscoverKnowledge omitted — must default to false.
        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final model =
            (outcome as ExecutionPlanReady).canonicalImplementationModel!;
        expect(model.corroboratedPatterns, isEmpty);
        expect(
          searchProvider.callCount,
          0,
          reason: 'opt-in flag must gate every search call',
        );
      },
    );

    test(
      'an empty/knowledge-free intent (no knowledgeNeeds) with autoDiscoverKnowledge:true produces an honest empty result, never an error',
      () async {
        final searchProvider = _FakeSearchProvider(const {});
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(_fieldSurveyApp()),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: searchProvider,
          ),
          softwareCognition: SoftwareCognitionCoordinator(),
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
          autoDiscoverKnowledge: true,
        );

        expect(outcome, isA<ExecutionPlanReady>());
        expect(
          (outcome as ExecutionPlanReady)
              .canonicalImplementationModel!
              .corroboratedPatterns,
          isEmpty,
        );
        expect(searchProvider.callCount, 0);
      },
    );

    test(
      'a single search result (ambiguous/insufficient evidence) is honestly not corroborated — the same 2-source gate R14/R15 documented, never fabricated from one source',
      () async {
        final app = _fieldSurveyApp(
          knowledgeNeeds: const [
            SynthesisKnowledgeRequirement(
              id: 'k1',
              purpose: 'p',
              query: 'field survey tracker',
              required: true,
              resourceType: 'repository',
            ),
          ],
        );
        final searchProvider = _FakeSearchProvider({
          'field survey tracker': ['https://example-a.com/repo'],
        });
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(app),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: searchProvider,
          ),
          softwareCognition: SoftwareCognitionCoordinator(
            engine: SoftwareCognitionEngine(
              repositoryAnalyzer: _analyzerFor({
                'https://example-a.com/repo': ['flutter'],
              }),
            ),
          ),
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
          autoDiscoverKnowledge: true,
        );

        expect(outcome, isA<ExecutionPlanReady>());
        expect(
          (outcome as ExecutionPlanReady)
              .canonicalImplementationModel!
              .corroboratedPatterns,
          isEmpty,
        );
      },
    );

    test(
      'a search/acquisition failure never fails creation — best-effort, matching every other optional-enhancement contract',
      () async {
        final app = _fieldSurveyApp(
          knowledgeNeeds: const [
            SynthesisKnowledgeRequirement(
              id: 'k1',
              purpose: 'p',
              query: 'field survey tracker',
              required: true,
              resourceType: 'repository',
            ),
          ],
        );
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(app),
          // No SearchProvider configured on this engine — `searchProvider`
          // getter returns null, so the autonomous step must no-op cleanly.
          knowledgeEngine: KnowledgeAcquisitionEngine(),
          softwareCognition: SoftwareCognitionCoordinator(),
        );

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
          autoDiscoverKnowledge: true,
        );

        expect(outcome, isA<ExecutionPlanReady>());
        expect(
          (outcome as ExecutionPlanReady)
              .canonicalImplementationModel!
              .corroboratedPatterns,
          isEmpty,
        );
      },
    );

    test(
      'R15\'s manual referenceUrls path and R16\'s autonomous discovery compose additively when both are supplied to the Kernel',
      () async {
        final app = _fieldSurveyApp(
          knowledgeNeeds: const [
            SynthesisKnowledgeRequirement(
              id: 'k1',
              purpose: 'p',
              query: 'field survey tracker',
              required: true,
              resourceType: 'repository',
            ),
          ],
        );
        final searchProvider = _FakeSearchProvider({
          'field survey tracker': [
            'https://auto-a.com/repo',
            'https://auto-b.com/repo',
          ],
        });
        final softwareCognition = SoftwareCognitionCoordinator(
          engine: SoftwareCognitionEngine(
            repositoryAnalyzer: _analyzerFor({
              'https://auto-a.com/repo': ['flutter'],
              'https://auto-b.com/repo': ['flutter'],
              'https://manual-a.com/repo': ['django'],
              'https://manual-b.com/repo': ['django'],
            }),
          ),
        );
        final kernel = AnythingKernel(
          providerRegistry: _FakeProviderRegistry(),
          capabilityRegistry: _registryWithStorage(),
          reasoner: _RecordingReasoner(app),
          knowledgeEngine: KnowledgeAcquisitionEngine(
            searchProvider: searchProvider,
          ),
          softwareCognition: softwareCognition,
        );

        // Manually pre-corroborated via the same reasoner directly (mirrors
        // what ExperienceCreationCoordinator._acquireSoftwareCognitionSeeds
        // would have produced from two human-supplied referenceUrls).
        final manualRepoA = RepositoryAnalyzer().analyze(
          RepositoryContext(
            source: 'django\n',
            metadata: RepositoryMetadata(
              name: 'manual-a',
              description: '',
              primaryLanguage: 'py',
              provenance: SoftwareProvenance(
                sourceUrl: 'https://manual-a.com/repo',
                retrievedAt: DateTime(2026, 8, 3),
                provider: 't',
                license: const LicenseMetadata(
                  policy: LicensePolicy.permissiveKnown,
                  licenseId: 'MIT',
                ),
              ),
            ),
          ),
        );
        final manualRepoB = RepositoryAnalyzer().analyze(
          RepositoryContext(
            source: 'django\n',
            metadata: RepositoryMetadata(
              name: 'manual-b',
              description: '',
              primaryLanguage: 'py',
              provenance: SoftwareProvenance(
                sourceUrl: 'https://manual-b.com/repo',
                retrievedAt: DateTime(2026, 8, 3),
                provider: 't',
                license: const LicenseMetadata(
                  policy: LicensePolicy.permissiveKnown,
                  licenseId: 'MIT',
                ),
              ),
            ),
          ),
        );
        final manualRecommendations = softwareCognition.reasoner
            .reasonAboutRepositories([manualRepoA, manualRepoB])
            .where((r) => r.accepted)
            .toList();
        expect(manualRecommendations, isNotEmpty);

        final outcome = await kernel.processIntent(
          Intent.create(expression: 'track my field survey entries'),
          corroboratingRecommendations: manualRecommendations,
          autoDiscoverKnowledge: true,
        );

        expect(outcome, isA<ExecutionPlanReady>());
        final patterns = (outcome as ExecutionPlanReady)
            .canonicalImplementationModel!
            .corroboratedPatterns;
        expect(
          patterns.any((p) => p.name == 'django'),
          isTrue,
          reason: 'manually-supplied corroboration must survive',
        );
        expect(
          patterns.any((p) => p.name == 'flutter'),
          isTrue,
          reason:
              'autonomously-discovered corroboration must also be present — both compose',
        );
      },
    );
  });

  group(
    'Performance (R16) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test('planning latency for a large plan (100 knowledgeNeeds)', () {
        final needs = [
          for (var i = 0; i < 100; i++)
            SynthesisKnowledgeRequirement(
              id: 'k$i',
              purpose: 'p$i',
              query: 'q$i',
              required: i.isEven,
              resourceType: i.isEven ? 'repository' : 'package',
            ),
        ];
        final app = _fieldSurveyApp(knowledgeNeeds: needs);

        final stopwatch = Stopwatch()..start();
        final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
        stopwatch.stop();

        expect(plan.actionableTargets, hasLength(100));
        // ignore: avoid_print
        print(
          'R16 planning latency (100 knowledgeNeeds): ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test(
        'search + acquisition latency over 10 actionable targets (fake provider/fetch, no real network)',
        () async {
          final needs = [
            for (var i = 0; i < 10; i++)
              SynthesisKnowledgeRequirement(
                id: 'k$i',
                purpose: 'p',
                query: 'query-$i',
                required: true,
                resourceType: 'repository',
              ),
          ];
          final app = _fieldSurveyApp(knowledgeNeeds: needs);
          final searchProvider = _FakeSearchProvider({
            for (var i = 0; i < 10; i++)
              'query-$i': ['https://repo-$i-a.com', 'https://repo-$i-b.com'],
          });
          final softwareCognition = SoftwareCognitionCoordinator(
            engine: SoftwareCognitionEngine(
              repositoryAnalyzer: _analyzerFor({
                for (var i = 0; i < 10; i++) ...{
                  'https://repo-$i-a.com': ['flutter'],
                  'https://repo-$i-b.com': ['flutter'],
                },
              }),
            ),
          );
          final kernel = AnythingKernel(
            providerRegistry: _FakeProviderRegistry(),
            capabilityRegistry: _registryWithStorage(),
            reasoner: _RecordingReasoner(app),
            knowledgeEngine: KnowledgeAcquisitionEngine(
              searchProvider: searchProvider,
            ),
            softwareCognition: softwareCognition,
          );

          final stopwatch = Stopwatch()..start();
          final outcome = await kernel.processIntent(
            Intent.create(expression: 'x'),
            autoDiscoverKnowledge: true,
          );
          stopwatch.stop();

          expect(outcome, isA<ExecutionPlanReady>());
          expect(searchProvider.callCount, 10);
          // ignore: avoid_print
          print(
            'R16 search+acquisition latency (10 targets, 20 candidate URLs): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'memory: real process RSS delta while planning over 200 knowledgeNeeds',
        () {
          final needs = [
            for (var i = 0; i < 200; i++)
              SynthesisKnowledgeRequirement(
                id: 'k$i',
                purpose: 'p',
                query: 'q$i',
                required: true,
                resourceType: 'repository',
              ),
          ];
          final app = _fieldSurveyApp(knowledgeNeeds: needs);

          final rssBefore = ProcessInfo.currentRss;
          final plan = const AutonomousKnowledgeAcquisitionPlanner().plan(app);
          final rssAfter = ProcessInfo.currentRss;

          expect(plan.actionableTargets, hasLength(200));
          // ignore: avoid_print
          print(
            'R16 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 200 knowledgeNeeds',
          );
        },
      );
    },
  );
}
