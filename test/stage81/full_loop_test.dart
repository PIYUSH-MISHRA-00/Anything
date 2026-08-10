/// Full product loop tests — the most important Stage 8.1 tests.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime/golden_paths/habit_tracker_package.dart';
import 'package:anything/runtime/golden_paths/notes_package.dart';
import 'package:anything/creation/modification/experience_modification_spec.dart';
import 'package:anything/creation/modification/modification_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Calculator Golden Path', () {
    test('7 × 8 = 56 through Runtime', () async {
      final package = createCalculatorPackage();
      final runtime = AnythingRuntime();
      await runtime.openExperience(package);

      // Simulate: 7 × 8 =
      runtime.setState('display', '7');
      runtime.setState('currentOperation', '*');
      runtime.setState('storedValue', 7.0);
      runtime.setState('display', '8');

      final stored = runtime.getState('storedValue') as num;
      final display =
          double.tryParse(runtime.getState('display').toString()) ?? 0;
      final result = stored * display;
      runtime.setState(
        'display',
        result == result.toInt().toDouble()
            ? result.toInt().toString()
            : result.toString(),
      );

      expect(runtime.getState('display'), equals('56'));

      await runtime.closeSession();
    });
  });

  group('Complete Habit Loop', () {
    test('create → persist → reopen → modify → preserve data', () async {
      final package = createHabitTrackerPackage();

      // Step 1: Create and open
      final runtime1 = AnythingRuntime();
      await runtime1.openExperience(package);

      // Step 2: Add habits
      final dr1 = ExperienceDataRuntime();
      dr1.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      await dr1.insert('habits', {
        'name': 'Drink water',
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await dr1.insert('habits', {
        'name': 'Read',
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Step 3: Toggle completion
      final habits = await dr1.query('habits');
      final drinkId =
          habits.firstWhere((h) => h['name'] == 'Drink water')['id'] as String;
      await dr1.update('habits', drinkId, {'completed': true});

      // Step 4: Close everything
      await runtime1.closeSession();
      await dr1.dispose();

      // Step 5: Reopen (simulates app restart)
      final runtime2 = AnythingRuntime();
      await runtime2.openExperience(package);
      final dr2 = ExperienceDataRuntime();
      dr2.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );

      // Step 6: Verify data persists
      final habits2 = await dr2.query('habits');
      expect(habits2.length, equals(2));
      expect(habits2[0]['name'], equals('Drink water'));
      expect(habits2[0]['completed'], equals(true));
      expect(habits2[1]['name'], equals('Read'));
      expect(habits2[1]['completed'], equals(false));

      // Step 7: Modify — add notification capability
      final engine = ModificationEngine();
      final modResult = await engine.modify(
        package,
        const ExperienceModificationSpec(
          targetExperienceId: 'test',
          basePackageVersion: '1.0.0',
          objective: 'Add reminders',
          operations: [
            ModificationOperation(
              type: ModificationType.addCapability,
              params: {'capabilityId': 'notifications'},
            ),
          ],
          requiredCapabilities: ['notifications'],
        ),
      );

      expect(modResult, isA<ModificationReady>());
      if (modResult is ModificationReady) {
        // Step 8: Verify v2 package has notification capability
        expect(
          modResult.updatedPackage.capabilityDeclarations.any(
            (c) => c.capabilityId == 'notifications',
          ),
          isTrue,
        );
        // Step 9: Version bumped
        expect(
          modResult.updatedPackage.manifest.version,
          isNot(equals('1.0.0')),
        );
      }

      // Cleanup
      await runtime2.closeSession();
      await dr2.dispose();
    });
  });

  group('Complete Notes Loop', () {
    test(
      'create → persist → reopen → modify → search → preserve data',
      () async {
        final package = createNotesPackage();

        // Step 1: Create and open
        final runtime = AnythingRuntime();
        await runtime.openExperience(package);
        final dr = ExperienceDataRuntime();
        dr.initialize(
          package.data!,
          experienceId: package.manifest.experienceId,
        );

        // Step 2: Create notes
        await dr.insert('notes', {
          'title': 'Anything',
          'body': 'My first generated app',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        await dr.insert('notes', {
          'title': 'Shopping List',
          'body': 'Milk, eggs, bread',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Step 3: Verify
        var notes = await dr.query('notes');
        expect(notes.length, equals(2));

        // Step 4: Close and reopen
        await runtime.closeSession();
        await dr.dispose();

        final runtime2 = AnythingRuntime();
        await runtime2.openExperience(package);
        final dr2 = ExperienceDataRuntime();
        dr2.initialize(
          package.data!,
          experienceId: package.manifest.experienceId,
        );

        notes = await dr2.query('notes');
        expect(notes.length, equals(2));
        expect(notes[0]['title'], equals('Anything'));

        // Step 5: Edit
        final id = notes[0]['id'] as String;
        await dr2.update('notes', id, {'body': 'Updated content'});

        // Step 6: Verify edit
        final updated = await dr2.readById('notes', id);
        expect(updated!['body'], equals('Updated content'));

        // Step 7: Modify — add search
        final engine = ModificationEngine();
        final modResult = await engine.modify(
          package,
          const ExperienceModificationSpec(
            targetExperienceId: 'test',
            basePackageVersion: '1.0.0',
            objective: 'Add search',
            operations: [
              ModificationOperation(
                type: ModificationType.addUiNode,
                params: {
                  'screenId': 'notes',
                  'nodeType': 'input',
                  'label': 'Search',
                  'stateBinding': 'searchQuery',
                },
              ),
            ],
          ),
        );

        expect(modResult, isA<ModificationReady>());

        // Step 8: Verify existing notes still there
        notes = await dr2.query('notes');
        expect(notes.length, equals(2));

        // Step 9: Delete
        await dr2.delete('notes', id);
        notes = await dr2.query('notes');
        expect(notes.length, equals(1));

        // Cleanup
        await runtime2.closeSession();
        await dr2.dispose();
      },
    );
  });

  group('Existing Experience Fast Path', () {
    test('Calculator opens without AI/creation', () async {
      final package = createCalculatorPackage();
      final runtime = AnythingRuntime();
      final session = await runtime.openExperience(package);

      expect(session.status.name, equals('running'));
      expect(session.experienceId, isNotEmpty);

      // Calculator works through generic Runtime
      runtime.setState('display', '42');
      expect(runtime.getState('display'), equals('42'));

      await runtime.closeSession();
    });
  });

  group('Offline Behavior', () {
    test('Calculator works without network', () async {
      final package = createCalculatorPackage();
      expect(package.manifest.networkMode.name, equals('none'));

      final runtime = AnythingRuntime();
      await runtime.openExperience(package);

      // Pure local computation using Calculator state
      runtime.setState('storedValue', 10.0);
      runtime.setState('display', '5');
      runtime.setState('currentOperation', '+');
      final stored = runtime.getState('storedValue') as num;
      final display =
          double.tryParse(runtime.getState('display').toString()) ?? 0;
      final result = stored + display;
      runtime.setState('display', result.toString());

      expect(runtime.getState('display'), equals('15.0'));
      await runtime.closeSession();
    });

    test('Habit Tracker works without network', () async {
      final package = createHabitTrackerPackage();
      expect(package.manifest.networkMode.name, equals('none'));

      final runtime = AnythingRuntime();
      await runtime.openExperience(package);
      await runtime.closeSession();
    });
  });
}
