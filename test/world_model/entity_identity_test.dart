/// Vision V9 WMSG — EntityIdentity/RelationshipIdentity/EntityResolver:
/// stable, persistent, cross-session, cross-experience identity, never a
/// random UUID.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/world_model/entity_identity.dart';
import 'package:anything/world_model/entity_resolver.dart';
import 'package:anything/world_model/relationship_identity.dart';
import 'package:anything/world_model/world_types.dart';

void main() {
  group('EntityIdentity.stable', () {
    test('reuses an already-stable id directly, deterministically', () {
      final a = EntityIdentity.stable(WorldNodeKind.capability, 'clock');
      final b = EntityIdentity.stable(WorldNodeKind.capability, 'clock');
      expect(a, b);
      expect(a.value, contains('clock'));
    });

    test('the same id under a different kind is a different identity', () {
      final capability = EntityIdentity.stable(WorldNodeKind.capability, 'x');
      final experience = EntityIdentity.stable(WorldNodeKind.experience, 'x');
      expect(capability, isNot(experience));
    });
  });

  group('EntityIdentity.structural', () {
    test(
      'two structurally-identical signatures across "different experiences" resolve to the same identity — '
      'no duplicate identities',
      () {
        final personInAppA = EntityIdentity.structural(WorldNodeKind.entity, [
          'Person',
          'text:name',
          'text:email',
        ]);
        final personInAppB = EntityIdentity.structural(WorldNodeKind.entity, [
          'Person',
          'text:email',
          'text:name',
        ]); // different order
        expect(personInAppA, personInAppB);
      },
    );

    test(
      'a structurally different signature produces a different identity',
      () {
        final person = EntityIdentity.structural(WorldNodeKind.entity, [
          'Person',
          'text:name',
        ]);
        final task = EntityIdentity.structural(WorldNodeKind.entity, [
          'Task',
          'text:title',
        ]);
        expect(person, isNot(task));
      },
    );
  });

  group('EntityResolver', () {
    const resolver = EntityResolver();

    test('prefers an already-stable id when provided', () {
      final identity = resolver.resolve(
        WorldNodeKind.capability,
        stableId: 'knowledge',
      );
      expect(
        identity,
        EntityIdentity.stable(WorldNodeKind.capability, 'knowledge'),
      );
    });

    test('falls back to a structural fingerprint when no stable id exists', () {
      final identity = resolver.resolve(
        WorldNodeKind.entity,
        structuralSignature: ['Task', 'text:title'],
      );
      expect(
        identity,
        EntityIdentity.structural(WorldNodeKind.entity, ['Task', 'text:title']),
      );
    });
  });

  group('RelationshipIdentity', () {
    test('is deterministic and distinguishes relationship kind', () {
      final a = EntityIdentity.stable(WorldNodeKind.experience, 'exp-a');
      final b = EntityIdentity.stable(WorldNodeKind.entity, 'task');
      final containsId = RelationshipIdentity.of(
        a,
        b,
        RelationshipKind.contains,
      );
      final referencesId = RelationshipIdentity.of(
        a,
        b,
        RelationshipKind.references,
      );
      expect(containsId, isNot(referencesId));
      expect(
        RelationshipIdentity.of(a, b, RelationshipKind.contains),
        containsId,
      );
    });
  });
}
