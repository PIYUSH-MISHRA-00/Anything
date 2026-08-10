/// Tests for Anything Runtime.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime/golden_paths/calculator_runtime.dart';
import 'package:anything/creation/experience_package.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AnythingRuntime', () {
    test('opens Calculator package', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      final session = await runtime.openExperience(package);

      expect(session.status, equals(SessionStatus.running));
      expect(session.experienceId, isNotEmpty);
      expect(runtime.status, equals(RuntimeStatus.running));
    });

    test('Calculator renders without crashing', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      await runtime.openExperience(package);

      // Verify state initialized
      expect(runtime.getState('display'), equals('0'));
      expect(runtime.getState('expression'), equals(''));
      expect(runtime.getState('currentValue'), equals(0.0));
      expect(runtime.getState('storedValue'), equals(0.0));

      await runtime.closeSession();
    });

    test('Calculator 7 × 8 = 56', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      await runtime.openExperience(package);

      final calc = CalculatorRuntime(runtime);

      // Press 7
      calc.onNumberPressed(7);
      expect(calc.display, equals('7'));

      // Press ×
      calc.onOperationPressed('*');
      expect(calc.display, equals('7'));

      // Press 8
      calc.onNumberPressed(8);
      expect(calc.display, equals('8'));

      // Press =
      calc.onEqualsPressed();
      expect(calc.display, equals('56'));

      await runtime.closeSession();
    });

    test('Calculator 9 ÷ 3 = 3', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      await runtime.openExperience(package);

      final calc = CalculatorRuntime(runtime);

      calc.onNumberPressed(9);
      calc.onOperationPressed('/');
      calc.onNumberPressed(3);
      calc.onEqualsPressed();

      expect(calc.display, equals('3'));
      await runtime.closeSession();
    });

    test('Calculator clear resets state', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      await runtime.openExperience(package);

      final calc = CalculatorRuntime(runtime);

      calc.onNumberPressed(5);
      calc.onOperationPressed('+');
      calc.onNumberPressed(3);
      calc.onClearPressed();

      expect(calc.display, equals('0'));
      expect(calc.expression, equals(''));
      await runtime.closeSession();
    });

    test('Calculator division by zero', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      await runtime.openExperience(package);

      final calc = CalculatorRuntime(runtime);

      calc.onNumberPressed(5);
      calc.onOperationPressed('/');
      calc.onNumberPressed(0);
      calc.onEqualsPressed();

      expect(calc.display, equals('Error'));
      await runtime.closeSession();
    });

    test('close session cleans up', () async {
      final runtime = AnythingRuntime();
      final package = createCalculatorPackage();
      await runtime.openExperience(package);

      await runtime.closeSession();
      expect(runtime.status, equals(RuntimeStatus.idle));
      expect(runtime.currentSession, isNull);
    });
  });

  group('ExperienceStateEngine', () {
    test('initialize sets defaults', () {
      final engine = ExperienceStateEngine();
      engine.initialize(
        const StateSchema(
          variables: [
            StateVariable(id: 'x', type: 'integer', defaultValue: 0),
            StateVariable(id: 'name', type: 'string', defaultValue: 'default'),
          ],
        ),
      );

      expect(engine.read('x'), equals(0));
      expect(engine.read('name'), equals('default'));
    });

    test('write validates type', () {
      final engine = ExperienceStateEngine();
      engine.initialize(
        const StateSchema(
          variables: [StateVariable(id: 'count', type: 'integer')],
        ),
      );

      engine.write('count', 42);
      expect(engine.read('count'), equals(42));

      // Invalid type should be rejected
      engine.write('count', 'not a number');
      expect(engine.read('count'), equals(42)); // unchanged
    });

    test('watch notifies on changes', () async {
      final engine = ExperienceStateEngine();
      engine.initialize(
        const StateSchema(
          variables: [StateVariable(id: 'value', type: 'string')],
        ),
      );

      final values = <dynamic>[];
      engine.watch('value').listen(values.add);

      engine.write('value', 'first');
      await Future.delayed(Duration.zero);
      engine.write('value', 'second');
      await Future.delayed(Duration.zero);

      expect(values, equals(['first', 'second']));
    });

    test('persistent state filtering', () {
      final engine = ExperienceStateEngine();
      engine.initialize(
        const StateSchema(
          variables: [
            StateVariable(
              id: 'session_only',
              type: 'string',
              persistence: 'session',
            ),
            StateVariable(
              id: 'persistent',
              type: 'string',
              persistence: 'persistent',
            ),
          ],
        ),
      );

      engine.write('session_only', 'temp');
      engine.write('persistent', 'saved');

      final persistent = engine.getPersistentState();
      expect(persistent, equals({'persistent': 'saved'}));
    });
  });

  group('ExperienceDataRuntime', () {
    test('CRUD operations', () async {
      final runtime = ExperienceDataRuntime();
      runtime.initialize(
        const DataSchema(
          entities: [DataEntitySchema(id: 'e_test', name: 'notes')],
        ),
        experienceId: 'test-experience-1',
      );

      // Insert
      await runtime.insert('notes', {
        'title': 'First note',
        'content': 'Hello',
      });
      expect(await runtime.count('notes'), equals(1));

      // Query
      final notes = await runtime.query('notes');
      expect(notes, hasLength(1));
      expect(notes[0]['title'], equals('First note'));

      // Read by ID
      final id = notes[0]['id'] as String;
      final note = await runtime.readById('notes', id);
      expect(note, isNotNull);
      expect(note!['title'], equals('First note'));

      // Update
      await runtime.update('notes', id, {'title': 'Updated note'});
      final updated = await runtime.readById('notes', id);
      expect(updated!['title'], equals('Updated note'));

      // Delete
      await runtime.delete('notes', id);
      expect(await runtime.count('notes'), equals(0));
    });

    test('unknown entity returns empty', () async {
      final runtime = ExperienceDataRuntime();
      runtime.initialize(const DataSchema());

      final results = await runtime.query('nonexistent');
      expect(results, isEmpty);
    });
  });

  group('ExperienceServiceResolver', () {
    test('resolves known services', () {
      final resolver = ExperienceServiceResolver();
      resolver.resolve([
        const ServiceDefinition(id: 'clock1', type: 'clock'),
        const ServiceDefinition(id: 'unknown1', type: 'nonexistent'),
      ]);

      expect(resolver.isAvailable('clock1'), isTrue);
      expect(resolver.isAvailable('unknown1'), isFalse);
    });

    test('clock service returns time', () async {
      final resolver = ExperienceServiceResolver();
      resolver.resolve([const ServiceDefinition(id: 'clock1', type: 'clock')]);

      final result = await resolver.execute('clock1', 'now', {});
      expect(result.containsKey('timestamp'), isTrue);
    });
  });
}
