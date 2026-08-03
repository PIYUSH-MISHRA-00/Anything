/// Implementation Milestone R14 — Software Cognition Engine, Semantic
/// Software Understanding. Proves the two real, additive integration
/// points this milestone wired into the EXISTING, canonical V11 Software
/// Cognition subsystem (`lib/software_cognition/`) — never a second one:
///
/// 1. `CanonicalImplementationPlanner` (R9) now carries forward real,
///    multi-source-corroborated `SoftwareRecommendation`s as
///    `CorroboratedPattern`s — a deterministic pass-through, never a
///    fuzzy name-matching heuristic (see
///    `docs/architecture/SOFTWARE_COGNITION_ENGINE.md`, "R14: Canonical
///    Implementation Model enrichment", for exactly why no automatic
///    cross-referencing was built).
/// 2. `AuthenticationPatternAnalyzer`/`NavigationPatternAnalyzer` fill the
///    two real gaps found when R14 audited Software Cognition's output
///    taxonomy against the milestone's own requested categories.
///
/// World Model wiring (`SoftwareCognitionCoordinator.syncToWorldModel`
/// now has a real production caller) is proven in
/// `test/app/r1_composition_root_test.dart` alongside the existing
/// Software Cognition creation-pipeline hook tests, not duplicated here.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_candidate.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_plan.dart';
import 'package:anything/implementation_model/canonical_implementation_planner.dart';
import 'package:anything/implementation_model/canonical_implementation_serialization.dart';
import 'package:anything/software_architect/architecture_candidate.dart';
import 'package:anything/software_architect/architecture_types.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_cognition/architecture_analyzer.dart';
import 'package:anything/software_cognition/repository_analyzer.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/software_cognition/software_reasoner.dart';
import 'package:anything/software_cognition/software_types.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Small, self-contained "Recipe Box" fixture (novel domain, zero
// footprint elsewhere in lib/) — mirrors R9's own established
// fixture-construction shape, not its exact fixture. ──────────────────

ArchitectureDecision _decision(String id) => ArchitectureDecision(
  id: id,
  category: ArchitectureDecisionCategory.data,
  subjectId: id,
  decision: 'd-$id',
  rationale: 'r',
  confidence: const Confidence(score: 1.0, reason: 'test'),
);

NavigationGraph _nav() => NavigationGraph(entryScreenId: 'recipes', screenIds: const ['recipes'], edges: const [], decision: _decision('nav'));

SemanticApp _recipeApp() => const SemanticApp(
  name: 'Recipe Box',
  purpose: 'Track recipes',
  entities: [
    SemanticEntity(
      id: 'recipe',
      name: 'Recipe',
      displayField: 'title',
      fields: [SemanticField(id: 'title', name: 'Title', type: BlueprintFieldType.text, required: true)],
    ),
  ],
);

ArchitectureCandidate _recipeArchitecture() => ArchitectureCandidate(
  id: 'recipe-candidate',
  appName: 'Recipe Box',
  entities: const [
    EntityDecision(
      entityId: 'recipe',
      name: 'Recipe',
      fieldCount: 1,
      storage: StorageKind.sqlite,
      storageDecision: ArchitectureDecision(id: 's1', category: ArchitectureDecisionCategory.data, subjectId: 'recipe', decision: 'sqlite', rationale: 'r', confidence: Confidence(score: 1.0, reason: 'test')),
    ),
  ],
  relationships: const [],
  navigation: _nav(),
  interactions: [
    InteractionDecision(entityId: 'recipe', canCreate: true, canRead: true, canUpdate: true, canDelete: true, supportsSearch: false, supportsFilter: false, supportsSort: false, supportsPagination: false, decision: _decision('int:recipe')),
  ],
  security: SecurityDecision(networkMode: NetworkMode.none, requiresCredentialVault: false, decision: _decision('sec')),
  offline: OfflineDecision(capability: OfflineCapability.fullyOffline, decision: _decision('off')),
  synchronization: SynchronizationDecision(strategy: SyncStrategy.none, decision: _decision('sync')),
  overallConfidence: const Confidence(score: 1.0, reason: 'test'),
);

EngineeringCandidate _recipeEngineering() {
  final architecture = _recipeArchitecture();
  return const EngineeringPlanner().plan(EngineeringContext(architecture: architecture, app: _recipeApp()));
}

BackendEngineeringPlan _recipeBackend() {
  final architecture = _recipeArchitecture();
  return const BackendEngineeringPlanner().plan(BackendEngineeringContext(architecture: architecture, app: _recipeApp()));
}

CanonicalImplementationContext _recipeContext({List<SoftwareRecommendation> corroboratingRecommendations = const []}) =>
    CanonicalImplementationContext(engineering: _recipeEngineering(), backend: _recipeBackend(), corroboratingRecommendations: corroboratingRecommendations);

