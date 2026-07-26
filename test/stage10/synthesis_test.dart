/// Stage 10 tests — Universal App Synthesis & Multi-Archetype Generation.
///
/// Tests the entire synthesis pipeline:
/// Intent → IntentUnderstanding → AppBlueprint → BlueprintValidator →
/// SynthesisPlanner → ExperiencePackage → Runtime → Persistence → Modification.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/blueprint_validator.dart';
import 'package:anything/synthesis/synthesis_planner.dart';
import 'package:anything/synthesis/synthesis_patterns.dart';
import 'package:anything/synthesis/blueprint_to_spec.dart';
import 'package:anything/synthesis/generic_package_builder.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('AppArchetype', () {
    test('enum has all required archetypes', () {
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
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test App',
        description: 'A test application',
        archetypes: [AppArchetype.collection],
        entities: [
          BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'item_name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
      );

      final result = BlueprintValidator.validate(blueprint);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('empty ID fails validation', () {
      const blueprint = AppBlueprint(
        id: '',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
      );

      final result = BlueprintValidator.validate(blueprint);
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Blueprint ID is required'));
    });

    test('empty name fails validation', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: '',
        description: 'Test',
        archetypes: [AppArchetype.collection],
      );

      final result = BlueprintValidator.validate(blueprint);
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Blueprint name is required'));
    });

    test('no archetypes fails validation', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [],
      );

      final result = BlueprintValidator.validate(blueprint);
      expect(result.isValid, isFalse);
      expect(result.errors, contains('At least one archetype is required'));
    });

    test('duplicate entity IDs fail validation', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
        entities: [
          BlueprintEntity(id: 'item', name: 'Item 1', fields: []),
          BlueprintEntity(id: 'item', name: 'Item 2', fields: []),
        ],
      );

      final result = BlueprintValidator.validate(blueprint);
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('Duplicate entity ID')),
        isTrue,
      );
    });

    test('limits are enforced', () {
      final entities = List.generate(
        11,
        (i) => BlueprintEntity(
          id: 'entity_$i',
          name: 'Entity $i',
          fields: [
            BlueprintField(id: 'f', name: 'F', type: BlueprintFieldType.text),
          ],
        ),
      );

      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
      );

      final result = BlueprintValidator.validate(
        blueprint.copyWith(entities: entities),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Too many entities')), isTrue);
    });
  });

  group('SynthesisPlanner', () {
    IntentUnderstanding _makeUnderstanding(String objective) {
      return IntentUnderstanding(
        intentId: Intent.create(
          expression: 'test intent',
          description: 'test',
        ).id,
        objective: objective,
        category: IntentCategory.create,
        existingExperience: ExistingExperienceResolution.notChecked(),
        desiredOutcome: objective,
        constraints: [],
        requiredInputs: [],
        assumptions: [],
        confidence: 0.9,
        ambiguities: [],
        networkNeed: NetworkNeed.none,
        creationNeed: CreationNeed.definitelyNeeded,
        modificationNeed: ModificationNeed.notNeeded,
      );
    }

    test('detects collection archetype for notes', () {
      final planner = const SynthesisPlanner();
      final result = planner.plan(_makeUnderstanding('Make me a notes app'));

      expect(result.blueprint.archetypes, contains(AppArchetype.collection));
      expect(result.blueprint.domain, equals(AppDomain.notes));
      expect(result.blueprint.entities, isNotEmpty);
      expect(result.blueprint.entities.first.name, equals('Note'));
    });

    test('detects tracker archetype for habits', () {
      final planner = const SynthesisPlanner();
      final result = planner.plan(
        _makeUnderstanding('Make me a habit tracker'),
      );

      expect(result.blueprint.archetypes, contains(AppArchetype.tracker));
      expect(result.blueprint.domain, equals(AppDomain.habits));
      expect(result.blueprint.entities, isNotEmpty);
    });

    test('detects dashboard archetype for expenses', () {
      final planner = const SynthesisPlanner();
      final result = planner.plan(
        _makeUnderstanding('Make me an expense tracker'),
      );

      expect(result.blueprint.archetypes, contains(AppArchetype.dashboard));
      expect(result.blueprint.domain, equals(AppDomain.finances));
      expect(result.blueprint.derivedValues, isNotEmpty);
    });

    test('detects planner archetype for study', () {
      final planner = const SynthesisPlanner();
      final result = planner.plan(
        _makeUnderstanding('Make me a study planner'),
      );

      expect(result.blueprint.archetypes, contains(AppArchetype.planner));
      expect(result.blueprint.entities, isNotEmpty);
    });

    test('detects collection archetype for reading list', () {
      final planner = const SynthesisPlanner();
      final result = planner.plan(_makeUnderstanding('Make me a reading list'));

      expect(result.blueprint.archetypes, contains(AppArchetype.collection));
      expect(result.blueprint.domain, equals(AppDomain.reading));
      expect(result.blueprint.entities, isNotEmpty);
    });

    test('blueprint has required fields', () {
      final planner = const SynthesisPlanner();
      final result = planner.plan(_makeUnderstanding('Make me a notes app'));

      expect(result.blueprint.id, isNotEmpty);
      expect(result.blueprint.name, isNotEmpty);
      expect(result.blueprint.views, isNotEmpty);
      expect(result.blueprint.actions, isNotEmpty);
      expect(result.blueprint.offlinePolicy, equals(OfflinePolicy.full));
    });
  });

  group('Blueprint Serialization', () {
    test('toJson and fromJson roundtrip', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test App',
        description: 'A test application',
        archetypes: [AppArchetype.collection, AppArchetype.hybrid],
        domain: AppDomain.notes,
        entities: [
          BlueprintEntity(
            id: 'note',
            name: 'Note',
            fields: [
              BlueprintField(
                id: 'note_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'note_title',
                name: 'Title',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'note_content',
                name: 'Content',
                type: BlueprintFieldType.multilineText,
              ),
              BlueprintField(
                id: 'note_active',
                name: 'Active',
                type: BlueprintFieldType.boolean,
                defaultValue: 'true',
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'note_list',
            name: 'Notes',
            purpose: 'View all notes',
            sourceEntityId: 'note',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_note',
            name: 'Create Note',
            targetEntityId: 'note',
            actionType: BlueprintActionType.create,
          ),
        ],
        derivedValues: [
          BlueprintDerivedValue(
            id: 'note_count',
            name: 'Note Count',
            sourceEntityId: 'note',
            operation: DerivedOperation.count,
          ),
        ],
      );

      final json = blueprint.toJson();
      final restored = AppBlueprint.fromJson(json);

      expect(restored.id, equals(blueprint.id));
      expect(restored.name, equals(blueprint.name));
      expect(restored.archetypes.length, equals(blueprint.archetypes.length));
      expect(restored.entities.length, equals(blueprint.entities.length));
      expect(
        restored.entities.first.fields.length,
        equals(blueprint.entities.first.fields.length),
      );
      expect(restored.views.length, equals(blueprint.views.length));
      expect(restored.actions.length, equals(blueprint.actions.length));
      expect(
        restored.derivedValues.length,
        equals(blueprint.derivedValues.length),
      );
    });
  });

  group('Blueprint to ExperienceSpec', () {
    test('converts collection blueprint to spec', () {
      const blueprint = AppBlueprint(
        id: 'bp_notes',
        name: 'Notes',
        description: 'A notes application',
        archetypes: [AppArchetype.collection],
        domain: AppDomain.notes,
        entities: [
          BlueprintEntity(
            id: 'note',
            name: 'Note',
            fields: [
              BlueprintField(
                id: 'note_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'note_title',
                name: 'Title',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'note_content',
                name: 'Content',
                type: BlueprintFieldType.multilineText,
              ),
            ],
          ),
        ],
      );

      final spec = BlueprintToSpecConverter.convert(blueprint);

      expect(spec.id, equals('bp_notes'));
      expect(spec.name, equals('Notes'));
      expect(spec.category, equals(ExperienceCategory.productivity));
      expect(
        spec.storageRequirements.storageType,
        equals(StorageType.localDatabase),
      );
      expect(spec.networkRequirements.networkNeed, equals(NetworkNeed.none));
      expect(
        spec.offlineBehavior.offlineCapability,
        equals(OfflineCapability.fullyOffline),
      );
    });

    test('converts dashboard blueprint to spec', () {
      const blueprint = AppBlueprint(
        id: 'bp_expenses',
        name: 'Expense Tracker',
        description: 'Track expenses',
        archetypes: [AppArchetype.dashboard],
        domain: AppDomain.finances,
        entities: [
          BlueprintEntity(
            id: 'expense',
            name: 'Expense',
            fields: [
              BlueprintField(
                id: 'expense_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'expense_amount',
                name: 'Amount',
                type: BlueprintFieldType.decimal,
                required: true,
              ),
            ],
          ),
        ],
      );

      final spec = BlueprintToSpecConverter.convert(blueprint);

      expect(spec.interactionModel, equals(InteractionModel.dashboard));
      expect(spec.category, equals(ExperienceCategory.finance));
    });
  });

  group('GenericPackageBuilder', () {
    test('builds valid package from collection blueprint', () {
      const blueprint = AppBlueprint(
        id: 'bp_notes',
        name: 'Notes',
        description: 'A notes application',
        archetypes: [AppArchetype.collection],
        domain: AppDomain.notes,
        entities: [
          BlueprintEntity(
            id: 'note',
            name: 'Note',
            fields: [
              BlueprintField(
                id: 'note_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'note_title',
                name: 'Title',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'note_content',
                name: 'Content',
                type: BlueprintFieldType.multilineText,
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'note_list',
            name: 'Notes',
            purpose: 'All notes',
            sourceEntityId: 'note',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
          BlueprintView(
            id: 'note_form',
            name: 'Add Note',
            purpose: 'Create note',
            entityId: 'note',
            viewType: BlueprintViewType.form,
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_note',
            name: 'Create Note',
            targetEntityId: 'note',
            actionType: BlueprintActionType.create,
          ),
          BlueprintAction(
            id: 'save_note',
            name: 'Save Note',
            targetEntityId: 'note',
            actionType: BlueprintActionType.update,
          ),
          BlueprintAction(
            id: 'delete_note',
            name: 'Delete Note',
            targetEntityId: 'note',
            actionType: BlueprintActionType.delete,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.packageVersion, equals(experiencePackageVersion));
      expect(pkg.manifest.experienceId, equals('bp_notes'));
      expect(pkg.manifest.name, equals('Notes'));
      expect(pkg.manifest.storageMode, equals(StorageMode.localDatabase));
      expect(pkg.manifest.networkMode, equals(NetworkMode.none));
      expect(pkg.interface.screens.length, equals(2));
      expect(pkg.behavior.nodes, isNotEmpty);
      expect(pkg.state.variables, isNotEmpty);
      expect(pkg.data, isNotNull);
      expect(pkg.data!.entities.length, equals(1));
      expect(pkg.data!.entities.first.id, equals('note'));
      expect(pkg.data!.entities.first.fields.length, equals(3));
    });

    test('builds valid package from tracker blueprint', () {
      const blueprint = AppBlueprint(
        id: 'bp_habits',
        name: 'Habit Tracker',
        description: 'Track daily habits',
        archetypes: [AppArchetype.tracker],
        domain: AppDomain.habits,
        entities: [
          BlueprintEntity(
            id: 'habit',
            name: 'Habit',
            fields: [
              BlueprintField(
                id: 'habit_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'habit_name',
                name: 'Name',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'habit_created_at',
                name: 'Created',
                type: BlueprintFieldType.dateTime,
                required: true,
              ),
            ],
          ),
          BlueprintEntity(
            id: 'habit_completions',
            name: 'Habit Completions',
            fields: [
              BlueprintField(
                id: 'completion_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'trackable_id',
                name: 'Trackable ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'completion_date',
                name: 'Date',
                type: BlueprintFieldType.date,
                required: true,
              ),
              BlueprintField(
                id: 'completed',
                name: 'Completed',
                type: BlueprintFieldType.boolean,
                defaultValue: 'false',
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'habit_today',
            name: 'Today',
            purpose: "Today's habits",
            sourceEntityId: 'habit',
            viewType: BlueprintViewType.dashboard,
            isDefault: true,
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_habit',
            name: 'Add Habit',
            targetEntityId: 'habit',
            actionType: BlueprintActionType.create,
          ),
          BlueprintAction(
            id: 'toggle_habit',
            name: 'Toggle Habit',
            targetEntityId: 'habit',
            actionType: BlueprintActionType.toggle,
          ),
        ],
        derivedValues: [
          BlueprintDerivedValue(
            id: 'today_completed',
            name: 'Completed Today',
            sourceEntityId: 'habit_completions',
            operation: DerivedOperation.count,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.manifest.experienceId, equals('bp_habits'));
      expect(pkg.data!.entities.length, equals(2));
      expect(pkg.state.variables.length, greaterThan(2));
    });

    test('builds valid package from dashboard blueprint', () {
      const blueprint = AppBlueprint(
        id: 'bp_expenses',
        name: 'Expense Tracker',
        description: 'Track expenses',
        archetypes: [AppArchetype.dashboard],
        domain: AppDomain.finances,
        entities: [
          BlueprintEntity(
            id: 'expense',
            name: 'Expense',
            fields: [
              BlueprintField(
                id: 'expense_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'expense_amount',
                name: 'Amount',
                type: BlueprintFieldType.decimal,
                required: true,
              ),
              BlueprintField(
                id: 'expense_category',
                name: 'Category',
                type: BlueprintFieldType.category,
                allowedValues: ['Food', 'Transport', 'Other'],
              ),
              BlueprintField(
                id: 'expense_date',
                name: 'Date',
                type: BlueprintFieldType.date,
                required: true,
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'expense_overview',
            name: 'Overview',
            purpose: 'Expense overview',
            sourceEntityId: 'expense',
            viewType: BlueprintViewType.dashboard,
            isDefault: true,
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_expense',
            name: 'Add Expense',
            targetEntityId: 'expense',
            actionType: BlueprintActionType.create,
          ),
          BlueprintAction(
            id: 'delete_expense',
            name: 'Delete Expense',
            targetEntityId: 'expense',
            actionType: BlueprintActionType.delete,
          ),
        ],
        derivedValues: [
          BlueprintDerivedValue(
            id: 'total_amount',
            name: 'Total',
            sourceEntityId: 'expense',
            operation: DerivedOperation.sum,
            fieldId: 'expense_amount',
          ),
          BlueprintDerivedValue(
            id: 'expense_count',
            name: 'Count',
            sourceEntityId: 'expense',
            operation: DerivedOperation.count,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.manifest.experienceId, equals('bp_expenses'));
      expect(pkg.data!.entities.length, equals(1));
      expect(pkg.data!.entities.first.fields.length, equals(4));
    });

    test('builds valid package from planner blueprint', () {
      const blueprint = AppBlueprint(
        id: 'bp_study',
        name: 'Study Planner',
        description: 'Plan your studies',
        archetypes: [AppArchetype.planner],
        domain: AppDomain.education,
        entities: [
          BlueprintEntity(
            id: 'study_task',
            name: 'Study Task',
            fields: [
              BlueprintField(
                id: 'study_task_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'study_task_title',
                name: 'Title',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'study_subject',
                name: 'Subject',
                type: BlueprintFieldType.text,
              ),
              BlueprintField(
                id: 'study_task_due_date',
                name: 'Due Date',
                type: BlueprintFieldType.date,
              ),
              BlueprintField(
                id: 'study_task_completed',
                name: 'Completed',
                type: BlueprintFieldType.boolean,
                defaultValue: 'false',
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'study_upcoming',
            name: 'Upcoming',
            purpose: 'Upcoming tasks',
            sourceEntityId: 'study_task',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_study_task',
            name: 'Add Task',
            targetEntityId: 'study_task',
            actionType: BlueprintActionType.create,
          ),
          BlueprintAction(
            id: 'complete_study_task',
            name: 'Complete Task',
            targetEntityId: 'study_task',
            actionType: BlueprintActionType.setValue,
          ),
        ],
        derivedValues: [
          BlueprintDerivedValue(
            id: 'pending_count',
            name: 'Pending',
            sourceEntityId: 'study_task',
            operation: DerivedOperation.count,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.manifest.experienceId, equals('bp_study'));
      expect(pkg.data!.entities.length, equals(1));
      expect(pkg.data!.entities.first.fields.length, equals(5));
    });

    test('builds valid package from collection (reading list) blueprint', () {
      const blueprint = AppBlueprint(
        id: 'bp_reading',
        name: 'Reading List',
        description: 'Track books',
        archetypes: [AppArchetype.collection],
        domain: AppDomain.reading,
        entities: [
          BlueprintEntity(
            id: 'book',
            name: 'Book',
            fields: [
              BlueprintField(
                id: 'book_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'book_name',
                name: 'Title',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'book_author',
                name: 'Author',
                type: BlueprintFieldType.text,
              ),
              BlueprintField(
                id: 'book_status',
                name: 'Status',
                type: BlueprintFieldType.category,
                allowedValues: ['Want to Read', 'Reading', 'Finished'],
                defaultValue: 'Want to Read',
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'book_list',
            name: 'Books',
            purpose: 'All books',
            sourceEntityId: 'book',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_book',
            name: 'Add Book',
            targetEntityId: 'book',
            actionType: BlueprintActionType.create,
          ),
          BlueprintAction(
            id: 'update_book',
            name: 'Update Book',
            targetEntityId: 'book',
            actionType: BlueprintActionType.update,
          ),
        ],
        derivedValues: [
          BlueprintDerivedValue(
            id: 'finished_count',
            name: 'Finished',
            sourceEntityId: 'book',
            operation: DerivedOperation.count,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.manifest.experienceId, equals('bp_reading'));
      expect(pkg.data!.entities.length, equals(1));
      expect(pkg.data!.entities.first.fields.length, equals(4));
    });

    test('behavior graph has event nodes for all actions', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
        entities: [
          BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
        actions: [
          BlueprintAction(
            id: 'create_item',
            name: 'Create',
            targetEntityId: 'item',
            actionType: BlueprintActionType.create,
          ),
          BlueprintAction(
            id: 'update_item',
            name: 'Update',
            targetEntityId: 'item',
            actionType: BlueprintActionType.update,
          ),
          BlueprintAction(
            id: 'delete_item',
            name: 'Delete',
            targetEntityId: 'item',
            actionType: BlueprintActionType.delete,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      final eventNodes = pkg.behavior.nodes
          .where((n) => n.type == 'event')
          .toList();
      expect(eventNodes.length, equals(3));
    });

    test('multi-screen apps have navigation', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
        entities: [
          BlueprintEntity(
            id: 'item',
            name: 'Item',
            fields: [
              BlueprintField(
                id: 'item_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
            ],
          ),
        ],
        views: [
          BlueprintView(
            id: 'list',
            name: 'List',
            purpose: 'Items',
            sourceEntityId: 'item',
            viewType: BlueprintViewType.list,
            isDefault: true,
          ),
          BlueprintView(
            id: 'form',
            name: 'Form',
            purpose: 'Add Item',
            entityId: 'item',
            viewType: BlueprintViewType.form,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.interface.navigation, isNotNull);
      expect(pkg.interface.navigation!.items, isNotEmpty);
    });

    test('single-screen apps have no navigation', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.utility],
        views: [
          BlueprintView(
            id: 'main',
            name: 'Main',
            purpose: 'Main',
            viewType: BlueprintViewType.dashboard,
            isDefault: true,
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.interface.navigation, isNull);
    });

    test('derived values create query and calculation nodes', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.dashboard],
        entities: [
          BlueprintEntity(
            id: 'record',
            name: 'Record',
            fields: [
              BlueprintField(
                id: 'record_id',
                name: 'ID',
                type: BlueprintFieldType.text,
                required: true,
              ),
              BlueprintField(
                id: 'record_amount',
                name: 'Amount',
                type: BlueprintFieldType.decimal,
              ),
            ],
          ),
        ],
        derivedValues: [
          BlueprintDerivedValue(
            id: 'total',
            name: 'Total',
            sourceEntityId: 'record',
            operation: DerivedOperation.sum,
            fieldId: 'record_amount',
          ),
        ],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      final queryNodes = pkg.behavior.nodes
          .where((n) => n.type == 'dataQuery')
          .toList();
      final calcNodes = pkg.behavior.nodes
          .where((n) => n.type == 'calculation')
          .toList();
      expect(queryNodes, isNotEmpty);
      expect(calcNodes, isNotEmpty);
    });

    test('integrity hash is computed', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.utility],
      );

      final pkg = GenericPackageBuilder.build(blueprint);

      expect(pkg.integrity.contentHash, isNotEmpty);
      expect(pkg.integrity.contentHash.length, equals(64)); // SHA-256 hex
    });
  });

  group('End-to-End Pipeline', () {
    test('intent → understanding → planner → blueprint → package', () {
      final intent = Intent.create(
        expression: 'Make me a notes app',
        description: 'Make me a notes app',
      );
      final understanding = IntentUnderstanding(
        intentId: intent.id,
        objective: 'Make me a notes app',
        category: IntentCategory.create,
        existingExperience: ExistingExperienceResolution.notChecked(),
        desiredOutcome: 'A notes application',
        constraints: [],
        requiredInputs: [],
        assumptions: [],
        confidence: 0.9,
        ambiguities: [],
        networkNeed: NetworkNeed.none,
        creationNeed: CreationNeed.definitelyNeeded,
        modificationNeed: ModificationNeed.notNeeded,
      );

      final planner = const SynthesisPlanner();
      final synthesisResult = planner.plan(understanding);

      final validation = BlueprintValidator.validate(synthesisResult.blueprint);
      expect(validation.isValid, isTrue);

      final pkg = GenericPackageBuilder.build(synthesisResult.blueprint);
      expect(pkg.manifest.name, isNotEmpty);
      expect(pkg.interface.screens, isNotEmpty);
      expect(pkg.behavior.nodes, isNotEmpty);
      expect(pkg.data, isNotNull);
    });

    test('all five golden archetypes produce valid packages', () {
      final intents = [
        'Make me a notes app',
        'Make me a habit tracker',
        'Make me an expense tracker',
        'Make me a study planner',
        'Make me a reading list',
      ];

      for (final intentText in intents) {
        final intent = Intent.create(
          expression: intentText,
          description: intentText,
        );
        final understanding = IntentUnderstanding(
          intentId: intent.id,
          objective: intentText,
          category: IntentCategory.create,
          existingExperience: ExistingExperienceResolution.notChecked(),
          desiredOutcome: intentText,
          constraints: [],
          requiredInputs: [],
          assumptions: [],
          confidence: 0.9,
          ambiguities: [],
          networkNeed: NetworkNeed.none,
          creationNeed: CreationNeed.definitelyNeeded,
          modificationNeed: ModificationNeed.notNeeded,
        );

        final planner = const SynthesisPlanner();
        final synthesisResult = planner.plan(understanding);

        final validation = BlueprintValidator.validate(
          synthesisResult.blueprint,
        );
        expect(
          validation.isValid,
          isTrue,
          reason: 'Blueprint invalid for: $intentText',
        );

        final pkg = GenericPackageBuilder.build(synthesisResult.blueprint);
        expect(
          pkg.manifest.name,
          isNotEmpty,
          reason: 'Package name empty for: $intentText',
        );
        expect(
          pkg.interface.screens,
          isNotEmpty,
          reason: 'No screens for: $intentText',
        );
        expect(
          pkg.behavior.nodes,
          isNotEmpty,
          reason: 'No behavior for: $intentText',
        );
      }
    });

    test('no app-specific production screens in generated packages', () {
      final intents = [
        'Make me a notes app',
        'Make me a habit tracker',
        'Make me an expense tracker',
        'Make me a study planner',
        'Make me a reading list',
      ];

      for (final intentText in intents) {
        final intent = Intent.create(
          expression: intentText,
          description: intentText,
        );
        final understanding = IntentUnderstanding(
          intentId: intent.id,
          objective: intentText,
          category: IntentCategory.create,
          existingExperience: ExistingExperienceResolution.notChecked(),
          desiredOutcome: intentText,
          constraints: [],
          requiredInputs: [],
          assumptions: [],
          confidence: 0.9,
          ambiguities: [],
          networkNeed: NetworkNeed.none,
          creationNeed: CreationNeed.definitelyNeeded,
          modificationNeed: ModificationNeed.notNeeded,
        );

        final planner = const SynthesisPlanner();
        final synthesisResult = planner.plan(understanding);
        final pkg = GenericPackageBuilder.build(synthesisResult.blueprint);

        // Verify no hardcoded app-specific screen names
        final screenTitles = pkg.interface.screens.map((s) => s.title).toList();
        for (final title in screenTitles) {
          expect(
            title.toLowerCase(),
            isNot(contains('notesscreen')),
            reason: 'Found NotesScreen in: $intentText',
          );
          expect(
            title.toLowerCase(),
            isNot(contains('habittrackerscreen')),
            reason: 'Found HabitTrackerScreen in: $intentText',
          );
          expect(
            title.toLowerCase(),
            isNot(contains('expensetrackerscreen')),
            reason: 'Found ExpenseTrackerScreen in: $intentText',
          );
          expect(
            title.toLowerCase(),
            isNot(contains('studyplannerscreen')),
            reason: 'Found StudyPlannerScreen in: $intentText',
          );
          expect(
            title.toLowerCase(),
            isNot(contains('readinglistscreen')),
            reason: 'Found ReadingListScreen in: $intentText',
          );
        }
      }
    });
  });

  group('Pattern Registry', () {
    test('has default patterns registered', () {
      expect(PatternRegistry.registeredPatterns, contains('collection'));
      expect(PatternRegistry.registeredPatterns, contains('tracker'));
      expect(PatternRegistry.registeredPatterns, contains('planner'));
      expect(PatternRegistry.registeredPatterns, contains('dashboard'));
    });

    test('can retrieve patterns by ID', () {
      final collection = PatternRegistry.getPattern('collection');
      expect(collection, isNotNull);
      expect(collection!.patternId, equals('collection'));
    });
  });

  group('Weather / Network Classification', () {
    test('weather intent is classified as reference/network archetype', () {
      final planner = const SynthesisPlanner();
      final understanding = IntentUnderstanding(
        intentId: Intent.create(expression: 'test', description: 'test').id,
        objective: 'Make me a weather dashboard',
        category: IntentCategory.create,
        existingExperience: ExistingExperienceResolution.notChecked(),
        desiredOutcome: 'Weather dashboard',
        constraints: [],
        requiredInputs: [],
        assumptions: [],
        confidence: 0.8,
        ambiguities: [],
        networkNeed: NetworkNeed.required,
        creationNeed: CreationNeed.definitelyNeeded,
        modificationNeed: ModificationNeed.notNeeded,
      );

      final result = planner.plan(understanding);
      // Weather should be classified as reference or have network requirements
      expect(
        result.blueprint.archetypes.contains(AppArchetype.reference) ||
            result.blueprint.networkConfig != null ||
            result.blueprint.offlinePolicy != OfflinePolicy.full,
        isTrue,
        reason: 'Weather should have network classification',
      );
    });
  });

  group('Offline Policy', () {
    test('local apps default to full offline', () {
      const blueprint = AppBlueprint(
        id: 'bp_test',
        name: 'Test',
        description: 'Test',
        archetypes: [AppArchetype.collection],
        offlinePolicy: OfflinePolicy.full,
      );

      expect(blueprint.offlinePolicy, equals(OfflinePolicy.full));
    });

    test('network apps have partial/networkRequired policy', () {
      const blueprint = AppBlueprint(
        id: 'bp_weather',
        name: 'Weather',
        description: 'Weather app',
        archetypes: [AppArchetype.reference],
        offlinePolicy: OfflinePolicy.networkRequired,
        networkConfig: BlueprintNetworkConfig(purpose: 'Weather data'),
      );

      expect(blueprint.offlinePolicy, equals(OfflinePolicy.networkRequired));
      expect(blueprint.networkConfig, isNotNull);
    });
  });

  group('Security Limits', () {
    test('blueprint limits are defined', () {
      expect(BlueprintLimits.maxEntities, equals(10));
      expect(BlueprintLimits.maxFieldsPerEntity, equals(20));
      expect(BlueprintLimits.maxViews, equals(20));
      expect(BlueprintLimits.maxActions, equals(50));
      expect(BlueprintLimits.maxDerivedValues, equals(20));
      expect(BlueprintLimits.maxCapabilities, equals(10));
    });
  });
}
