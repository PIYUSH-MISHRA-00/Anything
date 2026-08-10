/// Tests for Experience Modification Engine.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/creation/modification/experience_modification_spec.dart';
import 'package:anything/creation/modification/modification_engine.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/runtime/golden_paths/habit_tracker_package.dart';
import 'package:anything/runtime/golden_paths/notes_package.dart';

void main() {
  group('ModificationEngine', () {
    test('Calculator modification adds UI node', () async {
      final calculator = createCalculatorPackage();
      final spec = ExperienceModificationSpec(
        targetExperienceId: calculator.manifest.experienceId,
        basePackageVersion: calculator.manifest.version,
        objective: 'Add percentage button',
        operations: [
          const ModificationOperation(
            type: ModificationType.addUiNode,
            params: {
              'screenId': 'calculator',
              'nodeType': 'button',
              'label': '%',
              'actionId': 'percentagePressed',
            },
          ),
        ],
      );

      final engine = ModificationEngine();
      final result = await engine.modify(calculator, spec);

      expect(result, isA<ModificationReady>());
      if (result is ModificationReady) {
        // Version bumped
        expect(
          result.updatedPackage.manifest.version,
          isNot(equals(calculator.manifest.version)),
        );
        // New node exists in interface
        final screens = result.updatedPackage.interface.screens;
        expect(screens, isNotEmpty);
        final calcScreen = screens.firstWhere((s) => s.id == 'calculator');
        final percentNode = calcScreen.children
            .where((n) => n.properties['label'] == '%')
            .toList();
        expect(percentNode, isNotEmpty);
      }
    });

    test('Calculator modification adds behavior node', () async {
      final calculator = createCalculatorPackage();
      final spec = ExperienceModificationSpec(
        targetExperienceId: calculator.manifest.experienceId,
        basePackageVersion: calculator.manifest.version,
        objective: 'Add percentage behavior',
        operations: [
          const ModificationOperation(
            type: ModificationType.addBehavior,
            params: {
              'nodeType': 'event',
              'config': {'description': 'percentage pressed'},
            },
          ),
        ],
      );

      final engine = ModificationEngine();
      final result = await engine.modify(calculator, spec);

      expect(result, isA<ModificationReady>());
      if (result is ModificationReady) {
        expect(
          result.updatedPackage.behavior.nodes.length,
          greaterThan(calculator.behavior.nodes.length),
        );
      }
    });

    test('Notes modification adds search UI', () async {
      final notes = createNotesPackage();
      final spec = ExperienceModificationSpec(
        targetExperienceId: notes.manifest.experienceId,
        basePackageVersion: notes.manifest.version,
        objective: 'Add search',
        operations: [
          const ModificationOperation(
            type: ModificationType.addUiNode,
            params: {
              'screenId': 'notes',
              'nodeType': 'input',
              'label': 'Search',
              'stateBinding': 'searchQuery',
            },
          ),
        ],
      );

      final engine = ModificationEngine();
      final result = await engine.modify(notes, spec);

      expect(result, isA<ModificationReady>());
      if (result is ModificationReady) {
        final notesScreen = result.updatedPackage.interface.screens.firstWhere(
          (s) => s.id == 'notes',
        );
        final searchNodes = notesScreen.children
            .where((n) => n.stateBinding == 'searchQuery')
            .toList();
        expect(searchNodes, isNotEmpty);
      }
    });

    test('Notes schema modification adds tags field', () async {
      final notes = createNotesPackage();
      final spec = ExperienceModificationSpec(
        targetExperienceId: notes.manifest.experienceId,
        basePackageVersion: notes.manifest.version,
        objective: 'Add tags to notes',
        operations: [
          const ModificationOperation(
            type: ModificationType.addEntity,
            params: {
              'name': 'note_tags',
              'fields': [
                {'name': 'noteId', 'type': 'string', 'required': true},
                {'name': 'tag', 'type': 'string', 'required': true},
              ],
            },
          ),
        ],
      );

      final engine = ModificationEngine();
      final result = await engine.modify(notes, spec);

      expect(result, isA<ModificationReady>());
      if (result is ModificationReady) {
        expect(result.updatedPackage.data, isNotNull);
        expect(
          result.updatedPackage.data!.entities.length,
          greaterThan(notes.data!.entities.length),
        );
        // Schema version incremented
        expect(
          result.updatedPackage.data!.schemaVersion,
          greaterThan(notes.data!.schemaVersion),
        );
      }
    });

    test('modification preserves existing data', () async {
      final habit = createHabitTrackerPackage();
      final originalEntities = habit.data?.entities.length ?? 0;

      final spec = ExperienceModificationSpec(
        targetExperienceId: habit.manifest.experienceId,
        basePackageVersion: habit.manifest.version,
        objective: 'Add reminder',
        operations: [
          const ModificationOperation(
            type: ModificationType.addCapability,
            params: {'capabilityId': 'notifications'},
          ),
        ],
        requiredCapabilities: ['notifications'],
      );

      final engine = ModificationEngine();
      final result = await engine.modify(habit, spec);

      expect(result, isA<ModificationReady>());
      if (result is ModificationReady) {
        // Existing data entities preserved
        expect(
          result.updatedPackage.data?.entities.length,
          equals(originalEntities),
        );
        // New capability added
        expect(
          result.updatedPackage.capabilityDeclarations.any(
            (c) => c.capabilityId == 'notifications',
          ),
          isTrue,
        );
      }
    });
  });
}