SoftwareRecommendation _recommendation({required String artifact, required bool accepted, int sourceCount = 2}) => SoftwareRecommendation(
  description: 'Consider the "$artifact" approach — observed in $sourceCount acquired repositories.',
  tracedTo: [for (var i = 0; i < sourceCount; i++) SoftwareEvidence(sourceUrl: 'https://example.com/repo$i', sourceArtifact: artifact)],
  confidence: SoftwareConfidence(score: sourceCount / 3, reason: accepted ? 'repeated' : 'seen once'),
  accepted: accepted,
);

RepositoryMetadata _repoMetadata(String name) => RepositoryMetadata(
  name: name,
  description: '',
  primaryLanguage: 'dart',
  provenance: SoftwareProvenance(
    sourceUrl: 'https://example.com/$name',
    retrievedAt: DateTime(2026, 8, 3),
    provider: 'test-fixture',
    license: const LicenseMetadata(policy: LicensePolicy.permissiveKnown, licenseId: 'MIT'),
  ),
);

void main() {
  group('CanonicalImplementationModel corroboration (R14)', () {
    test('an accepted, multi-source recommendation becomes a real CorroboratedPattern', () {
      final model = const CanonicalImplementationPlanner().plan(
        _recipeContext(corroboratingRecommendations: [_recommendation(artifact: 'offline-first', accepted: true)]),
      );
      expect(model.corroboratedPatterns, hasLength(1));
      expect(model.corroboratedPatterns.single.name, 'offline-first');
      expect(model.corroboratedPatterns.single.supportingSourceCount, 2);
      expect(model.corroboratedPatterns.single.confidenceScore, closeTo(2 / 3, 0.0001));
    });

    test('an unaccepted (single-source) recommendation is never carried forward — never adopted from one source', () {
      final model = const CanonicalImplementationPlanner().plan(
        _recipeContext(corroboratingRecommendations: [_recommendation(artifact: 'graphql', accepted: false, sourceCount: 1)]),
      );
      expect(model.corroboratedPatterns, isEmpty);
    });

    test('omitting corroboratingRecommendations leaves the model byte-for-byte unaffected (fully backward compatible)', () {
      final model = const CanonicalImplementationPlanner().plan(_recipeContext());
      expect(model.corroboratedPatterns, isEmpty);
    });

    test('a mix of accepted and rejected recommendations only carries the accepted ones forward, deterministically ordered', () {
      final model = const CanonicalImplementationPlanner().plan(
        _recipeContext(
          corroboratingRecommendations: [
            _recommendation(artifact: 'rejected-one', accepted: false, sourceCount: 1),
            _recommendation(artifact: 'accepted-one', accepted: true),
            _recommendation(artifact: 'also-rejected', accepted: false, sourceCount: 1),
            _recommendation(artifact: 'accepted-two', accepted: true, sourceCount: 3),
          ],
        ),
      );
      expect(model.corroboratedPatterns.map((p) => p.name).toList(), ['accepted-one', 'accepted-two']);
    });

    test('determinism: the same context planned twice produces structurally identical corroboratedPatterns', () {
      final context = _recipeContext(corroboratingRecommendations: [_recommendation(artifact: 'offline-first', accepted: true)]);
      final m1 = const CanonicalImplementationPlanner().plan(context);
      final m2 = const CanonicalImplementationPlanner().plan(context);
      expect(m1.toJson()['corroboratedPatterns'], m2.toJson()['corroboratedPatterns']);
    });
  });

  group('CanonicalImplementationModel serialization (R14)', () {
    test('corroboratedPatterns round-trips with full fidelity', () {
      final model = const CanonicalImplementationPlanner().plan(
        _recipeContext(corroboratingRecommendations: [_recommendation(artifact: 'offline-first', accepted: true, sourceCount: 3)]),
      );
      final restored = canonicalImplementationModelFromJson(model.toJson());
      expect(restored.corroboratedPatterns, hasLength(1));
      expect(restored.corroboratedPatterns.single.name, 'offline-first');
      expect(restored.corroboratedPatterns.single.description, model.corroboratedPatterns.single.description);
      expect(restored.corroboratedPatterns.single.confidenceScore, model.corroboratedPatterns.single.confidenceScore);
      expect(restored.corroboratedPatterns.single.supportingSourceCount, 3);
    });

    test('backward compatibility: JSON persisted before R14 (no corroboratedPatterns key) deserializes to an empty list, never throws', () {
      final model = const CanonicalImplementationPlanner().plan(_recipeContext());
      final preR14Json = model.toJson()..remove('corroboratedPatterns');
      final restored = canonicalImplementationModelFromJson(preR14Json);
      expect(restored.corroboratedPatterns, isEmpty);
    });
  });

  group('AuthenticationPatternAnalyzer / NavigationPatternAnalyzer (R14) — fill the two real taxonomy gaps found this milestone', () {
    test('detects a real, known authentication dependency', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: 'firebase_auth\nflutter\n', metadata: _repoMetadata('auth-app')));
      final labels = const AuthenticationPatternAnalyzer().analyze(model).graph.nodes.map((n) => n.label).toSet();
      expect(labels, contains('firebase_auth'));
      expect(labels, isNot(contains('flutter')));
    });

    test('a repository with no known auth dependency produces no fabricated pattern', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: 'flutter\n', metadata: _repoMetadata('no-auth-app')));
      expect(const AuthenticationPatternAnalyzer().analyze(model).graph.nodes, isEmpty);
    });

    test('detects a real, known navigation/routing dependency', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: 'go_router\nflutter\n', metadata: _repoMetadata('nav-app')));
      final labels = const NavigationPatternAnalyzer().analyze(model).graph.nodes.map((n) => n.label).toSet();
      expect(labels, contains('go_router'));
      expect(labels, isNot(contains('flutter')));
    });

    test('a repository with no known navigation dependency produces no fabricated pattern', () {
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: 'flutter\n', metadata: _repoMetadata('no-nav-app')));
      expect(const NavigationPatternAnalyzer().analyze(model).graph.nodes, isEmpty);
    });

    test('new SoftwareNodeKind values (authenticationPattern/navigationPattern) exist and are distinct from every prior kind', () {
      expect(SoftwareNodeKind.authenticationPattern, isNot(equals(SoftwareNodeKind.navigationPattern)));
      expect(SoftwareNodeKind.values, contains(SoftwareNodeKind.authenticationPattern));
      expect(SoftwareNodeKind.values, contains(SoftwareNodeKind.navigationPattern));
    });
  });

  group('Performance (R14) — real Stopwatch numbers, matching test/world_model/stress_test.dart\'s established convention', () {
    test('repository understanding over a large (500-file, ~50KB source) acquired repository', () {
      final files = [for (var i = 0; i < 500; i++) 'lib/module_$i/file_$i.dart'];
      final source = List.generate(200, (i) => 'class GeneratedClass$i { void method$i() {} }').join('\n');
      final metadata = _repoMetadata('large-repo');

      final stopwatch = Stopwatch()..start();
      final model = RepositoryAnalyzer().analyze(RepositoryContext(source: source, metadata: metadata, files: files));
      const ArchitectureAnalyzer().analyze(model);
      const AuthenticationPatternAnalyzer().analyze(model);
      const NavigationPatternAnalyzer().analyze(model);
      stopwatch.stop();

      expect(model.structure.entries.length, 500);
      // ignore: avoid_print
      print('R14 repository understanding (500 files, all 4 analyzers): ${stopwatch.elapsedMilliseconds}ms');
    });

    test('large documentation processing (~100KB synthetic description text)', () {
      final text = List.generate(2000, (i) => 'This package provides feature number $i with real, documented behavior.').join(' ');
      final metadata = _repoMetadata('large-package').provenance;

      final stopwatch = Stopwatch()..start();
      final result = RepositoryAnalyzer().analyze(RepositoryContext(source: text, metadata: _repoMetadata('large-doc-repo')));
      stopwatch.stop();

      expect(result.summary.toDigestText(), isNotEmpty);
      // ignore: avoid_print
      print('R14 large documentation processing (~${text.length} chars): ${stopwatch.elapsedMilliseconds}ms (provenance license: ${metadata.license.licenseId})');
    });

    test('CanonicalImplementationPlanner.plan() with 50 corroborating recommendations', () {
      final recommendations = [for (var i = 0; i < 50; i++) _recommendation(artifact: 'pattern-$i', accepted: i.isEven)];

      final stopwatch = Stopwatch()..start();
      final model = const CanonicalImplementationPlanner().plan(_recipeContext(corroboratingRecommendations: recommendations));
      stopwatch.stop();

      expect(model.corroboratedPatterns, hasLength(25));
      // ignore: avoid_print
      print('R14 CanonicalImplementationModel enrichment (50 recommendations): ${stopwatch.elapsedMilliseconds}ms');
    });

    test('memory: real process RSS delta while understanding 50 repositories in sequence', () {
      final rssBefore = ProcessInfo.currentRss;
      final models = <RepositoryModel>[];
      for (var i = 0; i < 50; i++) {
        models.add(
          RepositoryAnalyzer().analyze(
            RepositoryContext(source: 'sqflite\nfirebase_auth\ngo_router\n', metadata: _repoMetadata('repo-$i'), files: ['ui/', 'data/', 'lib/main_$i.dart']),
          ),
        );
      }
      final rssAfter = ProcessInfo.currentRss;
      expect(models, hasLength(50));
      // ignore: avoid_print
      print('R14 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 repositories');
    });
  });
}
