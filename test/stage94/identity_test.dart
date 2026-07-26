/// Stage 9.4 — Birth Identity & Opening Identity Tests.
///
/// Verifies that:
/// - Birth completion opens the EXACT created Experience (not the first recent)
/// - Multiple Calculators are handled correctly
/// - Opening coordinator is the single entry point
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_opening_coordinator.dart';
import 'package:anything/core/contracts/protection_provider.dart';
import 'package:anything/legacy/kaalka_adapter.dart';
import 'package:anything/security/protection_service.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Birth Identity', () {
    late SqliteExperienceRepository repository;

    setUp(() async {
      repository = SqliteExperienceRepository(
        dbName: 'test_birth_${DateTime.now().millisecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      await repository.close();
    });

    test(
      'after creating Calculator B, opening the created ID yields B not A',
      () async {
        final packageA = createCalculatorPackage();
        await repository.savePackage(packageA);
        await repository.saveMetadata(
          ExperienceMetadataRecord(
            id: packageA.manifest.experienceId,
            name: 'Calculator A',
            description: 'Older calculator',
            category: 'utility',
            createdAt: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        final packageB = createCalculatorPackage();
        await repository.savePackage(packageB);
        await repository.saveMetadata(
          ExperienceMetadataRecord(
            id: packageB.manifest.experienceId,
            name: 'Calculator B',
            description: 'Newer calculator',
            category: 'utility',
            createdAt: DateTime(2025, 6, 1),
            updatedAt: DateTime(2025, 6, 1),
          ),
        );

        final openedPackage = await repository.getPackage(
          packageB.manifest.experienceId,
        );

        expect(openedPackage, isNotNull);
        expect(
          openedPackage!.manifest.experienceId,
          equals(packageB.manifest.experienceId),
        );

        final all = await repository.listAll();
        expect(all.length, greaterThanOrEqualTo(2));
        final ids = all.map((e) => e.id).toSet();
        expect(ids, contains(packageA.manifest.experienceId));
        expect(ids, contains(packageB.manifest.experienceId));
      },
    );

    test('opening via coordinator uses created ID, not first recent', () async {
      final provider = KaalkaProtectionProvider(
        config: const ProtectionConfig(enabled: true),
      );
      final protectionService = ExperienceProtectionService(
        provider: provider,
        repository: repository,
      );
      final coordinator = ExperienceOpeningCoordinator(
        repository: repository,
        activity: ActivityRepository(),
        protectionService: protectionService,
      );

      final packageA = createCalculatorPackage();
      await repository.savePackage(packageA);
      await repository.saveMetadata(
        ExperienceMetadataRecord(
          id: packageA.manifest.experienceId,
          name: 'Calculator A',
          description: 'Older calculator',
          category: 'utility',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      );

      final packageB = createCalculatorPackage();
      await repository.savePackage(packageB);
      await repository.saveMetadata(
        ExperienceMetadataRecord(
          id: packageB.manifest.experienceId,
          name: 'Calculator B',
          description: 'Newer calculator',
          category: 'utility',
          createdAt: DateTime(2025, 6, 1),
          updatedAt: DateTime(2025, 6, 1),
        ),
      );

      final result = await coordinator.openExperience(
        packageB.manifest.experienceId,
      );

      expect(result, isA<OpenReady>());
      final ready = result as OpenReady;
      expect(ready.experienceId, equals(packageB.manifest.experienceId));
      expect(ready.experienceName, equals('Calculator B'));
    });
  });

  group('Protection State vs Activity', () {
    late SqliteExperienceRepository repository;
    late ActivityRepository activity;
    late ExperienceProtectionService protectionService;
    late ExperienceOpeningCoordinator coordinator;

    setUp(() async {
      repository = SqliteExperienceRepository(
        dbName: 'test_prot_act_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      activity = ActivityRepository();
      final provider = KaalkaProtectionProvider(
        config: const ProtectionConfig(enabled: true),
      );
      protectionService = ExperienceProtectionService(
        provider: provider,
        repository: repository,
      );
      coordinator = ExperienceOpeningCoordinator(
        repository: repository,
        activity: activity,
        protectionService: protectionService,
      );
    });

    tearDown(() async {
      await repository.close();
    });

    test('Activity history is not used as protection state', () async {
      final package = createCalculatorPackage();
      final experienceId = package.manifest.experienceId;

      await repository.savePackage(package);
      await repository.saveMetadata(
        ExperienceMetadataRecord(
          id: experienceId,
          name: package.manifest.name,
          description: package.manifest.description,
          category: 'utility',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await activity.record(
        ActivityEvent(
          id: 'evt-fake-protected',
          type: 'protected',
          experienceId: experienceId,
          experienceName: 'Calculator',
          message: 'Protected Calculator',
          timestamp: DateTime.now(),
        ),
      );

      final result = await coordinator.openExperience(experienceId);
      expect(result, isA<OpenReady>());
    });

    test('protected state survives Activity clearing', () async {
      final package = createCalculatorPackage();
      final experienceId = package.manifest.experienceId;

      await repository.savePackage(package);
      await repository.saveMetadata(
        ExperienceMetadataRecord(
          id: experienceId,
          name: package.manifest.name,
          description: package.manifest.description,
          category: 'utility',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final customTime = DateTime(2025, 6, 10, 8, 15, 0);
      await protectionService.protectWithCustomTime(
        package: package,
        experienceId: experienceId,
        customTime: customTime,
      );

      await activity.clearAll();

      final result = await coordinator.openExperience(experienceId);
      expect(result, isA<OpenProtectionInputRequired>());
    });
  });
}
