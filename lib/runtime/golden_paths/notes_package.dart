/// Notes ExperiencePackage fixture.
library;

import 'package:uuid/uuid.dart';

import '../../creation/experience_package.dart';

ExperiencePackage createNotesPackage() {
  final id = 'exp-notes-${const Uuid().v4()}';
  final now = DateTime.now();

  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: id,
      name: 'Notes',
      description: 'Simple note taking',
      version: '1.0.0',
      createdAt: now,
      updatedAt: now,
      networkMode: NetworkMode.none,
      storageMode: StorageMode.localDatabase,
    ),
    interface: InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'notes',
          title: 'Notes',
          appBarTitle: 'Notes',
          children: [
            InterfaceNode(type: 'column', id: 'noteList', children: []),
          ],
        ),
      ],
    ),
    behavior: BehaviorGraph(
      nodes: [
        const BehaviorNode(
          id: 'createNote',
          type: 'event',
          config: {'description': 'Create a new note'},
        ),
        const BehaviorNode(
          id: 'editNote',
          type: 'event',
          config: {'description': 'Edit an existing note'},
        ),
        const BehaviorNode(
          id: 'deleteNote',
          type: 'event',
          config: {'description': 'Delete a note'},
        ),
        const BehaviorNode(
          id: 'insertNote',
          type: 'dataMutation',
          config: {'operation': 'insert', 'entity': 'notes'},
        ),
        const BehaviorNode(
          id: 'updateNote',
          type: 'dataMutation',
          config: {'operation': 'update', 'entity': 'notes'},
        ),
        const BehaviorNode(
          id: 'deleteNoteData',
          type: 'dataMutation',
          config: {'operation': 'delete', 'entity': 'notes'},
        ),
      ],
      edges: const [],
    ),
    state: const StateSchema(
      variables: [
        StateVariable(
          id: 'noteTitle',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
        StateVariable(
          id: 'noteBody',
          type: 'string',
          defaultValue: '',
          persistence: 'session',
        ),
      ],
    ),
    data: const DataSchema(
      entities: [
        DataEntitySchema(
          id: 'notes',
          name: 'notes',
          fields: [
            DataFieldSchema(
              id: 'f_id',
              name: 'id',
              type: 'string',
              required: true,
            ),
            DataFieldSchema(
              id: 'f_title',
              name: 'title',
              type: 'string',
              required: true,
            ),
            DataFieldSchema(
              id: 'f_body',
              name: 'body',
              type: 'string',
              defaultValue: '',
            ),
            DataFieldSchema(
              id: 'f_createdAt',
              name: 'createdAt',
              type: 'string',
              required: true,
            ),
            DataFieldSchema(
              id: 'f_updatedAt',
              name: 'updatedAt',
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
