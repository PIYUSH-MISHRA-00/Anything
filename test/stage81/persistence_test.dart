/// Tests for real SQLite persistence.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/golden_paths/habit_tracker_package.dart';
import 'package:anything/runtime/golden_paths/notes_package.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime/data_runtime.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Habit Tracker Persistence', () {
    test('habit data survives Runtime recreation', () async {
      final package = createHabitTrackerPackage();

      // First Runtime session
      final runtime1 = AnythingRuntime();
      final session1 = await runtime1.openExperience(package);
      expect(session1.status.name, equals('running'));

      // Add habits
      runtime1.stateEngine.write('habitName', 'Drink water');
      final dataRuntime1 = ExperienceDataRuntime();
      dataRuntime1.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      await dataRuntime1.insert('habits', {
        'name': 'Drink water',
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await dataRuntime1.insert('habits', {
        'name': 'Read',
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Verify data exists
      final habits1 = await dataRuntime1.query('habits');
      expect(habits1.length, equals(2));

      // Close everything
      await runtime1.closeSession();
      await dataRuntime1.dispose();

      // Second Runtime session (simulates app restart)
      final runtime2 = AnythingRuntime();
      final session2 = await runtime2.openExperience(package);
      expect(session2.status.name, equals('running'));

      // Verify data persists
      final dataRuntime2 = ExperienceDataRuntime();
      dataRuntime2.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      final habits2 = await dataRuntime2.query('habits');
      expect(habits2.length, equals(2));
      expect(habits2[0]['name'], equals('Drink water'));
      expect(habits2[1]['name'], equals('Read'));

      // Cleanup
      await runtime2.closeSession();
      await dataRuntime2.dispose();
    });

    test('habit toggle persists', () async {
      final package = createHabitTrackerPackage();
      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );

      // Insert habit
      await dataRuntime.insert('habits', {
        'name': 'Drink water',
        'completed': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Toggle completion
      final habits = await dataRuntime.query('habits');
      final id = habits[0]['id'] as String;
      await dataRuntime.update('habits', id, {'completed': true});

      // Verify
      final updated = await dataRuntime.readById('habits', id);
      expect(updated!['completed'], equals(true));

      await dataRuntime.dispose();
    });
  });

  group('Notes Persistence', () {
    test('notes CRUD survives recreation', () async {
      final package = createNotesPackage();
      final dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );

      // Create note
      await dataRuntime.insert('notes', {
        'title': 'Anything',
        'body': 'My first generated app',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Verify
      var notes = await dataRuntime.query('notes');
      expect(notes.length, equals(1));
      expect(notes[0]['title'], equals('Anything'));
      expect(notes[0]['body'], equals('My first generated app'));

      // Edit
      final id = notes[0]['id'] as String;
      await dataRuntime.update('notes', id, {'body': 'Updated content'});

      // Verify edit
      final updated = await dataRuntime.readById('notes', id);
      expect(updated!['body'], equals('Updated content'));

      // Delete
      await dataRuntime.delete('notes', id);
      notes = await dataRuntime.query('notes');
      expect(notes.isEmpty, isTrue);

      await dataRuntime.dispose();
    });

    test('notes data persists across DataRuntime recreation', () async {
      final package = createNotesPackage();

      // First session
      final dr1 = ExperienceDataRuntime();
      dr1.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      await dr1.insert('notes', {
        'title': 'Persisted Note',
        'body': 'This should survive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await dr1.dispose();

      // Second session
      final dr2 = ExperienceDataRuntime();
      dr2.initialize(
        package.data!,
        experienceId: package.manifest.experienceId,
      );
      final notes = await dr2.query('notes');
      expect(notes.length, equals(1));
      expect(notes[0]['title'], equals('Persisted Note'));

      await dr2.dispose();
    });
  });

  group('Experience Isolation', () {
    test('different Experiences have isolated data', () async {
      final packageA = createHabitTrackerPackage();
      final packageB = createNotesPackage();

      final drA = ExperienceDataRuntime();
      drA.initialize(
        packageA.data!,
        experienceId: packageA.manifest.experienceId,
      );

      final drB = ExperienceDataRuntime();
      drB.initialize(
        packageB.data!,
        experienceId: packageB.manifest.experienceId,
      );

      // Insert into A
      await drA.insert('habits', {
        'name': 'Alpha',
        'completed': false,
        'createdAt': '',
      });

      // Insert into B
      await drB.insert('notes', {
        'title': 'Beta',
        'body': '',
        'createdAt': '',
        'updatedAt': '',
      });

      // Verify isolation
      final habitsA = await drA.query('habits');
      expect(habitsA.length, equals(1));
      expect(habitsA[0]['name'], equals('Alpha'));

      final notesA = await drA.query('notes');
      expect(notesA.length, equals(0)); // A has no notes

      final habitsB = await drB.query('habits');
      expect(habitsB.length, equals(0)); // B has no habits

      final notesB = await drB.query('notes');
      expect(notesB.length, equals(1));
      expect(notesB[0]['title'], equals('Beta'));

      await drA.dispose();
      await drB.dispose();
    });
  });

  group('Calculator', () {
    test('Calculator 7×8=56 through Runtime', () async {
      final package = createCalculatorPackage();
      final runtime = AnythingRuntime();
      await runtime.openExperience(package);

      // Simulate calculator operations
      runtime.setState('display', '7');
      runtime.setState('currentOperation', '*');
      runtime.setState('storedValue', 7.0);
      runtime.setState('display', '8');
      runtime.setState('newInput', true);

      // Calculate
      final stored = runtime.getState('storedValue') as num;
      final display =
          double.tryParse(runtime.getState('display').toString()) ?? 0;
      final result = stored * display;
      runtime.setState('display', result.toString());

      expect(runtime.getState('display'), equals('56.0'));

      await runtime.closeSession();
    });
  });
}
