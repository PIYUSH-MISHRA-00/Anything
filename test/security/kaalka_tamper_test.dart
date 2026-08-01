/// M2 — Kaalka protected-envelope tampering adversarial tests.
///
/// Stage 9.4 already certifies protect/unprotect roundtrip and wrong-time
/// rejection against the real, published Kaalka package. This file adds the
/// gap the Master Audit flagged: what happens when the *persisted*
/// ciphertext itself is corrupted (bit-flipped, truncated) rather than the
/// caller simply supplying the wrong time seed. Trusted opening must fail
/// safely — no crash, no raw crypto exception surfaced.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/core/contracts/protection_provider.dart';
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

  group('Tampered protected envelope', () {
    late SqliteExperienceRepository repository;
    late KaalkaProtectionProvider provider;
    late ExperienceProtectionService service;

    setUp(() async {
      repository = SqliteExperienceRepository(
        dbName: 'test_tamper_${DateTime.now().millisecondsSinceEpoch}.db',
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

    test(
      'bit-flipped ciphertext fails closed, not with a raw crypto error',
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

        final seed = provider.getCurrentSeed();
        final protectResult = await service.protectWithCustomTime(
          package: package,
          experienceId: experienceId,
          customTime: DateTime(
            2026,
            1,
            1,
            seed.hours,
            seed.minutes,
            seed.seconds,
          ),
        );
        expect(protectResult, isA<ProtectionSucceeded>());

        // Corrupt the persisted envelope's ciphertext in place.
        final envelopeJson = await repository.getProtectedEnvelope(
          experienceId,
        );
        expect(envelopeJson, isNotNull);
        final envelope = ProtectedEnvelope.deserialize(envelopeJson as String);
        final corruptedCiphertext = envelope.ciphertext.length > 10
            ? '${envelope.ciphertext.substring(0, envelope.ciphertext.length - 5)}XXXXX'
            : 'corrupted';
        final corruptedEnvelope = ProtectedEnvelope(
          ciphertext: corruptedCiphertext,
          seed: envelope.seed,
          originalContentHash: envelope.originalContentHash,
          protectedAt: envelope.protectedAt,
        );
        await repository.saveProtectedEnvelope(
          experienceId,
          corruptedEnvelope.serialize(),
        );

        // Attempt to open with the CORRECT time seed against corrupted data.
        final result = await service.unprotect(
          experienceId: experienceId,
          timeSeed: seed,
        );

        expect(result, isA<UnprotectionFailed>());
        final failure = result as UnprotectionFailed;
        // No raw crypto internals, stack traces, or ciphertext in the message.
        expect(failure.message.toLowerCase(), isNot(contains('exception')));
        expect(failure.message, isNot(contains(corruptedCiphertext)));
      },
    );

    test('protection flag set but envelope missing (crash mid-protect, before '
        'plaintext deletion) recovers the still-present plaintext instead of '
        'crashing or losing data', () async {
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
      // Simulate a crash between "mark protected" and "write envelope"
      // (_protect's step 5 deletePackage never ran) — the flag says
      // protected but no envelope and the plaintext row is still there.
      await repository.updateProtectionState(experienceId, true);

      final result = await service.unprotect(
        experienceId: experienceId,
        timeSeed: provider.getCurrentSeed(),
      );

      // Deterministic, safe recovery: no envelope to decrypt, but the
      // plaintext is still intact, so unprotect() serves it rather than
      // failing or crashing. Nothing is lost from this partial-write state.
      expect(result, isA<UnprotectionNotProtected>());
      final recovered = result as UnprotectionNotProtected;
      expect(recovered.experienceId, experienceId);
    });

    test('protection flag set, envelope missing, AND plaintext already gone '
        'fails safely rather than crashing', () async {
      final package = createCalculatorPackage();
      final experienceId = package.manifest.experienceId;

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
      // No package saved at all, and protection flag set — the worst
      // case partial/corrupted state.
      await repository.updateProtectionState(experienceId, true);

      final result = await service.unprotect(
        experienceId: experienceId,
        timeSeed: provider.getCurrentSeed(),
      );

      expect(result, isA<UnprotectionFailed>());
    });
  });
}
