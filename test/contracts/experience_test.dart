/// Tests for foundational Experience contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/contracts/contracts.dart';

void main() {
  group('Experience', () {
    test('create with required fields', () {
      final experience = Experience(
        id: 'exp-1',
        title: 'Calculator',
        runtimeCategory: ExperienceRuntimeType.flutter,
        status: ExperienceStatus.active,
        metadata: ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.flutter,
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(experience.id, equals('exp-1'));
      expect(experience.title, equals('Calculator'));
      expect(experience.runtimeCategory, equals(ExperienceRuntimeType.flutter));
      expect(experience.status, equals(ExperienceStatus.active));
    });

    test('experience can represent non-AUIL runtime types', () {
      final flutterExp = Experience(
        id: 'exp-flutter',
        title: 'Flutter App',
        runtimeCategory: ExperienceRuntimeType.flutter,
        status: ExperienceStatus.active,
        metadata: const ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.flutter,
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final webExp = Experience(
        id: 'exp-web',
        title: 'Web App',
        runtimeCategory: ExperienceRuntimeType.web,
        status: ExperienceStatus.active,
        metadata: const ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.web,
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(
          requiresNetwork: true,
          endpoints: ['https://api.example.com'],
        ),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final auilExp = Experience(
        id: 'exp-auil',
        title: 'AUIL View',
        runtimeCategory: ExperienceRuntimeType.auil,
        status: ExperienceStatus.creating,
        metadata: ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.auil,
          data: {'layout': 'dashboard', 'components': []},
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(flutterExp.runtimeCategory, equals(ExperienceRuntimeType.flutter));
      expect(webExp.runtimeCategory, equals(ExperienceRuntimeType.web));
      expect(auilExp.runtimeCategory, equals(ExperienceRuntimeType.auil));
      expect(webExp.networkRequirements.requiresNetwork, isTrue);
    });

    test('copyWith preserves identity', () {
      final experience = Experience(
        id: 'exp-1',
        title: 'Original',
        runtimeCategory: ExperienceRuntimeType.flutter,
        status: ExperienceStatus.active,
        metadata: const ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.flutter,
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final updated = experience.copyWith(
        title: 'Updated',
        status: ExperienceStatus.suspended,
      );

      expect(updated.id, equals(experience.id));
      expect(updated.title, equals('Updated'));
      expect(updated.status, equals(ExperienceStatus.suspended));
    });

    test('equality compares by id, title, runtimeType, status', () {
      final exp1 = Experience(
        id: 'exp-1',
        title: 'Test',
        runtimeCategory: ExperienceRuntimeType.flutter,
        status: ExperienceStatus.active,
        metadata: const ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.flutter,
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final exp2 = Experience(
        id: 'exp-1',
        title: 'Test',
        runtimeCategory: ExperienceRuntimeType.flutter,
        status: ExperienceStatus.active,
        metadata: const ExperienceMetadata(
          runtimeCategory: ExperienceRuntimeType.flutter,
        ),
        storageRequirements: const ExperienceStorageRequirements(),
        networkRequirements: const ExperienceNetworkRequirements(),
        createdAt: DateTime(2025, 6, 1), // different date
        updatedAt: DateTime(2025, 6, 1),
      );

      expect(exp1, equals(exp2));
    });
  });

  group('Workspace', () {
    test('create workspace', () {
      final workspace = Workspace(
        id: 'ws-1',
        experienceId: 'exp-1',
        name: 'Main Workspace',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(workspace.id, equals('ws-1'));
      expect(workspace.experienceId, equals('exp-1'));
      expect(workspace.name, equals('Main Workspace'));
    });
  });

  group('ProtectionMetadata', () {
    test('default values', () {
      const protection = ProtectionMetadata();

      expect(protection.isEncrypted, isFalse);
      expect(protection.timeSeedMode, equals(ProtectionTimeSeedMode.live));
      expect(protection.customTimeSeed, isNull);
    });
  });
}
