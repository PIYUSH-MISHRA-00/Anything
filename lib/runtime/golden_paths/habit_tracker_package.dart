/// Habit Tracker ExperiencePackage fixture.
library;

import 'package:uuid/uuid.dart';

import '../../creation/experience_package.dart';

ExperiencePackage createHabitTrackerPackage() {
  final id = 'exp-habit-${const Uuid().v4()}';
  final now = DateTime.now();

  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: id,
      name: 'Habit Tracker',
      description: 'Track your daily habits',
      version: '1.0.0',
      createdAt: now,
      updatedAt: now,
      networkMode: NetworkMode.none,
      storageMode: StorageMode.localDatabase,
    ),
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'habits',
          title: 'Habit Tracker',
          appBarTitle: 'Habits',
          children: [
            InterfaceNode(type: 'column', id: 'habitList', children: []),
          ],
        ),
      ],
    ),
    behavior: BehaviorGraph(
      nodes: [
        const BehaviorNode(
          id: 'addHabit',
          type: 'event',
          config: {'description': 'Add a new habit'},
        ),
        const BehaviorNode(
          id: 'toggleHabit',
          type: 'event',
          config: {'description': 'Toggle habit completion'},
        ),
        const BehaviorNode(
          id: 'deleteHabit',
          type: 'event',
          config: {'description': 'Delete a habit'},
        ),
        const BehaviorNode(
          id: 'insertHabit',
          type: 'dataMutation',
          config: {'operation': 'insert', 'entity': 'habits'},
        ),
        const BehaviorNode(
          id: 'updateHabit',
          type: 'dataMutation',
          config: {'operation': 'update', 'entity': 'habits'},
        ),
        const BehaviorNode(
          id: 'deleteHabitData',
          type: 'dataMutation',
          config: {'operation': 'delete', 'entity': 'habits'},
        ),
      ],
      edges: const [],
    ),
    state: const StateSchema(
      variables: [
        StateVariable(
          id: 'habitName',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
      ],
    ),
    data: const DataSchema(
      entities: [
        DataEntitySchema(
          id: 'habits',
          name: 'habits',
          fields: [
            DataFieldSchema(
              id: 'f_id',
              name: 'id',
              type: 'string',
              required: true,
            ),
            DataFieldSchema(
              id: 'f_name',
              name: 'name',
              type: 'string',
              required: true,
            ),
            DataFieldSchema(
              id: 'f_completed',
              name: 'completed',
              type: 'boolean',
              defaultValue: false,
            ),
            DataFieldSchema(
              id: 'f_createdAt',
              name: 'createdAt',
              type: 'string',
              required: true,
            ),
          ],
        ),
      ],
      schemaVersion: 1,
    ),
    provenance: const PackageProvenance(
      creationEngineVersion: '1.0.0',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: '', computedAt: now),
  );
}
