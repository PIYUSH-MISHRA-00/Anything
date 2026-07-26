/// Stage 9.4 — Trusted Opening Tests.
///
/// Tests the ExperienceOpeningCoordinator as the single entry point
/// for all opening paths: Home Recent, My Apps, natural-language Open.
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

  group('Trusted Opening Flow', () {
    late SqliteExperienceRepository repository;
    late ActivityRepository activity;
    late ExperienceProtectionService protectionService;
    late ExperienceOpeningCoordinator coordinator;

    setUp(() async {
      repository = SqliteExperienceRepository(
        dbName: 'test_opening_${DateTime.now().millisecondsSinceEpoch}.db',
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

    test('opening unprotected Experience returns OpenReady', () async {
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

      final result = await coordinator.openExperience(experienceId);

      expect(result, isA<OpenReady>());
      final ready = result as OpenReady;
      expect(ready.package.manifest.name, equals('Calculator'));
      expect(ready.experienceId, equals(experienceId));
    });

    test('opening non-existent Experience returns OpenNotFound', () async {
      final result = await coordinator.openExperience('non-existent-id');
      expect(result, isA<OpenNotFound>());
    });

    test(
      'opening protected Experience returns OpenProtectionInputRequired',
      () async {
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
        final protectResult = await protectionService.protectWithCustomTime(
          package: package,
          experienceId: experienceId,
          customTime: customTime,
        );
        expect(protectResult, isA<ProtectionSucceeded>());

        final openResult = await coordinator.openExperience(experienceId);
        expect(openResult, isA<OpenProtectionInputRequired>());

        final required = openResult as OpenProtectionInputRequired;
        expect(required.experienceId, equals(experienceId));
        expect(required.needsTimeInput, isTrue);
      },
    );

    test(
      'openProtectedExperienceWithSeed with correct time returns OpenReady',
      () async {
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

        final timeSeed = TimeSeed(hours: 8, minutes: 15, seconds: 0);
        final result = await coordinator.openProtectedExperienceWithSeed(
          experienceId: experienceId,
          timeSeed: timeSeed,
        );

        expect(result, isA<OpenReady>());
        final ready = result as OpenReady;
        expect(ready.package.manifest.name, equals('Calculator'));
      },
    );

    test(
      'openProtectedExperienceWithSeed with wrong time returns OpenFailed',
      () async {
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

        final wrongSeed = TimeSeed(hours: 12, minutes: 0, seconds: 0);
        final result = await coordinator.openProtectedExperienceWithSeed(
          experienceId: experienceId,
          timeSeed: wrongSeed,
        );

        expect(result, isA<OpenFailed>());

        final envelope = await repository.getProtectedEnvelope(experienceId);
        expect(envelope, isNotNull);

        final pkg = await repository.getPackage(experienceId);
        expect(pkg, isNull);
      },
    );

    test('Opened Activity event emitted exactly once', () async {
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

      await coordinator.openExperience(experienceId);

      final events = await activity.list(limit: 10);
      final openedEvents = events
          .where((e) => e.type == 'opened' && e.experienceId == experienceId)
          .toList();
      expect(openedEvents.length, equals(1));
    });
  });

  group('Activity Independence', () {
    late SqliteExperienceRepository repository;
    late ActivityRepository activity;
    late ExperienceProtectionService protectionService;
    late ExperienceOpeningCoordinator coordinator;

    setUp(() async {
      repository = SqliteExperienceRepository(
        dbName: 'test_activity_${DateTime.now().millisecondsSinceEpoch}.db',
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

    test(
      'fake Protected Activity event does not fake protected state',
      () async {
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
            id: 'evt-fake',
            type: 'protected',
            experienceId: experienceId,
            experienceName: 'Calculator',
            message: 'Protected Calculator',
            timestamp: DateTime.now(),
          ),
        );

        final result = await coordinator.openExperience(experienceId);
        expect(result, isA<OpenReady>());
      },
    );

    test(
      'protected state persists even if Activity history is cleared',
      () async {
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
      },
    );
  });
}
