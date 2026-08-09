/// IS-P11 — Kaalka protect → persist → reopen repository → unprotect.
library;

import 'package:anything/core/contracts/protection_provider.dart';
import 'package:anything/legacy/kaalka_adapter.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/security/protection_service.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  test('protect, close repo, reopen, unprotect recovers package', () async {
    final dbName = 'p11_kaalka_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = SqliteExperienceRepository(dbName: dbName);
    final provider = KaalkaProtectionProvider(
      config: const ProtectionConfig(enabled: true),
    );
    final service = ExperienceProtectionService(
      provider: provider,
      repository: repository,
    );

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

    final seed = provider.getCurrentSeed();
    final protectTime = DateTime(
      2026,
      3,
      15,
      seed.hours,
      seed.minutes,
      seed.seconds,
    );
    final protectResult = await service.protectWithCustomTime(
      package: package,
      experienceId: experienceId,
      customTime: protectTime,
    );
    expect(protectResult, isA<ProtectionSucceeded>());

    await repository.close();

    final restarted = SqliteExperienceRepository(dbName: dbName);
    final restartedProvider = KaalkaProtectionProvider(
      config: const ProtectionConfig(enabled: true),
    );
    final restartedService = ExperienceProtectionService(
      provider: restartedProvider,
      repository: restarted,
    );

    final unprotect = await restartedService.unprotect(
      experienceId: experienceId,
      timeSeed: seed,
    );
    expect(unprotect, isA<UnprotectionSucceeded>());
    final ok = unprotect as UnprotectionSucceeded;
    expect(ok.package.manifest.experienceId, experienceId);
    expect(ok.package.manifest.name, package.manifest.name);

    await restarted.close();
  });
}
