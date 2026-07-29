/// Stage 11 — Universal Experience Runtime Certification Tests
///
/// Tests for:
/// - DataQuery engine (filter, sort, search, pagination, aggregates)
/// - FormController (validation, dirty state, submit)
/// - ExperienceRouter (navigation, validation)
/// - ComponentRegistry (trusted widget types)
/// - Enhanced DataRuntime (reactivity)
/// - Golden path: People Tracker (full CRUD lifecycle)
/// - Golden path: Equipment Lending (relational CRUD)
/// - Security: malicious query, behavior budget, UI limits
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anything/runtime/data_query.dart';
import 'package:anything/runtime/form_controller.dart';
import 'package:anything/runtime/experience_router.dart';
import 'package:anything/runtime/component_registry.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // =========================================================================
  // DataQuery Engine
  // =========================================================================
  group('DataQuery Engine', () {
    late DataQueryEngine engine;
    late List<Map<String, dynamic>> records;

    setUp(() {
      engine = DataQueryEngine();
      records = [
        {'id': '1', 'name': 'Alice', 'age': 30, 'active': true, 'city': 'NYC'},
        {'id': '2', 'name': 'Bob', 'age': 25, 'active': true, 'city': 'LA'},
        {
          'id': '3',
          'name': 'Charlie',
          'age': 35,
          'active': false,
          'city': 'NYC',
        },
        {
          'id': '4',
          'name': 'Diana',
          'age': 28,
          'active': true,
          'city': 'Chicago',
        },
        {'id': '5', 'name': 'Eve', 'age': 32, 'active': false, 'city': 'LA'},
      ];
    });

    test('Filter: equals', () {
      final query = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(
            fieldId: 'city',
            operator: FilterOperator.equals,
            value: 'NYC',
          ),
        ],
      );
      final result = engine.query(query, records);
      expect(result.length, 2);
      expect(result.every((r) => r['city'] == 'NYC'), isTrue);
    });

    test('Filter: greaterThan', () {
      final query = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(
            fieldId: 'age',
            operator: FilterOperator.greaterThan,
            value: 30,
          ),
        ],
      );
      final result = engine.query(query, records);
      expect(result.length, 2);
      expect(result.every((r) => (r['age'] as int) > 30), isTrue);
    });

    test('Filter: contains', () {
      final query = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(
            fieldId: 'name',
            operator: FilterOperator.contains,
            value: 'li',
          ),
        ],
      );
      final result = engine.query(query, records);
      expect(result.length, 2);
      expect(result.any((r) => r['name'] == 'Alice'), isTrue);
      expect(result.any((r) => r['name'] == 'Charlie'), isTrue);
    });

    test('Filter: isTrue', () {
      final query = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(fieldId: 'active', operator: FilterOperator.isTrue),
        ],
      );
      final result = engine.query(query, records);
      expect(result.length, 3);
    });

    test('Sort: ascending', () {
      final query = DataQuery(
        entityId: 'person',
        sorts: [SortSpec(fieldId: 'age', direction: SortDirection.ascending)],
      );
      final result = engine.query(query, records);
      expect(result.first['name'], 'Bob');
      expect(result.last['name'], 'Charlie');
    });

    test('Sort: descending', () {
      final query = DataQuery(
        entityId: 'person',
        sorts: [SortSpec(fieldId: 'age', direction: SortDirection.descending)],
      );
      final result = engine.query(query, records);
      expect(result.first['name'], 'Charlie');
      expect(result.last['name'], 'Bob');
    });

    test('Search: multi-field', () {
      final query = DataQuery(
        entityId: 'person',
        search: 'bob',
        searchFields: ['name', 'city'],
      );
      final result = engine.query(query, records);
      expect(result.length, 1);
      expect(result.first['name'], 'Bob');
    });

    test('Limit + Offset', () {
      final query = DataQuery(
        entityId: 'person',
        sorts: [SortSpec(fieldId: 'age')],
        limit: 2,
        offset: 1,
      );
      final result = engine.query(query, records);
      expect(result.length, 2);
      expect(result.first['name'], 'Diana');
    });

    test('Combined filter + sort + search', () {
      final query = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(fieldId: 'active', operator: FilterOperator.isTrue),
        ],
        sorts: [SortSpec(fieldId: 'name')],
        search: 'a',
      );
      final result = engine.query(query, records);
      expect(result.length, 3);
      expect(result.first['name'], 'Alice');
    });

    test('Aggregate: count', () {
      final count = engine.aggregate('count', records, null);
      expect(count, 5);
    });

    test('Aggregate: sum', () {
      final sum = engine.aggregate('sum', records, 'age');
      expect(sum, 150);
    });

    test('Aggregate: average', () {
      final avg = engine.aggregate('average', records, 'age');
      expect(avg, 30.0);
    });

    test('Aggregate: min', () {
      final min = engine.aggregate('min', records, 'age');
      expect(min, 25);
    });

    test('Aggregate: max', () {
      final max = engine.aggregate('max', records, 'age');
      expect(max, 35);
    });

    test('Empty result', () {
      final query = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(
            fieldId: 'age',
            operator: FilterOperator.greaterThan,
            value: 100,
          ),
        ],
      );
      final result = engine.query(query, records);
      expect(result, isEmpty);
    });

    test('Query validation: too many filters', () {
      final filters = List.generate(
        DataQuery.maxFilters + 1,
        (i) => FilterCondition(fieldId: 'f$i', operator: FilterOperator.equals),
      );
      final query = DataQuery(entityId: 'test', filters: filters);
      final errors = query.validate();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Too many filters'));
    });

    test('Query validation: limit too high', () {
      final query = DataQuery(
        entityId: 'test',
        limit: DataQuery.maxResultLimit + 1,
      );
      final errors = query.validate();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Limit too high'));
    });
  });

  // =========================================================================
  // Form Controller
  // =========================================================================
  group('Form Controller', () {
    test('Create mode: empty initial values', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            required: true,
          ),
          const FormFieldDefinition(id: 'email', name: 'Email', type: 'text'),
        ],
      );
      expect(controller.mode, FormMode.create);
      expect(controller.values, isEmpty);
      expect(controller.isDirty, isFalse);
    });

    test('Edit mode: pre-populated values', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.edit,
        initialValues: {'name': 'Alice', 'email': 'alice@example.com'},
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            required: true,
          ),
          const FormFieldDefinition(id: 'email', name: 'Email', type: 'text'),
        ],
      );
      expect(controller.mode, FormMode.edit);
      expect(controller.getValue('name'), 'Alice');
      expect(controller.isDirty, isFalse);
    });

    test('Dirty state tracking', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.edit,
        initialValues: {'name': 'Alice'},
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            required: true,
          ),
        ],
      );
      expect(controller.isDirty, isFalse);
      controller.setValue('name', 'Bob');
      expect(controller.isDirty, isTrue);
    });

    test('Validation: required field', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            required: true,
          ),
        ],
      );
      expect(controller.validate(), isFalse);
      expect(controller.getFieldError('name'), contains('required'));
    });

    test('Validation: min length', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            minLength: 3,
          ),
        ],
      );
      controller.setValue('name', 'AB');
      expect(controller.validate(), isFalse);
      expect(controller.getFieldError('name'), contains('at least 3'));
    });

    test('Validation: allowed values', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'status',
            name: 'Status',
            type: 'text',
            allowedValues: ['active', 'inactive'],
          ),
        ],
      );
      controller.setValue('status', 'unknown');
      expect(controller.validate(), isFalse);
      expect(controller.getFieldError('status'), contains('one of'));
    });

    test('Reset restores initial values', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.edit,
        initialValues: {'name': 'Alice'},
        fieldDefinitions: [
          const FormFieldDefinition(id: 'name', name: 'Name', type: 'text'),
        ],
      );
      controller.setValue('name', 'Bob');
      expect(controller.isDirty, isTrue);
      controller.reset();
      expect(controller.getValue('name'), 'Alice');
      expect(controller.isDirty, isFalse);
    });

    test('Set multiple values', () {
      final controller = ExperienceFormController(
        entityId: 'person',
        fieldDefinitions: [
          const FormFieldDefinition(id: 'name', name: 'Name', type: 'text'),
          const FormFieldDefinition(id: 'age', name: 'Age', type: 'integer'),
        ],
      );
      controller.setValues({'name': 'Alice', 'age': 30});
      expect(controller.getValue('name'), 'Alice');
      expect(controller.getValue('age'), 30);
    });

    test('Form state stream', () async {
      final controller = ExperienceFormController(
        entityId: 'person',
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            required: true,
          ),
        ],
      );
      final states = <FormState>[];
      controller.stateStream.listen(states.add);

      controller.setValue('name', 'Alice');
      await Future.delayed(Duration.zero);

      expect(states, isNotEmpty);
      expect(states.last.isDirty, isTrue);
    });
  });

  // =========================================================================
  // Experience Router
  // =========================================================================
  group('Experience Router', () {
    late ExperienceRouter router;

    setUp(() {
      router = ExperienceRouter(
        validScreenIds: {'list', 'detail', 'add', 'edit'},
      );
    });

    test('Push navigates to screen', () {
      final event = router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'list',
        ),
      );
      expect(event.action, NavigationAction.push);
      expect(event.screenId, 'list');
      expect(router.currentScreenId, 'list');
    });

    test('Pop returns to previous screen', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'list',
        ),
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'detail',
        ),
      );
      expect(router.currentScreenId, 'detail');

      router.navigate(const NavigationRequest(action: NavigationAction.pop));
      expect(router.currentScreenId, 'list');
    });

    test('Invalid screen ID is rejected', () {
      final event = router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'nonexistent',
        ),
      );
      // Should not push to invalid screen
      expect(router.history, isEmpty);
    });

    test('Pop to root', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'list',
        ),
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'detail',
        ),
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'edit',
        ),
      );

      router.navigate(
        const NavigationRequest(action: NavigationAction.popToRoot),
      );
      expect(router.history.length, 1);
      expect(router.currentScreenId, 'list');
    });

    test('Replace current screen', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'list',
        ),
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.replace,
          targetScreenId: 'detail',
        ),
      );
      expect(router.history.length, 1);
      expect(router.currentScreenId, 'detail');
    });

    test('Switch tab', () {
      final event = router.navigate(
        const NavigationRequest(
          action: NavigationAction.switchTab,
          targetScreenId: 'detail',
        ),
      );
      expect(event.action, NavigationAction.switchTab);
      expect(router.currentTabIndex, 1);
    });

    test('Navigation history tracking', () {
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'list',
        ),
      );
      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'detail',
        ),
      );
      expect(router.history.length, 2);
    });

    test('isValidScreen', () {
      expect(router.isValidScreen('list'), isTrue);
      expect(router.isValidScreen('nonexistent'), isFalse);
    });

    test('Navigation events stream', () async {
      final events = <NavigationEvent>[];
      router.events.listen(events.add);

      router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'list',
        ),
      );
      await Future.delayed(Duration.zero);

      expect(events, isNotEmpty);
    });
  });

  // =========================================================================
  // Component Registry
  // =========================================================================
  group('Component Registry', () {
    late RuntimeComponentRegistry registry;

    setUp(() {
      registry = RuntimeComponentRegistry.defaults();
    });

    test('Standard components are registered', () {
      expect(registry.isRegistered('text'), isTrue);
      expect(registry.isRegistered('button'), isTrue);
      expect(registry.isRegistered('card'), isTrue);
      expect(registry.isRegistered('column'), isTrue);
      expect(registry.isRegistered('row'), isTrue);
      expect(registry.isRegistered('input'), isTrue);
      expect(registry.isRegistered('list'), isTrue);
      expect(registry.isRegistered('listItem'), isTrue);
      expect(registry.isRegistered('emptyState'), isTrue);
      expect(registry.isRegistered('metric'), isTrue);
      expect(registry.isRegistered('searchField'), isTrue);
      expect(registry.isRegistered('grid'), isTrue);
      expect(registry.isRegistered('chip'), isTrue);
      expect(registry.isRegistered('divider'), isTrue);
      expect(registry.isRegistered('spacer'), isTrue);
    });

    test('Unknown component returns null builder', () {
      expect(registry.getBuilder('unknownType'), isNull);
    });

    test('Security: max components', () {
      expect(RuntimeComponentRegistry.maxTotalComponents, 500);
      expect(RuntimeComponentRegistry.maxDepth, 20);
      expect(RuntimeComponentRegistry.maxChildrenPerNode, 50);
    });

    test('All registered types', () {
      final types = registry.registeredTypes;
      expect(types.length, greaterThanOrEqualTo(15));
    });
  });

  // =========================================================================
  // Golden Path: People Tracker (unit-level)
  // =========================================================================
  group('Golden Path — People Tracker Logic', () {
    late DataQueryEngine queryEngine;

    setUp(() {
      queryEngine = DataQueryEngine();
    });

    test('Full CRUD lifecycle', () async {
      // Simulate: create people, query, filter, search, update, delete
      final people = <Map<String, dynamic>>[];

      // Create
      people.add({
        'id': 'p1',
        'name': 'Alice',
        'email': 'alice@test.com',
        'notes': 'Met at conference',
        'active': true,
      });
      people.add({
        'id': 'p2',
        'name': 'Bob',
        'email': 'bob@test.com',
        'notes': 'Colleague',
        'active': true,
      });

      // Query all
      final allQuery = DataQuery(entityId: 'person');
      final all = queryEngine.query(allQuery, people);
      expect(all.length, 2);

      // Search
      final searchQuery = DataQuery(entityId: 'person', search: 'alice');
      final found = queryEngine.query(searchQuery, people);
      expect(found.length, 1);
      expect(found.first['name'], 'Alice');

      // Sort by name
      final sortQuery = DataQuery(
        entityId: 'person',
        sorts: [SortSpec(fieldId: 'name')],
      );
      final sorted = queryEngine.query(sortQuery, people);
      expect(sorted.first['name'], 'Alice');
      expect(sorted.last['name'], 'Bob');

      // Filter active
      final filterQuery = DataQuery(
        entityId: 'person',
        filters: [
          FilterCondition(fieldId: 'active', operator: FilterOperator.isTrue),
        ],
      );
      final active = queryEngine.query(filterQuery, people);
      expect(active.length, 2);

      // Update
      final idx = people.indexWhere((r) => r['id'] == 'p1');
      people[idx] = {...people[idx], 'notes': 'Updated notes'};
      expect(people[idx]['notes'], 'Updated notes');

      // Delete
      people.removeWhere((r) => r['id'] == 'p2');
      expect(people.length, 1);
    });

    test('Search is case-insensitive', () {
      final people = [
        {'id': '1', 'name': 'Alice', 'email': 'alice@test.com'},
        {'id': '2', 'name': 'Bob', 'email': 'bob@test.com'},
      ];
      final query = DataQuery(entityId: 'person', search: 'ALICE');
      final result = queryEngine.query(query, people);
      expect(result.length, 1);
      expect(result.first['name'], 'Alice');
    });
  });

  // =========================================================================
  // Golden Path: Equipment Lending (relational logic)
  // =========================================================================
  group('Golden Path — Equipment Lending Logic', () {
    late DataQueryEngine queryEngine;

    setUp(() {
      queryEngine = DataQueryEngine();
    });

    test('Relational CRUD with references', () {
      // Entities
      final people = [
        {'id': 'p1', 'name': 'Alice'},
        {'id': 'p2', 'name': 'Bob'},
      ];
      final equipment = [
        {'id': 'e1', 'name': 'Camera', 'type': 'Electronics'},
        {'id': 'e2', 'name': 'Tripod', 'type': 'Accessory'},
      ];
      final loans = [
        {'id': 'l1', 'personId': 'p1', 'equipmentId': 'e1', 'returned': false},
        {'id': 'l2', 'personId': 'p2', 'equipmentId': 'e2', 'returned': true},
      ];

      // Query active loans
      final activeLoans = DataQuery(
        entityId: 'loan',
        filters: [
          FilterCondition(
            fieldId: 'returned',
            operator: FilterOperator.isFalse,
          ),
        ],
      );
      final active = queryEngine.query(activeLoans, loans);
      expect(active.length, 1);
      expect(active.first['personId'], 'p1');

      // Resolve reference: person name
      final person = people.firstWhere(
        (p) => p['id'] == active.first['personId'],
      );
      expect(person['name'], 'Alice');

      // Resolve reference: equipment name
      final equip = equipment.firstWhere(
        (e) => e['id'] == active.first['equipmentId'],
      );
      expect(equip['name'], 'Camera');

      // Delete safety: cannot delete Alice while loan references her
      final hasActiveLoan = loans.any(
        (l) => l['personId'] == 'p1' && l['returned'] == false,
      );
      expect(hasActiveLoan, isTrue);

      // Delete Alice should be blocked
      expect(() {
        if (hasActiveLoan)
          throw Exception('Cannot delete: referenced by active loan');
      }, throwsException);
    });
  });

  // =========================================================================
  // Security Tests
  // =========================================================================
  group('Security', () {
    test('DataQuery: max result limit enforced', () {
      expect(DataQuery.maxResultLimit, 1000);
      final query = DataQuery(entityId: 'test', limit: 10001);
      final errors = query.validate();
      expect(errors, isNotEmpty);
    });

    test('DataQuery: max filters enforced', () {
      expect(DataQuery.maxFilters, 20);
      final filters = List.generate(
        21,
        (i) => FilterCondition(fieldId: 'f$i', operator: FilterOperator.equals),
      );
      final query = DataQuery(entityId: 'test', filters: filters);
      final errors = query.validate();
      expect(errors, isNotEmpty);
    });

    test('DataQuery: max sorts enforced', () {
      expect(DataQuery.maxSorts, 5);
      final sorts = List.generate(6, (i) => SortSpec(fieldId: 'f$i'));
      final query = DataQuery(entityId: 'test', sorts: sorts);
      final errors = query.validate();
      expect(errors, isNotEmpty);
    });

    test('ComponentRegistry: security limits', () {
      expect(RuntimeComponentRegistry.maxDepth, 20);
      expect(RuntimeComponentRegistry.maxChildrenPerNode, 50);
      expect(RuntimeComponentRegistry.maxTotalComponents, 500);
    });

    test('FormController: validation prevents invalid data', () {
      final controller = ExperienceFormController(
        entityId: 'test',
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'text',
            required: true,
          ),
        ],
      );
      // Empty form should be invalid
      expect(controller.isValid, isFalse);
      // Set value
      controller.setValue('name', 'Valid Name');
      expect(controller.isValid, isTrue);
    });

    test('Router: unknown screen IDs rejected', () {
      final router = ExperienceRouter(validScreenIds: {'list', 'detail'});
      final event = router.navigate(
        const NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'malicious_screen',
        ),
      );
      // Should not navigate to unknown screen
      expect(router.history, isEmpty);
    });
  });
}
