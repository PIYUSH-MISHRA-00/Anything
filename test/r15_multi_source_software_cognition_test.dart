/// Implementation Milestone R15 — Multi-Source Software Cognition, Evidence
/// Corroboration Engine. Proves the real gap this milestone closes: R14
/// built `CanonicalImplementationContext.corroboratingRecommendations` /
/// `CanonicalImplementationModel.corroboratedPatterns` but never wired it
/// into production because `ExperienceCreationCoordinator.createFromIntent`
/// only ever acquired ONE `referenceUrl` per creation — mathematically
/// unable to satisfy `SoftwareReasoner`'s `minSupportingCandidates` (V11,
/// default 2) acceptance gate. R15 adds a real, additive `referenceUrls`
/// multi-source acquisition path so that gate finally does real work in
/// production, all the way through the Kernel into a persisted
/// `CanonicalImplementationModel` — never a second Software Cognition
/// Engine, World Model, Knowledge Engine, AI Boundary, or Compiler.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/software_cognition/software_cognition_engine.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_reasoner.dart';
import 'package:anything/storage/engineering_memory_repository.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

// ── Shared fixtures (mirroring test/app/r1_composition_root_test.dart's
// established shape — not a duplicate, this file cannot import a private
// library part, so equivalents are redeclared minimally). ─────────────────

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
  Future<AppReasoningResult> reason(ApplicationReasoningContext context) async => ReasoningReady(semanticApp: app);
}

SemanticApp _fieldSurveyApp() => SemanticApp(
  name: 'Field Survey Log',
  purpose: 'Track field survey entries',
  entities: [
    const SemanticEntity(
      id: 'entry',
      name: 'Entry',
      displayField: 'title',
      fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
    ),
  ],
  views: const [
    SemanticView(id: 'entries_list', name: 'Entries', purpose: 'list', sourceEntityId: 'entry', viewType: BlueprintViewType.list, isDefault: true),
  ],
  actions: const [SemanticAction(id: 'add_entry', name: 'Add Entry', targetEntityId: 'entry')],
);

void _mockSecureStorageChannel() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'read':
      case 'containsKey':
        return null;
      default:
        return null;
    }
  });
}

