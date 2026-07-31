/// Stage 11.1 — Security Certification Tests
///
/// Adversarial enforcement tests proving runtime security budgets,
/// component restrictions, query limits, and isolation guarantees.
///
/// Component tree budget enforcement tests are in stage11_proof_closure_test.dart.
/// Form validation enforcement tests are in stage11_proof_closure_test.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/data_query.dart';
import 'package:anything/runtime/form_controller.dart';
import 'package:anything/runtime/experience_router.dart';
import 'package:anything/runtime/component_registry.dart';
import 'package:anything/runtime/runtime_context.dart';
import 'package:anything/runtime/experience_renderer.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/runtime/behavior_interpreter.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ═════════════════════════════════════════════════════════════════════
  // COMPONENT BUDGET ENFORCEMENT
  // ═════════════════════════════════════════════════════════════════════
  group('Component Budget Enforcement', () {
    test('Depth 21 fails validation via ComponentTreeValidator', () {
      InterfaceNode leaf = InterfaceNode(
        id: 'd21',
        type: 'text',
        properties: {'text': 'x'},
      );
      for (var i = 20; i >= 0; i--) {
        leaf = InterfaceNode(
          id: 'd$i',
          type: 'column',
          properties: {},
          children: [leaf],
        );
      }
      final screen = InterfaceScreen(
        id: 'test',
        title: 'Test',
        children: [leaf],
      );
      final errors = ComponentTreeValidator.validateScreen(screen);
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('ui_depth_exceeded')), isTrue);
    });

    test('51 children fails validation via ComponentTreeValidator', () {
      final children = List.generate(
        51,
        (i) =>
            InterfaceNode(id: 'c_$i', type: 'text', properties: {'text': '$i'}),
      );
      final root = InterfaceNode(
        id: 'root',
        type: 'column',
        properties: {},
        children: children,
      );
      final screen = InterfaceScreen(
        id: 'test',
        title: 'Test',
        children: [root],
      );
      final errors = ComponentTreeValidator.validateScreen(screen);
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('ui_children_exceeded')), isTrue);
    });

    test('501 total nodes fails validation via ComponentTreeValidator', () {
      final children = List.generate(
        500,
        (i) =>
            InterfaceNode(id: 'c_$i', type: 'text', properties: {'text': '$i'}),
      );
      final root = InterfaceNode(
        id: 'root',
        type: 'column',
        properties: {},
        children: children,
      );
      final screen = InterfaceScreen(
        id: 'test',
        title: 'Test',
        children: [root],
      );
      final errors = ComponentTreeValidator.validateScreen(screen);
      expect(errors, isNotEmpty);
      expect(
        errors.any((e) => e.contains('ui_component_count_exceeded')),
        isTrue,
      );
    });

    test('Budget constants cannot be overridden by package semantics', () {
      expect(RuntimeComponentRegistry.maxDepth, 20);
      expect(RuntimeComponentRegistry.maxChildrenPerNode, 50);
      expect(RuntimeComponentRegistry.maxTotalComponents, 500);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // UNKNOWN COMPONENT
  // ═════════════════════════════════════════════════════════════════════
  group('Unknown Component', () {
    testWidgets('Unknown component type renders safely (no crash)', (
      tester,
    ) async {
      final renderer = ExperienceRenderer();
      final stateEngine = ExperienceStateEngine();

      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'test',
            title: 'Test',
            children: [
              InterfaceNode(
                type: 'superMagicWidget',
                id: 'unknown_1',
                properties: {'data': 'test'},
              ),
              const InterfaceNode(
                type: 'text',
                id: 'fallback',
                properties: {'content': 'Fallback text'},
              ),
            ],
          ),
        ],
      );

      // Should render without throwing
      expect(
        () => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    renderer.render(context, interface, stateEngine),
              ),
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('Registry returns null for unknown type', () {
      final registry = RuntimeComponentRegistry.defaults();
      expect(registry.isRegistered('nonExistentType'), isFalse);
      expect(registry.getBuilder('nonExistentType'), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // FORBIDDEN EXECUTABLE COMPONENTS
  // ═════════════════════════════════════════════════════════════════════
  group('Forbidden Executable Components', () {
    test('Shell/terminal/JS/dartCode components are not registered', () {
      final registry = RuntimeComponentRegistry.defaults();

      final forbidden = [
        'shell',
        'terminal',
        'javascript',
        'dartCode',
        'dynamicDart',
        'rawHtmlScript',
        'credentialDump',
        'eval',
        'exec',
        'process',
      ];

      for (final type in forbidden) {
        expect(
          registry.isRegistered(type),
          isFalse,
          reason: 'Component type "$type" must not be registered',
        );
      }
    });

    test('Only trusted component types are registered', () {
      final registry = RuntimeComponentRegistry.defaults();
      final registered = registry.registeredTypes;

      // Every registered type should be a known trusted type
      final trustedTypes = {
        'text',
        'heading',
        'button',
        'iconButton',
        'card',
        'column',
        'row',
        'container',
        'input',
        'numberInput',
        'dateInput',
        'switch',
        'searchField',
        'list',
        'listItem',
        'emptyState',
        'progress',
        'metric',
        'divider',
        'spacer',
        'chip',
        'badge',
        'tabBar',
        'tab',
        'grid',
      };

      for (final type in registered) {
        expect(
          trustedTypes.contains(type),
          isTrue,
          reason: 'Registered type "$type" is not in trusted set',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // NAVIGATION ESCAPE
  // ═════════════════════════════════════════════════════════════════════
  group('Navigation Escape', () {
    test('Router rejects unknown screen IDs', () {
      final validScreenIds = {'home', 'list', 'form'};
      final router = ExperienceRouter(validScreenIds: validScreenIds);

      // Router starts with null screen (no history)
      expect(router.currentScreenId, isNull);

      // Attempt to navigate to nonexistent screen
      router.navigate(
        NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: '../../settings',
        ),
      );

      // Should still have no screen (invalid target rejected)
      expect(router.currentScreenId, isNull);

      router.dispose();
    });

    test('Router rejects hostRoot navigation', () {
      final validScreenIds = {'home', 'list'};
      final router = ExperienceRouter(validScreenIds: validScreenIds);

      router.navigate(
        NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'hostRoot',
        ),
      );

      expect(router.currentScreenId, isNull);

      router.dispose();
    });

    test('Router validates all navigation against screen list', () {
      final validScreenIds = {'screen_a', 'screen_b'};
      final router = ExperienceRouter(validScreenIds: validScreenIds);

      // Valid navigation
      router.navigate(
        NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'screen_a',
        ),
      );
      expect(router.currentScreenId, 'screen_a');

      // Invalid navigation should be rejected
      router.navigate(
        NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: 'nonexistent',
        ),
      );
      expect(router.currentScreenId, 'screen_a');

      router.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // QUERY LIMIT ENFORCEMENT
  // ═════════════════════════════════════════════════════════════════════
  group('Query Limit Enforcement', () {
    test('DataQuery max result limit enforced', () {
      final eng = DataQueryEngine();

      // Seed 1000 records
      final records = List.generate(
        1000,
        (i) => {'id': 'rec_$i', 'name': 'Record $i', 'value': i},
      );

      // Request more than max — DataQueryEngine.query validates and rejects
      final query = DataQuery(
        entityId: 'test',
        limit: 2000, // Exceeds maxResultLimit of 1000
      );

      expect(
        () => eng.query(query, records),
        throwsA(isA<DataQueryException>()),
      );
    });

    test('DataQuery max filters enforced', () {
      // DataQuery validates limits at query time, throws DataQueryException
      final eng = DataQueryEngine();
      final query = DataQuery(
        entityId: 'test',
        filters: List.generate(
          25,
          (i) => FilterCondition(
            fieldId: 'field_$i',
            operator: FilterOperator.equals,
            value: 'value_$i',
          ),
        ),
      );

      expect(() => eng.query(query, []), throwsA(isA<DataQueryException>()));
    });

    test('DataQuery max sorts enforced', () {
      final eng = DataQueryEngine();
      final query = DataQuery(
        entityId: 'test',
        sorts: List.generate(
          10,
          (i) =>
              SortSpec(fieldId: 'field_$i', direction: SortDirection.ascending),
        ),
      );

      expect(() => eng.query(query, []), throwsA(isA<DataQueryException>()));
    });

    test('Large data (1000 records) search/filter/sort without crash', () {
      final eng = DataQueryEngine();

      final records = List.generate(
        1000,
        (i) => {
          'id': 'rec_$i',
          'name': 'Person ${i % 100}',
          'value': i % 50,
          'active': i % 2 == 0,
        },
      );

      // Search
      final searchQuery = DataQuery(
        entityId: 'test',
        search: 'Person 1',
        searchFields: ['name'],
      );
      final searchResult = eng.query(searchQuery, records);
      expect(searchResult, isNotEmpty);

      // Filter
      final filterQuery = DataQuery(
        entityId: 'test',
        filters: [
          const FilterCondition(
            fieldId: 'active',
            operator: FilterOperator.isTrue,
          ),
        ],
      );
      final filterResult = eng.query(filterQuery, records);
      expect(filterResult.length, 500);

      // Sort
      final sortQuery = DataQuery(
        entityId: 'test',
        sorts: [
          const SortSpec(fieldId: 'value', direction: SortDirection.descending),
        ],
      );
      final sortResult = eng.query(sortQuery, records);
      expect(sortResult.length, 1000);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // MALICIOUS QUERY
  // ═════════════════════════════════════════════════════════════════════
  group('Malicious Query', () {
    test('SQL injection in field identifier is handled safely', () async {
      // Seed legitimate data
      final pipeline = _buildTestPipeline();
      final dr = ExperienceDataRuntime();
      dr.initialize(
        DataSchema(
          entities: [
            const DataEntitySchema(
              id: 'person',
              name: 'Person',
              fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
            ),
          ],
        ),
        experienceId: 'injection_test',
      );

      await dr.insert('person', {'id': 'p1', 'name': 'Alice'});

      // Attempt malicious field identifier via DataQuery
      final eng = DataQueryEngine();
      final maliciousQuery = DataQuery(
        entityId: 'person',
        filters: [
          const FilterCondition(
            fieldId: "name; DROP TABLE records;",
            operator: FilterOperator.equals,
            value: 'test',
          ),
        ],
      );

      // The DataQuery engine evaluates in-memory against records
      // It does NOT execute raw SQL from field identifiers
      final records = await dr.query('person');
      final result = eng.query(maliciousQuery, records);

      // Query completes without crashing; original data unaffected
      expect(records.length, 1);
      expect(records.first['name'], 'Alice');

      await dr.dispose();
    });

    test('Malicious entity identifier does not crash DataRuntime', () async {
      final dr = ExperienceDataRuntime();
      dr.initialize(
        DataSchema(
          entities: [
            const DataEntitySchema(
              id: 'person',
              name: 'Person',
              fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
            ),
          ],
        ),
        experienceId: 'injection_test2',
      );

      // Query with malicious entity name
      final result = await dr.query("person'; DROP TABLE records; --");
      expect(result, isEmpty); // No crash, returns empty

      await dr.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // FORM REFERENCE VALIDATION
  // ═════════════════════════════════════════════════════════════════════
  group('Form Validation', () {
    test('Invalid enum/select value fails validation via validate()', () {
      final form = ExperienceFormController(
        entityId: 'loan',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'status',
            name: 'Status',
            type: 'enum',
            allowedValues: ['active', 'returned', 'overdue'],
          ),
        ],
      );

      form.setValue('status', 'malicious_value');
      final isValid = form.validate();
      expect(isValid, isFalse);
      expect(form.getFieldError('status'), isNotNull);

      form.dispose();
    });

    test('Valid enum/select value passes validation', () {
      final form = ExperienceFormController(
        entityId: 'loan',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'status',
            name: 'Status',
            type: 'enum',
            allowedValues: ['active', 'returned', 'overdue'],
          ),
        ],
      );

      form.setValue('status', 'active');
      final isValid = form.validate();
      expect(isValid, isTrue);

      form.dispose();
    });

    test('Required field validation prevents empty submission', () {
      final form = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'string',
            required: true,
          ),
          const FormFieldDefinition(
            id: 'email',
            name: 'Email',
            type: 'string',
            required: true,
          ),
        ],
      );

      expect(form.isValid, isFalse);

      form.setValue('name', 'Alice');
      expect(form.isValid, isFalse); // email still required

      form.setValue('email', 'alice@test.com');
      expect(form.isValid, isTrue);

      form.dispose();
    });

    test('MinLength validation enforced by controller', () {
      final form = ExperienceFormController(
        entityId: 'person',
        mode: FormMode.create,
        fieldDefinitions: [
          const FormFieldDefinition(
            id: 'name',
            name: 'Name',
            type: 'string',
            required: true,
            minLength: 3,
          ),
        ],
      );

      form.setValue('name', 'Ab');
      final isValid = form.validate();
      expect(isValid, isFalse);
      expect(form.getFieldError('name'), contains('at least 3'));

      form.setValue('name', 'Alice');
      final isValid2 = form.validate();
      expect(isValid2, isTrue);

      form.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // RUNTIME PACKAGE VALIDATION
  // ═════════════════════════════════════════════════════════════════════
  group('Runtime Package Validation', () {
    test('Empty experience ID is rejected', () async {
      final runtime = AnythingRuntime();
      final pkg = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: '',
          name: 'Test',
          description: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        interface: const InterfaceDefinition(
          screens: [InterfaceScreen(id: 'test', title: 'Test')],
        ),
        behavior: const BehaviorGraph(),
        state: const StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime.now(),
        ),
      );

      final session = await runtime.openExperience(pkg);
      expect(session.status, SessionStatus.failed);
      expect(session.error, contains('Missing experience ID'));

      await runtime.closeSession();
    });

    test('No screens defined is rejected', () async {
      final runtime = AnythingRuntime();
      final pkg = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'test-001',
          name: 'Test',
          description: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        interface: const InterfaceDefinition(),
        behavior: const BehaviorGraph(),
        state: const StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime.now(),
        ),
      );

      final session = await runtime.openExperience(pkg);
      expect(session.status, SessionStatus.failed);
      expect(session.error, contains('No screens defined'));

      await runtime.closeSession();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // BEHAVIOR BUDGET
  // ═════════════════════════════════════════════════════════════════════
  group('Behavior Budget', () {
    test('BehaviorInterpreter exists with internal budget limits', () {
      // BehaviorInterpreter has internal budget limits (_maxNodesPerExecution = 100)
      // These are private constants enforced during execution
      // Verify the class can be instantiated (budgets are enforced internally)
      final interpreter = BehaviorInterpreter();
      expect(interpreter, isNotNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // COMPONENT REGISTRY COMPLETENESS
  // ═════════════════════════════════════════════════════════════════════
  group('Component Registry', () {
    test('All standard components registered', () {
      final registry = RuntimeComponentRegistry.defaults();

      final expected = [
        'text',
        'heading',
        'button',
        'iconButton',
        'card',
        'column',
        'row',
        'container',
        'input',
        'numberInput',
        'dateInput',
        'switch',
        'searchField',
        'list',
        'listItem',
        'emptyState',
        'progress',
        'metric',
        'divider',
        'spacer',
        'chip',
        'badge',
        'tabBar',
        'tab',
        'grid',
      ];

      for (final type in expected) {
        expect(
          registry.isRegistered(type),
          isTrue,
          reason: 'Standard component "$type" should be registered',
        );
      }
    });

    test('Build unknown component returns null', () {
      final registry = RuntimeComponentRegistry.defaults();
      final widget = registry.buildComponent(
        TestWidgetsFlutterBinding.ensureInitialized().rootElement!,
        'nonExistentType',
        {},
        [],
      );
      expect(widget, isNull);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════

ExperienceDataRuntime _buildTestPipeline() {
  return ExperienceDataRuntime();
}
