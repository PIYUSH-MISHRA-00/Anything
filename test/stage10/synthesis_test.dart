/// Stage 10.1 — Universal Synthesis Integration Tests
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/generic_package_builder.dart';
import 'package:anything/synthesis/synthesis_planner.dart';
import 'package:anything/synthesis/synthesis_patterns.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed, StorageType;

IntentUnderstanding _understand(
  String objective, {
  String desiredOutcome = '',
  NetworkNeed networkNeed = NetworkNeed.none,
}) {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: objective,
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: desiredOutcome,
    confidence: 0.8,
    networkNeed: networkNeed,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

void main() {
  group('AppArchetype enum', () {
    test('has all required archetypes', () {
      expect(AppArchetype.values.length, 8);
      expect(AppArchetype.values, contains(AppArchetype.utility));
      expect(AppArchetype.values, contains(AppArchetype.collection));
      expect(AppArchetype.values, contains(AppArchetype.tracker));
      expect(AppArchetype.values, contains(AppArchetype.planner));
      expect(AppArchetype.values, contains(AppArchetype.dashboard));
      expect(AppArchetype.values, contains(AppArchetype.reference));
      expect(AppArchetype.values, contains(AppArchetype.workflow));
      expect(AppArchetype.values, contains(AppArchetype.hybrid));
    });
  });

  group('BlueprintValidator', () {
    test('valid blueprint passes validation', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test App',
        description: 'A test application',
        archetypes: [AppArchetype.collection],
        tags: ['test'],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
            displayField: 'item_name',
          ),
        ],
        views: [
          const BlueprintView(
            id: 'item_list',
            name: 'Item List',
            purpose: 'View all items',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_item',
            name: 'Create Item',
            targetEntityId: 'item',
            actionType: BlueprintActionType.create,
          ),
        ],
      );

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
    });

    test('empty ID fails validation', () {
      final blueprint = AppBlueprint(
        id: '',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
      );

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isFalse);
      expect(validation.errors, contains('Blueprint ID is required'));
    });

    test('no archetypes fails validation', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [],
      );

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isFalse);
      expect(validation.errors, contains('At least one archetype is required'));
    });

    test('duplicate entity IDs fail validation', () {
      final blueprint = AppBlueprint(
        id: 'bp_dup',
        name: 'Dup',
        description: 'Dup entities',
        archetypes: [AppArchetype.collection],
        entities: [
          const BlueprintEntity(
            id: 'same',
            name: 'A',
            fields: [
              BlueprintField(
                id: 'a_f',
                name: 'F',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
          const BlueprintEntity(
            id: 'same',
            name: 'B',
            fields: [
              BlueprintField(
                id: 'b_f',
                name: 'F',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        ],
      );

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isFalse);
    });

    test('limits are enforced', () {
      final entities = List.generate(
        BlueprintLimits.maxEntities + 1,
        (i) => BlueprintEntity(
          id: 'e_$i',
          name: 'E$i',
          fields: [
            const BlueprintField(
              id: 'f',
              name: 'F',
              type: BlueprintFieldType.text,
            ),
          ],
        ),
      );

      final blueprint = AppBlueprint(
        id: 'bp_limit',
        name: 'Limit',
        description: 'Over limit',
        archetypes: [AppArchetype.collection],
        entities: entities,
      );

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isFalse);
    });
  });

  group('DeterministicReasoner', () {
    const reasoner = DeterministicReasoner();

    test('handles collection intent', () async {
      final result = await reasoner.reason(
        _understand('Create a list of plants'),
      );
      expect(result, isA<ReasoningReady>());

      final ready = result as ReasoningReady;
      expect(ready.semanticApp.entities, isNotEmpty);
      expect(ready.semanticApp.entities.first.name, isNotEmpty);
      expect(ready.semanticApp.archetypes, contains('collection'));
    });

    test('handles tracker intent', () async {
      final result = await reasoner.reason(
        _understand('Habit tracker for daily routine'),
      );
      expect(result, isA<ReasoningReady>());

      final ready = result as ReasoningReady;
      expect(ready.semanticApp.entities, isNotEmpty);
      expect(
        ready.semanticApp.entities.any((e) => e.id.contains('complet')),
        isTrue,
      );
    });

    test('handles planner intent', () async {
      final result = await reasoner.reason(
        _understand('Plan my study schedule'),
      );
      expect(result, isA<ReasoningReady>());

      final ready = result as ReasoningReady;
      expect(ready.semanticApp.archetypes, contains('planner'));
    });

    test('returns provider required for unhandled intents', () async {
      final result = await reasoner.reason(
        _understand('Build a complex real-time collaborative editor'),
      );
      expect(result, isA<ReasoningProviderRequired>());
    });
  });

  group('SynthesisPlanner', () {
    final reasoner = const DeterministicReasoner();
    final planner = SynthesisPlanner(reasoner);

    test('converts semantic understanding to blueprint', () async {
      final result = await planner.plan(_understand('Create a list of books'));
      expect(result.blueprint, isNotNull);
      expect(result.blueprint.name, isNotEmpty);
      expect(result.blueprint.entities, isNotEmpty);
      expect(result.blueprint.views, isNotEmpty);
      expect(result.blueprint.actions, isNotEmpty);
    });

    test('blueprint has no domain-specific hardcoding', () async {
      final result = await planner.plan(
        _understand('Track my plants and watering'),
      );
      expect(result.blueprint.tags, isA<List<String>>());
      expect(result.blueprint.tags, isNotEmpty);
    });
  });

  group('Blueprint Serialization', () {
    test('toJson and fromJson roundtrip', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test App',
        description: 'A test application',
        archetypes: [AppArchetype.collection],
        tags: ['test', 'collection'],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'item_list',
            name: 'Item List',
            purpose: 'View all items',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.list,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_item',
            name: 'Create Item',
            targetEntityId: 'item',
            actionType: BlueprintActionType.create,
          ),
        ],
      );

      final json = blueprint.toJson();
      final restored = AppBlueprint.fromJson(json);

      expect(restored.id, blueprint.id);
      expect(restored.name, blueprint.name);
      expect(restored.tags, blueprint.tags);
      expect(restored.entities.length, blueprint.entities.length);
      expect(restored.views.length, blueprint.views.length);
      expect(restored.actions.length, blueprint.actions.length);
    });
  });

  group('Blueprint to ExperienceSpec', () {
    test('converts collection blueprint to spec', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test App',
        description: 'A test application',
        archetypes: [AppArchetype.collection],
        tags: ['test'],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'item_list',
            name: 'Item List',
            purpose: 'View all items',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.list,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_item',
            name: 'Create Item',
            targetEntityId: 'item',
            actionType: BlueprintActionType.create,
          ),
        ],
      );

      final spec = BlueprintToSpecConverter.convert(blueprint);
      expect(spec.id, blueprint.id);
      expect(spec.name, blueprint.name);
      expect(spec.storageRequirements.storageType, StorageType.localDatabase);
    });

    test('converts dashboard blueprint to spec', () {
      final blueprint = AppBlueprint(
        id: 'bp_dash',
        name: 'Dashboard',
        description: 'A dashboard',
        archetypes: [AppArchetype.dashboard],
        entities: [
          const BlueprintEntity(
            id: 'record',
            name: 'Record',
            fields: [
              BlueprintField(
                id: 'record_amount',
                name: 'Amount',
                type: BlueprintFieldType.decimal,
              ),
            ],
          ),
        ],
        views: [],
        actions: [],
        derivedValues: [
          const BlueprintDerivedValue(
            id: 'total',
            name: 'Total',
            sourceEntityId: 'record',
            operation: DerivedOperation.sum,
            fieldId: 'record_amount',
          ),
        ],
      );

      final spec = BlueprintToSpecConverter.convert(blueprint);
      expect(spec.storageRequirements.storageType, isNotNull);
    });
  });

  group('GenericPackageBuilder', () {
    test('builds valid package from collection blueprint', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test App',
        description: 'A test application',
        archetypes: [AppArchetype.collection],
        tags: ['test'],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'item_list',
            name: 'Item List',
            purpose: 'View all items',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_item',
            name: 'Create Item',
            targetEntityId: 'item',
            actionType: BlueprintActionType.create,
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.manifest.experienceId, blueprint.id);
      expect(package.manifest.name, blueprint.name);
      expect(package.interface.screens, isNotEmpty);
      expect(package.behavior.nodes, isNotEmpty);
    });

    test('builds valid package from tracker blueprint', () {
      final blueprint = AppBlueprint(
        id: 'bp_tracker',
        name: 'Tracker',
        description: 'A tracker',
        archetypes: [AppArchetype.tracker],
        entities: [
          const BlueprintEntity(
            id: 'trackable',
            name: 'Trackable',
            fields: [
              BlueprintField(
                id: 'trackable_name',
                name: 'Name',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
          const BlueprintEntity(
            id: 'trackable_completions',
            name: 'Completions',
            fields: [
              BlueprintField(
                id: 'completion_date',
                name: 'Date',
                type: BlueprintFieldType.date,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'today',
            name: 'Today',
            purpose: "Today's items",
            sourceEntityId: 'trackable',
            viewType: BlueprintViewType.dashboard,
            isDefault: true,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'toggle',
            name: 'Toggle',
            targetEntityId: 'trackable',
            actionType: BlueprintActionType.toggle,
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.interface.screens, isNotEmpty);
    });

    test('builds valid package from dashboard blueprint', () {
      final blueprint = AppBlueprint(
        id: 'bp_dash',
        name: 'Dashboard',
        description: 'A dashboard',
        archetypes: [AppArchetype.dashboard],
        entities: [
          const BlueprintEntity(
            id: 'record',
            name: 'Record',
            fields: [
              BlueprintField(
                id: 'record_amount',
                name: 'Amount',
                type: BlueprintFieldType.decimal,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'overview',
            name: 'Overview',
            purpose: 'Overview',
            sourceEntityId: 'record',
            viewType: BlueprintViewType.dashboard,
            isDefault: true,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_record',
            name: 'Add Record',
            targetEntityId: 'record',
            actionType: BlueprintActionType.create,
          ),
        ],
        derivedValues: [
          const BlueprintDerivedValue(
            id: 'total',
            name: 'Total',
            sourceEntityId: 'record',
            operation: DerivedOperation.sum,
            fieldId: 'record_amount',
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.behavior.nodes, isNotEmpty);
    });

    test('builds valid package from planner blueprint', () {
      final blueprint = AppBlueprint(
        id: 'bp_plan',
        name: 'Planner',
        description: 'A planner',
        archetypes: [AppArchetype.planner],
        entities: [
          const BlueprintEntity(
            id: 'task',
            name: 'Task',
            fields: [
              BlueprintField(
                id: 'task_title',
                name: 'Title',
                type: BlueprintFieldType.text,
              ),
              BlueprintField(
                id: 'task_due_date',
                name: 'Due Date',
                type: BlueprintFieldType.date,
              ),
              BlueprintField(
                id: 'task_completed',
                name: 'Completed',
                type: BlueprintFieldType.boolean,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'task_list',
            name: 'Tasks',
            purpose: 'All tasks',
            sourceEntityId: 'task',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_task',
            name: 'Add Task',
            targetEntityId: 'task',
            actionType: BlueprintActionType.create,
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.interface.screens, isNotEmpty);
    });

    test('behavior graph has event nodes for all actions', () {
      final blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        ],
        views: [],
        actions: [
          const BlueprintAction(
            id: 'create_item',
            name: 'Create',
            targetEntityId: 'item',
            actionType: BlueprintActionType.create,
          ),
          const BlueprintAction(
            id: 'delete_item',
            name: 'Delete',
            targetEntityId: 'item',
            actionType: BlueprintActionType.delete,
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      final events = package.behavior.nodes
          .where((n) => n.type == 'event')
          .toList();
      expect(events.length, 2);
    });

    test('multi-screen apps have navigation', () {
      final blueprint = AppBlueprint(
        id: 'bp_multi',
        name: 'Multi',
        description: 'Multi-screen',
        archetypes: [AppArchetype.collection],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'list',
            name: 'List',
            purpose: 'All',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
          const BlueprintView(
            id: 'form',
            name: 'Form',
            purpose: 'Add',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.form,
          ),
        ],
        actions: [],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.interface.navigation, isNotNull);
    });

    test('derived values create query and calculation nodes', () {
      final blueprint = AppBlueprint(
        id: 'bp_dv',
        name: 'DV',
        description: 'Derived values',
        archetypes: [AppArchetype.dashboard],
        entities: [
          const BlueprintEntity(
            id: 'record',
            name: 'Record',
            fields: [
              BlueprintField(
                id: 'amount',
                name: 'Amount',
                type: BlueprintFieldType.decimal,
              ),
            ],
          ),
        ],
        views: [],
        actions: [],
        derivedValues: [
          const BlueprintDerivedValue(
            id: 'total',
            name: 'Total',
            sourceEntityId: 'record',
            operation: DerivedOperation.sum,
            fieldId: 'amount',
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(
        package.behavior.nodes.where((n) => n.type == 'dataQuery').length,
        1,
      );
      expect(
        package.behavior.nodes.where((n) => n.type == 'calculation').length,
        1,
      );
    });

    test('integrity hash is computed', () {
      final blueprint = AppBlueprint(
        id: 'bp_hash',
        name: 'Hash',
        description: 'Hash test',
        archetypes: [AppArchetype.collection],
        entities: [
          const BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        ],
        views: [],
        actions: [],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.integrity.contentHash, isNotEmpty);
    });

    test('arbitrary semantic names work', () {
      final blueprint = AppBlueprint(
        id: 'bp_xyz',
        name: 'Xyz App',
        description: 'Arbitrary names',
        archetypes: [AppArchetype.collection],
        tags: ['arbitrary'],
        entities: [
          const BlueprintEntity(
            id: 'quantum_device',
            name: 'Quantum Device',
            fields: [
              BlueprintField(
                id: 'quantum_device_name',
                name: 'Name',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        ],
        views: [
          const BlueprintView(
            id: 'quantum_device_list',
            name: 'Devices',
            purpose: 'All devices',
            sourceEntityId: 'quantum_device',
            viewType: BlueprintViewType.list,
          ),
        ],
        actions: [
          const BlueprintAction(
            id: 'create_quantum_device',
            name: 'Add Device',
            targetEntityId: 'quantum_device',
            actionType: BlueprintActionType.create,
          ),
        ],
      );

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.manifest.experienceId, 'bp_xyz');
      expect(package.interface.screens, isNotEmpty);
    });
  });

  group('End-to-End Pipeline', () {
    final reasoner = const DeterministicReasoner();
    final planner = SynthesisPlanner(reasoner);

    test(
      'intent -> understanding -> planner -> blueprint -> package',
      () async {
        final result = await planner.plan(
          _understand('Create a list of plants'),
        );

        final validation = BlueprintValidator.validate(result.blueprint);
        expect(validation.isValid, isTrue);

        final package = GenericPackageBuilder.build(result.blueprint);
        expect(package.manifest.experienceId, isNotEmpty);
        expect(package.interface.screens, isNotEmpty);
        expect(package.behavior.nodes, isNotEmpty);
      },
    );

    test('all five golden archetypes produce valid packages', () async {
      final intents = [
        'Create a list of notes',
        'Track my daily habits',
        'Manage my expenses and budget',
        'Plan my study schedule',
        'Create a reading list',
      ];

      for (final intent in intents) {
        final result = await planner.plan(_understand(intent));
        final validation = BlueprintValidator.validate(result.blueprint);
        expect(validation.isValid, isTrue, reason: 'Failed for: $intent');

        final package = GenericPackageBuilder.build(result.blueprint);
        expect(
          package.interface.screens,
          isNotEmpty,
          reason: 'No screens for: $intent',
        );
      }
    });

    test('no app-specific production screens in generated packages', () async {
      final result = await planner.plan(
        _understand('Create a list of anything'),
      );

      final package = GenericPackageBuilder.build(result.blueprint);

      for (final screen in package.interface.screens) {
        expect(screen.id, isNot(contains('calculator')));
        expect(screen.id, isNot(contains('habit')));
        expect(screen.id, isNot(contains('expense')));
      }
    });
  });

  group('Pattern Registry', () {
    test('default patterns registered', () {
      expect(PatternRegistry.registeredPatterns, contains('collection'));
      expect(PatternRegistry.registeredPatterns, contains('tracker'));
      expect(PatternRegistry.registeredPatterns, contains('planner'));
      expect(PatternRegistry.registeredPatterns, contains('dashboard'));
    });

    test('can retrieve patterns by ID', () {
      final collection = PatternRegistry.getPattern('collection');
      expect(collection, isNotNull);
      expect(collection!.patternId, 'collection');
    });
  });

  group('Novel Domain - Plant Care (Black-Box)', () {
    final reasoner = const DeterministicReasoner();
    final planner = SynthesisPlanner(reasoner);

    test('synthesizes Plant Care app with no Plant template', () async {
      final result = await planner.plan(
        _understand('Track my plants and when I watered them'),
      );
      final blueprint = result.blueprint;

      expect(blueprint.entities, isNotEmpty);
      expect(blueprint.name, isNotEmpty);

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isTrue);

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.manifest.experienceId, isNotEmpty);
      expect(package.interface.screens, isNotEmpty);
      expect(package.behavior.nodes, isNotEmpty);
    });
  });

  group('Novel Domain - Borrowed Items (Black-Box)', () {
    final reasoner = const DeterministicReasoner();
    final planner = SynthesisPlanner(reasoner);

    test('synthesizes borrowed items app', () async {
      final result = await planner.plan(
        _understand(
          'Track which friends borrowed my books and when they should return them',
        ),
      );
      final blueprint = result.blueprint;

      expect(blueprint.entities, isNotEmpty);

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isTrue);

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.interface.screens, isNotEmpty);
    });
  });

  group('Novel Domain - Inventory (Black-Box)', () {
    final reasoner = const DeterministicReasoner();
    final planner = SynthesisPlanner(reasoner);

    test('synthesizes inventory app', () async {
      final result = await planner.plan(
        _understand('Manage my small shop inventory'),
      );
      final blueprint = result.blueprint;

      expect(blueprint.entities, isNotEmpty);

      final validation = BlueprintValidator.validate(blueprint);
      expect(validation.isValid, isTrue);

      final package = GenericPackageBuilder.build(blueprint);
      expect(package.interface.screens, isNotEmpty);
    });
  });

  group('Security Limits', () {
    test('blueprint limits are defined', () {
      expect(BlueprintLimits.maxEntities, 10);
      expect(BlueprintLimits.maxFieldsPerEntity, 20);
      expect(BlueprintLimits.maxViews, 20);
      expect(BlueprintLimits.maxActions, 50);
      expect(BlueprintLimits.maxDerivedValues, 20);
    });
  });

  group('Offline Policy', () {
    test('local apps default to full offline', () {
      final blueprint = AppBlueprint(
        id: 'bp_local',
        name: 'Local App',
        description: 'A local app',
        archetypes: [AppArchetype.collection],
        offlinePolicy: OfflinePolicy.full,
      );
      expect(blueprint.offlinePolicy, OfflinePolicy.full);
    });

    test('network apps have networkRequired policy', () {
      final blueprint = AppBlueprint(
        id: 'bp_net',
        name: 'Net App',
        description: 'A network app',
        archetypes: [AppArchetype.reference],
        offlinePolicy: OfflinePolicy.networkRequired,
        networkConfig: const BlueprintNetworkConfig(purpose: 'Fetch data'),
      );
      expect(blueprint.offlinePolicy, OfflinePolicy.networkRequired);
    });
  });

  group('Open-World Tags', () {
    test('tags are open-world strings', () {
      final blueprint = AppBlueprint(
        id: 'bp_tags',
        name: 'Tags',
        description: 'Tags test',
        archetypes: [AppArchetype.collection],
        tags: ['plant_care', 'gardening', 'my_custom_domain'],
      );
      expect(blueprint.tags, contains('plant_care'));
      expect(blueprint.tags, contains('my_custom_domain'));
    });

    test('unknown domains require no source change', () {
      final blueprint = AppBlueprint(
        id: 'bp_unknown',
        name: 'Unknown',
        description: 'Unknown domain',
        archetypes: [AppArchetype.collection],
        tags: ['quantum_computing', 'neural_interface'],
      );
      expect(blueprint.tags, contains('quantum_computing'));
    });
  });
}