/// A fake `RepositoryAnalyzer.fetchPage` that returns real, distinct HTML
/// per URL — `<p>` tags whose text is dependency-manifest-shaped, exactly
/// the same shape `test/software_cognition/software_similarity_and_reasoner_test.dart`
/// feeds `RepositoryAnalyzer().analyze()` directly. Empirically confirmed
/// (via `RepositoryAnalyzer.acquireFromUrl`) that WebWeaveX's real
/// paragraph/dependency extraction recognizes these as real dependencies,
/// and `frameworks` picks up the well-known ones (e.g. `flutter`).
RepositoryAnalyzer _analyzerFor(Map<String, List<String>> dependenciesByUrl) => RepositoryAnalyzer(
  fetchPage: (url) async {
    final deps = dependenciesByUrl[url];
    if (deps == null) return {'available': false};
    final html = '<html><body>${deps.map((d) => '<p>$d</p>').join()}</body></html>';
    return {'available': true, 'html': html};
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CorroborationSummary (R15) — real, deterministic aggregate', () {
    RepositoryModel repo(String name, String source) =>
        RepositoryAnalyzer().analyze(RepositoryContext(source: source, metadata: RepositoryMetadata(name: name, description: '', primaryLanguage: 'dart', provenance: SoftwareProvenance(sourceUrl: 'https://example.com/$name', retrievedAt: DateTime(2026, 8, 3), provider: 'test-fixture', license: const LicenseMetadata(policy: LicensePolicy.permissiveKnown, licenseId: 'MIT')))));

    test('sourceCount/considered/corroborated/conflicting reflect the real recommendation list', () {
      final candidates = [repo('a', 'flutter\nsqflite\n'), repo('b', 'flutter\nhttp\n'), repo('c', 'django\n')];
      final recommendations = const SoftwareReasoner().reasonAboutRepositories(candidates);
      final summary = CorroborationSummary.of(recommendations, sourceCount: candidates.length);

      expect(summary.sourceCount, 3);
      // Distinct known frameworks across all three: flutter, django (sqflite/http are not in _knownFrameworks).
      expect(summary.recommendationsConsidered, recommendations.length);
      expect(summary.corroborated, 1); // flutter: 2/3
      expect(summary.conflicting, recommendations.length - 1); // django: 1/3, isolated
      expect(summary.corroborated + summary.conflicting, summary.recommendationsConsidered);
    });

    test('an empty recommendation list produces an honest, all-zero summary, never an error', () {
      final summary = CorroborationSummary.of(const [], sourceCount: 0);
      expect(summary.recommendationsConsidered, 0);
      expect(summary.corroborated, 0);
      expect(summary.conflicting, 0);
    });
  });

  group('SoftwareCognitionCoordinator.reasoner getter (R15)', () {
    test('exposes the SAME reasoner instance passed to the constructor — never a second one', () {
      const reasoner = SoftwareReasoner(minSupportingCandidates: 3);
      final coordinator = SoftwareCognitionCoordinator(reasoner: reasoner);
      expect(identical(coordinator.reasoner, reasoner), isTrue);
    });
  });

  group('ExperienceCreationCoordinator multi-source acquisition (R15 centerpiece)', () {
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      SharedPreferences.setMockInitialValues({});
      _mockSecureStorageChannel();
    });

    test('two real, independent sources both declaring "flutter" corroborate it end-to-end into a persisted CanonicalImplementationModel', () async {
      final dbName = 'r15_corroborate_${DateTime.now().microsecondsSinceEpoch}.db';
      final repository = SqliteExperienceRepository(dbName: dbName);
      final engineeringMemory = EngineeringMemoryRepository(experienceRepository: repository);
      final kernel = AnythingKernel(
        providerRegistry: _FakeProviderRegistry(),
        capabilityRegistry: _registryWithStorage(),
        reasoner: _RecordingReasoner(_fieldSurveyApp()),
      );
      final softwareCognition = SoftwareCognitionCoordinator(
        engine: SoftwareCognitionEngine(
          repositoryAnalyzer: _analyzerFor({
            'https://example.com/repo-a': ['flutter', 'sqflite'],
            'https://example.com/repo-b': ['flutter', 'http'],
          }),
        ),
      );
      final worldModel = WorldModelCoordinator();
      final creation = ExperienceCreationCoordinator(
        kernel: kernel,
        repository: repository,
        softwareCognition: softwareCognition,
        worldModel: worldModel,
        engineeringMemory: engineeringMemory,
      );

      final result = await creation.createFromIntent(
        Intent.create(expression: 'track my field survey entries'),
        referenceUrls: const ['https://example.com/repo-a', 'https://example.com/repo-b'],
      );

      expect(result, isA<CreationCreated>());
      final experienceId = (result as CreationCreated).experienceId;

      final record = await engineeringMemory.load(experienceId);
      expect(record, isNotNull, reason: 'Engineering Memory must persist the CanonicalImplementationModel this creation produced');
      final corroborated = record!.canonicalImplementationModel?.corroboratedPatterns ?? const [];
      expect(corroborated, isNotEmpty, reason: 'A real recommendation supported by 2 independent sources must reach CorroboratedPattern — the R14 hook R15 finally wires');
      expect(corroborated.any((p) => p.name == 'flutter'), isTrue);
      expect(corroborated.firstWhere((p) => p.name == 'flutter').supportingSourceCount, 2);

      await repository.close();
    });

    test('a SINGLE source (referenceUrl only, unchanged call site) still creates successfully and produces NO corroborated patterns — the exact gate R14 documented, now genuinely exercised end-to-end rather than assumed', () async {
      final dbName = 'r15_single_source_${DateTime.now().microsecondsSinceEpoch}.db';
      final repository = SqliteExperienceRepository(dbName: dbName);
      final engineeringMemory = EngineeringMemoryRepository(experienceRepository: repository);
      final kernel = AnythingKernel(
        providerRegistry: _FakeProviderRegistry(),
        capabilityRegistry: _registryWithStorage(),
        reasoner: _RecordingReasoner(_fieldSurveyApp()),
      );
      final softwareCognition = SoftwareCognitionCoordinator(
        engine: SoftwareCognitionEngine(
          repositoryAnalyzer: _analyzerFor({
            'https://example.com/repo-a': ['flutter', 'sqflite'],
          }),
        ),
      );
      final creation = ExperienceCreationCoordinator(
        kernel: kernel,
        repository: repository,
        softwareCognition: softwareCognition,
        engineeringMemory: engineeringMemory,
      );

      // Existing single-referenceUrl call site — byte-for-byte the same
      // API every pre-R15 caller (e.g. lib/features/home/home_screen.dart)
      // could already use.
      final result = await creation.createFromIntent(
        Intent.create(expression: 'track my field survey entries'),
        referenceUrl: 'https://example.com/repo-a',
      );

      expect(result, isA<CreationCreated>());
      final record = await engineeringMemory.load((result as CreationCreated).experienceId);
      expect(record!.canonicalImplementationModel?.corroboratedPatterns ?? const [], isEmpty);

      await repository.close();
    });

    test('World Model: two sources both declaring "flutter" produce exactly ONE package node — GraphMerge\'s existing identity-keyed dedup (unchanged, V9), never two', () async {
      final dbName = 'r15_dedup_${DateTime.now().microsecondsSinceEpoch}.db';
      final repository = SqliteExperienceRepository(dbName: dbName);
      final kernel = AnythingKernel(
        providerRegistry: _FakeProviderRegistry(),
        capabilityRegistry: _registryWithStorage(),
        reasoner: _RecordingReasoner(_fieldSurveyApp()),
      );
      final softwareCognition = SoftwareCognitionCoordinator(
        engine: SoftwareCognitionEngine(
          repositoryAnalyzer: _analyzerFor({
            // Distinct hosts (unlike the corroboration test above) so
            // `_acquireSoftwareCognitionSeeds`'s `Uri.host`-derived name
            // gives each acquisition its own, genuinely distinct
            // repository identity — isolating this test's proof to the
            // shared "flutter" package node specifically.
            'https://example-a.com/repo': ['flutter'],
            'https://example-b.com/repo': ['flutter'],
          }),
        ),
      );
      final worldModel = WorldModelCoordinator();
      final creation = ExperienceCreationCoordinator(kernel: kernel, repository: repository, softwareCognition: softwareCognition, worldModel: worldModel);

      final result = await creation.createFromIntent(
        Intent.create(expression: 'track my field survey entries'),
        referenceUrls: const ['https://example-a.com/repo', 'https://example-b.com/repo'],
      );
      expect(result, isA<CreationCreated>());

      final flutterNodes = worldModel.model.graph.nodes.where((n) => n.kind == WorldNodeKind.softwarePackage && n.label == 'flutter');
      expect(flutterNodes, hasLength(1), reason: 'Two independent sources reporting the same real-world package must collapse into one World Model node');

      // Both source repositories themselves ARE genuinely distinct and
      // must NOT be deduped — proves this isn't over-merging everything.
      final repoNodes = worldModel.model.graph.nodes.where((n) => n.kind == WorldNodeKind.repository);
      expect(repoNodes.length, greaterThanOrEqualTo(2));

      await repository.close();
    });
  });

  group('Performance (R15) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated', () {
    List<RepositoryModel> syntheticRepositories(int count) => [
      for (var i = 0; i < count; i++)
        RepositoryAnalyzer().analyze(
          RepositoryContext(
            source: i.isEven ? 'flutter\nsqflite\n' : 'flutter\nhttp\n',
            metadata: RepositoryMetadata(
              name: 'repo-$i',
              description: '',
              primaryLanguage: 'dart',
              provenance: SoftwareProvenance(sourceUrl: 'https://example.com/repo-$i', retrievedAt: DateTime(2026, 8, 3), provider: 'test-fixture', license: const LicenseMetadata(policy: LicensePolicy.permissiveKnown, licenseId: 'MIT')),
            ),
          ),
        ),
    ];

    for (final count in [10, 50, 100]) {
      test('$count synthetic repositories: corroboration + merge latency', () {
        final repos = syntheticRepositories(count);
        final stopwatch = Stopwatch()..start();
        final recommendations = const SoftwareReasoner().reasonAboutRepositories(repos);
        final summary = CorroborationSummary.of(recommendations, sourceCount: repos.length);
        stopwatch.stop();

        expect(summary.corroborated, greaterThan(0));
        // ignore: avoid_print
        print('R15 corroboration over $count repositories: ${stopwatch.elapsedMilliseconds}ms (${summary.recommendationsConsidered} recommendations, ${summary.corroborated} corroborated)');
      });
    }

    test('memory: real process RSS delta while corroborating 100 repositories', () {
      final rssBefore = ProcessInfo.currentRss;
      final repos = syntheticRepositories(100);
      final recommendations = const SoftwareReasoner().reasonAboutRepositories(repos);
      final rssAfter = ProcessInfo.currentRss;
      expect(recommendations, isNotEmpty);
      // ignore: avoid_print
      print('R15 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 100 repositories');
    });
  });
}
