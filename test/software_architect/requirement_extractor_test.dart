/// V2 ASAE — RequirementExtractor + RequirementGraph tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/app_blueprint.dart' show BlueprintFieldType;
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/software_architect/requirement_graph.dart';

IntentUnderstanding _understanding(String objective) {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: objective,
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

void main() {
  const extractor = RequirementExtractor();

  group('Structural extraction — works for any never-before-seen domain', () {
    test('entities, fields, constraints, storage, state are all derived', () {
      final app = SemanticApp(
        name: 'Fossil Catalog',
        purpose: 'Track fossil specimens',
        entities: [
          SemanticEntity(
            id: 'specimen',
            name: 'Specimen',
            displayField: 'label',
            fields: [
              const SemanticField(
                id: 'label',
                name: 'Label',
                type: BlueprintFieldType.text,
                required: true,
                minLength: 2,
              ),
              const SemanticField(
                id: 'ageMillionYears',
                name: 'Age (million years)',
                type: BlueprintFieldType.decimal,
                minimum: 0,
              ),
            ],
          ),
        ],
      );

      final graph = extractor.extract(
        app: app,
        understanding: _understanding('track fossils'),
      );

      expect(graph.nodesOfType(RequirementNodeType.entity), hasLength(1));
      expect(graph.nodesOfType(RequirementNodeType.field), hasLength(2));
      expect(graph.nodesOfType(RequirementNodeType.constraint), hasLength(2));
      expect(graph.nodesOfType(RequirementNodeType.storage), hasLength(1));
      expect(graph.nodesOfType(RequirementNodeType.state), hasLength(1));
      expect(graph.danglingRelations, isEmpty);
    });

    test(
      'reference fields produce relationship nodes referencing the target entity',
      () {
        final app = SemanticApp(
          name: 'Lending',
          purpose: 'Track loans',
          entities: [
            const SemanticEntity(id: 'book', name: 'Book'),
            SemanticEntity(
              id: 'loan',
              name: 'Loan',
              fields: [
                const SemanticField(
                  id: 'bookRef',
                  name: 'Book',
                  type: BlueprintFieldType.reference,
                  referenceEntityId: 'book',
                  required: true,
                ),
              ],
            ),
          ],
        );

        final graph = extractor.extract(
          app: app,
          understanding: _understanding('track loans'),
        );

        final relationships = graph.nodesOfType(
          RequirementNodeType.relationship,
        );
        expect(relationships, hasLength(1));
        final rel = graph.relationsFrom(relationships.first.id).single;
        expect(rel.toId, 'entity:book');
        expect(rel.type, RequirementRelationType.references);
        expect(graph.danglingRelations, isEmpty);
      },
    );

    test(
      'views produce navigation nodes; actions reference their target entity',
      () {
        final app = SemanticApp(
          name: 'Anything',
          purpose: 'p',
          entities: [const SemanticEntity(id: 'e1', name: 'E1')],
          views: [
            const SemanticView(
              id: 'v1',
              name: 'List',
              purpose: 'list',
              sourceEntityId: 'e1',
            ),
          ],
          actions: [
            const SemanticAction(id: 'a1', name: 'Add', targetEntityId: 'e1'),
          ],
        );

        final graph = extractor.extract(
          app: app,
          understanding: _understanding('anything'),
        );

        expect(graph.nodesOfType(RequirementNodeType.view), hasLength(1));
        expect(graph.nodesOfType(RequirementNodeType.navigation), hasLength(1));
        expect(graph.nodesOfType(RequirementNodeType.action), hasLength(1));
        expect(graph.danglingRelations, isEmpty);
      },
    );

    test('required capabilities become capability nodes', () {
      final app = SemanticApp(
        name: 'Weather-ish',
        purpose: 'p',
        entities: const [],
        requiredCapabilities: const ['http', 'clock'],
      );

      final graph = extractor.extract(
        app: app,
        understanding: _understanding('anything'),
      );

      final capabilities = graph.nodesOfType(RequirementNodeType.capability);
      expect(capabilities.map((c) => c.label), containsAll(['http', 'clock']));
    });

    test(
      'non-functional requirements are always present (offline/security/lifecycle/future-mod)',
      () {
        final app = SemanticApp(name: 'X', purpose: 'p', entities: const []);
        final graph = extractor.extract(
          app: app,
          understanding: _understanding('anything'),
        );

        final categories = graph.nonFunctional.map((n) => n.category).toSet();
        expect(
          categories,
          containsAll([
            NonFunctionalCategory.offline,
            NonFunctionalCategory.security,
            NonFunctionalCategory.futureModification,
            NonFunctionalCategory.lifecycle,
          ]),
        );
      },
    );
  });

  test(
    'never inspects entity/field names — identical shape, different names, identical graph shape',
    () {
      SemanticApp appNamed(String entityName, String fieldName) => SemanticApp(
        name: 'X',
        purpose: 'p',
        entities: [
          SemanticEntity(
            id: 'e',
            name: entityName,
            fields: [
              SemanticField(
                id: 'f',
                name: fieldName,
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
      );

      final graphA = extractor.extract(
        app: appNamed('Plant', 'Watering Schedule'),
        understanding: _understanding('x'),
      );
      final graphB = extractor.extract(
        app: appNamed('Quantum Widget', 'Flibbertigibbet'),
        understanding: _understanding('x'),
      );

      expect(graphA.nodes.length, graphB.nodes.length);
      expect(
        graphA.nodes.map((n) => n.type).toList(),
        graphB.nodes.map((n) => n.type).toList(),
      );
    },
  );
}
