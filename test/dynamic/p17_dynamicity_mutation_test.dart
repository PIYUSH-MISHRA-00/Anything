/// P17 — architecture / semantic / relationship / action mutation gates.
library;

import 'dart:io';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_smoke_validator.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _scanDomainFactories() {
  final offenders = <String>[];
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    final rel = file.path.replaceAll('\\', '/');
    for (final pattern in const [
      'class BakeryFactory',
      'class GardenFactory',
      'class PhotographyFactory',
      'class MaintenanceFactory',
      'class LanguageLearningFactory',
      'buildCompleteNewsApplication(',
      "if (domain == 'bakery')",
    ]) {
      if (text.contains(pattern)) offenders.add('$rel :: $pattern');
    }
  }
  return offenders;
}

void main() {
  test(
    'mutation inserts BakeryFactory → certification fails; cleanup passes',
    () {
      final probe = File('lib/_p17_mutation_probe_bakery.dart');
      addTearDown(() {
        if (probe.existsSync()) probe.deleteSync();
      });
      expect(_scanDomainFactories(), isEmpty);
      probe.writeAsStringSync('class BakeryFactory {}\n');
      expect(_scanDomainFactories(), isNotEmpty);
      probe.deleteSync();
      expect(_scanDomainFactories(), isEmpty);
    },
  );

  test('mutation inserts buildCompleteNewsApplication → fails', () {
    final probe = File('lib/_p17_mutation_probe_news.dart');
    addTearDown(() {
      if (probe.existsSync()) probe.deleteSync();
    });
    probe.writeAsStringSync('void buildCompleteNewsApplication() {}\n');
    expect(
      _scanDomainFactories().any(
        (o) => o.contains('buildCompleteNewsApplication'),
      ),
      isTrue,
    );
    probe.deleteSync();
    expect(_scanDomainFactories(), isEmpty);
  });

  test('quantity:text fails blueprint type-cue validation', () {
    final bp = AppBlueprint(
      id: 'mut',
      name: 'Mut',
      description: 'm',
      archetypes: const [AppArchetype.collection],
      entities: [
        BlueprintEntity(
          id: 'inventory',
          name: 'Inventory',
          fields: const [
            BlueprintField(
              id: 'name',
              name: 'Name',
              type: BlueprintFieldType.text,
              required: true,
            ),
            BlueprintField(
              id: 'quantity',
              name: 'Quantity',
              type: BlueprintFieldType.text,
            ),
          ],
          displayField: 'name',
        ),
      ],
      views: const [
        BlueprintView(
          id: 'inventory_list',
          name: 'List',
          purpose: 'list',
          sourceEntityId: 'inventory',
          viewType: BlueprintViewType.list,
          isDefault: true,
        ),
      ],
      actions: const [
        BlueprintAction(
          id: 'create_inventory',
          name: 'Add',
          targetEntityId: 'inventory',
          actionType: BlueprintActionType.create,
        ),
      ],
    );
    final v = BlueprintValidator.validate(bp);
    expect(v.isValid, isFalse);
    expect(
      v.errors.any((e) => e.contains('quantity') && e.contains('numeric')),
      isTrue,
    );
  });

  test('dangling relationship reference fails validation', () {
    final bp = AppBlueprint(
      id: 'mut2',
      name: 'Mut2',
      description: 'm',
      archetypes: const [AppArchetype.collection],
      entities: [
        BlueprintEntity(
          id: 'batch',
          name: 'Batch',
          fields: const [
            BlueprintField(
              id: 'name',
              name: 'Name',
              type: BlueprintFieldType.text,
              required: true,
            ),
            BlueprintField(
              id: 'recipe_ref',
              name: 'Recipe',
              type: BlueprintFieldType.reference,
              referenceEntityId: 'does_not_exist',
            ),
          ],
          displayField: 'name',
        ),
      ],
      views: const [
        BlueprintView(
          id: 'batch_list',
          name: 'List',
          purpose: 'list',
          sourceEntityId: 'batch',
          viewType: BlueprintViewType.list,
          isDefault: true,
        ),
      ],
      actions: const [
        BlueprintAction(
          id: 'create_batch',
          name: 'Add',
          targetEntityId: 'batch',
          actionType: BlueprintActionType.create,
        ),
      ],
    );
    final v = BlueprintValidator.validate(bp);
    expect(v.isValid, isFalse);
    expect(v.errors.any((e) => e.contains('does_not_exist')), isTrue);
  });

  test('dead action binding fails smoke validator', () {
    final now = DateTime.utc(2026, 1, 1);
    final report = const ExperienceSmokeValidator().validate(
      ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'x',
          name: 'Demo App',
          description: 'd',
          version: '1.0.0',
          createdAt: now,
          updatedAt: now,
          requiredCapabilities: const [],
        ),
        interface: const InterfaceDefinition(
          screens: [
            InterfaceScreen(
              id: 's',
              title: 'S',
              children: [
                InterfaceNode(
                  type: 'button',
                  id: 'dead',
                  properties: {'label': 'Go'},
                  actionBinding: ActionBinding(actionId: 'nonexistent'),
                ),
              ],
            ),
          ],
        ),
        behavior: const BehaviorGraph(nodes: []),
        state: const StateSchema(),
        services: const [],
        provenance: const PackageProvenance(
          creationEngineVersion: 'test',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
      ),
    );
    expect(report.passed, isFalse);
    expect(report.findings.any((f) => f.code == 'dead_action'), isTrue);
  });
}
