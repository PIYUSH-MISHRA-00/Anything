/// Vision V11 — SoftwareCognitionEngine (orchestration: acquire -> review
/// -> copyright check) and SoftwareCognitionCoordinator (World Model
/// bridging, KnowledgeResource conversion, Evolution suggestion).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/knowledge/knowledge_resource.dart';
import 'package:anything/software_cognition/package_model.dart';
import 'package:anything/software_cognition/repository_model.dart';
import 'package:anything/software_cognition/software_cognition_coordinator.dart';
import 'package:anything/software_cognition/software_cognition_engine.dart';
import 'package:anything/software_cognition/software_provenance.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:anything/world_model/world_types.dart';

import '../evolution/evolution_test_support.dart';

const _novelSource = '''
flutter
sqflite

class OrchidCareTrackerScreen:
    def main():
        return None
''';

SoftwareProvenance _provenance({
  String url = 'https://example.com/orchid-tracker',
}) => SoftwareProvenance(
  sourceUrl: url,
  retrievedAt: DateTime(2026, 8, 2),
  provider: 'test-fixture',
  license: const LicenseMetadata(
    policy: LicensePolicy.permissiveKnown,
    licenseId: 'MIT',
    confidence: 1.0,
  ),
);

RepositoryContext _context() => RepositoryContext(
  source: _novelSource,
  metadata: RepositoryMetadata(
    name: 'orchid-tracker',
    description: 'A novel orchid cultivation tracker',
    primaryLanguage: 'dart',
    provenance: _provenance(),
  ),
);

void main() {
  group('SoftwareCognitionEngine.understandRepository', () {
    test('produces a sound result for a real, well-provenanced repository', () {
      final result = SoftwareCognitionEngine().understandRepository(_context());
      expect(result.isSound, isTrue);
      expect(result.model.dependencies, containsAll(['flutter', 'sqflite']));
    });

    test('reports attribution completeness honestly', () {
      final result = SoftwareCognitionEngine().understandRepository(_context());
      expect(result.attribution.present, contains('source'));
      expect(
        result.attribution.missing,
        contains('author'),
      ); // never fabricated
    });

    test('a repository with no source URL is not sound', () {
      final badContext = RepositoryContext(
        source: _novelSource,
        metadata: RepositoryMetadata(
          name: 'no-url',
          description: '',
          primaryLanguage: 'dart',
          provenance: SoftwareProvenance(
            sourceUrl: '',
            retrievedAt: DateTime(2026, 8, 2),
            provider: 'test',
            license: const LicenseMetadata(
              policy: LicensePolicy.unknownReviewRequired,
            ),
          ),
        ),
      );
      final result = SoftwareCognitionEngine().understandRepository(badContext);
      expect(result.isSound, isFalse);
    });
  });

  group('SoftwareCognitionEngine.understandPackageFromPubspec', () {
    test('produces a sound result for a real pubspec', () {
      final metadata = PackageMetadata(
        name: 'orchid_pkg',
        version: '1.0.0',
        description: 'An orchid care package',
        provenance: _provenance(url: 'https://pub.dev/packages/orchid_pkg'),
      );
      final result = SoftwareCognitionEngine().understandPackageFromPubspec(
        pubspecSource: 'dependencies:\n  http: ^1.0.0\n',
        metadata: metadata,
      );
      expect(result.isSound, isTrue);
    });
  });

  group('SoftwareCognitionCoordinator.toKnowledgeResource', () {
    test(
      'converts a sound repository understanding into a real KnowledgeResource',
      () {
        final result = SoftwareCognitionEngine().understandRepository(
          _context(),
        );
        final resource = SoftwareCognitionCoordinator().toKnowledgeResource(
          result,
        );
        expect(resource, isNotNull);
        expect(resource!.type, KnowledgeResourceType.repositoryMetadata);
        expect(
          resource.content,
          isNot(contains('def main()')),
        ); // digest, never raw source
      },
    );

    test(
      'returns null for an unsound understanding — never fabricates a resource',
      () {
        final badContext = RepositoryContext(
          source: _novelSource,
          metadata: RepositoryMetadata(
            name: 'no-url',
            description: '',
            primaryLanguage: 'dart',
            provenance: SoftwareProvenance(
              sourceUrl: '',
              retrievedAt: DateTime(2026, 8, 2),
              provider: 'test',
              license: const LicenseMetadata(
                policy: LicensePolicy.unknownReviewRequired,
              ),
            ),
          ),
        );
        final result = SoftwareCognitionEngine().understandRepository(
          badContext,
        );
        final resource = SoftwareCognitionCoordinator().toKnowledgeResource(
          result,
        );
        expect(resource, isNull);
      },
    );
  });

  group('SoftwareCognitionCoordinator.syncToWorldModel', () {
    test(
      'acquired repository understanding becomes real World Graph nodes',
      () {
        final result = SoftwareCognitionEngine().understandRepository(
          _context(),
        );
        final worldModel = WorldModelCoordinator();
        SoftwareCognitionCoordinator().syncToWorldModel(
          worldModel,
          result.model,
        );

        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.repository),
          isNotEmpty,
        );
        expect(
          worldModel.model.graph.nodesOfKind(WorldNodeKind.softwarePackage),
          isNotEmpty,
        );
      },
    );
  });

  group('SoftwareCognitionCoordinator.suggestEvolutionOpportunities', () {
    test(
      'a capability repeated across acquired repositories not already declared becomes a real EvolutionOpportunity',
      () {
        final context = buildEvolutionContext(fieldSurveyApp());
        final models = [
          _repoWith('flutter\n', 'r1'),
          _repoWith('flutter\n', 'r2'),
        ];
        final opportunities = SoftwareCognitionCoordinator()
            .suggestEvolutionOpportunities(models, context);
        expect(opportunities, isNotEmpty);
        expect(opportunities.first.category.name, 'missingCapability');
      },
    );
  });
}

RepositoryModel _repoWith(String source, String name) {
  final engineResult = SoftwareCognitionEngine().understandRepository(
    RepositoryContext(
      source: source,
      metadata: RepositoryMetadata(
        name: name,
        description: '',
        primaryLanguage: 'text',
        provenance: _provenance(url: 'https://example.com/$name'),
      ),
    ),
  );
  return engineResult.model;
}
