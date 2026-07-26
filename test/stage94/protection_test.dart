/// Stage 9.4 — Real Kaalka Protection Tests.
///
/// Tests the actual published Kaalka adapter through the
/// ProtectionProvider boundary. No mocking of Kaalka.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/core/contracts/protection_provider.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/legacy/kaalka_adapter.dart';
import 'package:anything/security/protection_service.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Real Kaalka Protection', () {
    late SqliteExperienceRepository repository;
    late KaalkaProtectionProvider provider;
    late ExperienceProtectionService service;

    setUp(() async {
      repository = SqliteExperienceRepository(
        dbName: 'test_protection_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      provider = KaalkaProtectionProvider(
        config: const ProtectionConfig(enabled: true),
      );
      service = ExperienceProtectionService(
        provider: provider,
        repository: repository,
      );
    });

    tearDown(() async {
      await repository.close();
    });

    test('current-time Protect executes real Kaalka encryption', () async {
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

      final result = await service.protectWithCurrentTime(
        package: package,
        experienceId: experienceId,
      );

      expect(result, isA<ProtectionSucceeded>());

      final succeeded = result as ProtectionSucceeded;
      expect(succeeded.envelope.ciphertext, isNotEmpty);
      expect(succeeded.envelope.seed, isA<TimeSeed>());
      expect(succeeded.envelope.originalContentHash, isNotEmpty);

      final metadata = await repository.getMetadata(experienceId);
      expect(metadata, isNotNull);
      expect(metadata!.isProtected, isTrue);

      final storedPackage = await repository.getPackage(experienceId);
      expect(storedPackage, isNull);

      final envelope = await repository.getProtectedEnvelope(experienceId);
      expect(envelope, isNotNull);
    });

    test('custom-time Protect executes real Kaalka encryption', () async {
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

      final customTime = DateTime(2025, 3, 15, 14, 30, 0);
      final result = await service.protectWithCustomTime(
        package: package,
        experienceId: experienceId,
        customTime: customTime,
      );

      expect(result, isA<ProtectionSucceeded>());

      final succeeded = result as ProtectionSucceeded;
      expect(succeeded.envelope.seed.hours, equals(14));
      expect(succeeded.envelope.seed.minutes, equals(30));
      expect(succeeded.envelope.seed.seconds, equals(0));
    });

    test('unprotect with correct time succeeds', () async {
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
      final protectResult = await service.protectWithCustomTime(
        package: package,
        experienceId: experienceId,
        customTime: customTime,
      );
      expect(protectResult, isA<ProtectionSucceeded>());

      final timeSeed = TimeSeed(hours: 8, minutes: 15, seconds: 0);
      final unprotectResult = await service.unprotect(
        experienceId: experienceId,
        timeSeed: timeSeed,
      );

      expect(unprotectResult, isA<UnprotectionSucceeded>());

      final succeeded = unprotectResult as UnprotectionSucceeded;
      expect(succeeded.package.manifest.experienceId, equals(experienceId));
      expect(succeeded.package.manifest.name, equals('Calculator'));
    });

    test('unprotect with wrong time fails', () async {
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

      final protectTime = DateTime(2025, 6, 10, 8, 15, 0);
      final protectResult = await service.protectWithCustomTime(
        package: package,
        experienceId: experienceId,
        customTime: protectTime,
      );
      expect(protectResult, isA<ProtectionSucceeded>());

      final wrongSeed = TimeSeed(hours: 9, minutes: 99, seconds: 0);
      final unprotectResult = await service.unprotect(
        experienceId: experienceId,
        timeSeed: wrongSeed,
      );

      expect(unprotectResult, isA<UnprotectionFailed>());

      final envelope = await repository.getProtectedEnvelope(experienceId);
      expect(envelope, isNotNull);

      final package2 = await repository.getPackage(experienceId);
      expect(package2, isNull);
    });

    test('integrity hash verified after unprotection', () async {
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
      await service.protectWithCustomTime(
        package: package,
        experienceId: experienceId,
        customTime: customTime,
      );

      final timeSeed = TimeSeed(hours: 8, minutes: 15, seconds: 0);
      final result = await service.unprotect(
        experienceId: experienceId,
        timeSeed: timeSeed,
      );

      expect(result, isA<UnprotectionSucceeded>());
      final succeeded = result as UnprotectionSucceeded;

      final restoredHash = ExperiencePackage.computeIntegrityHash(
        succeeded.package,
      );
      final originalHash = ExperiencePackage.computeIntegrityHash(package);
      expect(restoredHash, equals(originalHash));
    });
  });

  group('Protection survives restart', () {
    test(
      'protected Experience persists across repository recreation',
      () async {
        final dbSuffix = DateTime.now().millisecondsSinceEpoch;
        final repo1 = SqliteExperienceRepository(
          dbName: 'test_restart_1_$dbSuffix.db',
        );
        final provider1 = KaalkaProtectionProvider(
          config: const ProtectionConfig(enabled: true),
        );
        final service1 = ExperienceProtectionService(
          provider: provider1,
          repository: repo1,
        );

        final package = createCalculatorPackage();
        final experienceId = package.manifest.experienceId;

        await repo1.savePackage(package);
        await repo1.saveMetadata(
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
        final protectResult = await service1.protectWithCustomTime(
          package: package,
          experienceId: experienceId,
          customTime: customTime,
        );
        expect(protectResult, isA<ProtectionSucceeded>());

        await repo1.close();

        final repo2 = SqliteExperienceRepository(
          dbName: 'test_restart_1_$dbSuffix.db',
        );
        final provider2 = KaalkaProtectionProvider(
          config: const ProtectionConfig(enabled: true),
        );
        final service2 = ExperienceProtectionService(
          provider: provider2,
          repository: repo2,
        );

        final metadata = await repo2.getMetadata(experienceId);
        expect(metadata, isNotNull);
        expect(metadata!.isProtected, isTrue);

        final envelope = await repo2.getProtectedEnvelope(experienceId);
        expect(envelope, isNotNull);

        final timeSeed = TimeSeed(hours: 8, minutes: 15, seconds: 0);
        final unprotectResult = await service2.unprotect(
          experienceId: experienceId,
          timeSeed: timeSeed,
        );
        expect(unprotectResult, isA<UnprotectionSucceeded>());

        final succeeded = unprotectResult as UnprotectionSucceeded;
        expect(succeeded.package.manifest.name, equals('Calculator'));

        await repo2.close();
      },
    );
  });
}
