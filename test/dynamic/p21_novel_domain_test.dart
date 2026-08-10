/// P21 — novel domain never named in production vocabulary patches.
library;

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CapabilityRegistry _reg() {
  final r = CapabilityRegistry();
  for (final d in const [
    CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 's',
      category: CapabilityCategory.storage,
      inputContract: 'v',
      outputContract: 'p',
    ),
    CapabilityDescriptor(
      id: 'clock',
      version: '1.0.0',
      name: 'Clock',
      description: 'c',
      category: CapabilityCategory.computation,
      inputContract: 'n',
      outputContract: 't',
    ),
    CapabilityDescriptor(
      id: 'http',
      version: '1.0.0',
      name: 'HTTP',
      description: 'h',
      category: CapabilityCategory.integration,
      inputContract: 'r',
      outputContract: 'r',
      requiredPermissions: ['internet'],
      networkRequired: true,
    ),
    CapabilityDescriptor(
      id: 'knowledge',
      version: '1.0.0',
      name: 'Knowledge',
      description: 'k',
      category: CapabilityCategory.knowledge,
      inputContract: 'q',
      outputContract: 'r',
      networkRequired: true,
    ),
    CapabilityDescriptor(
      id: 'files',
      version: '1.0.0',
      name: 'Files',
      description: 'f',
      category: CapabilityCategory.data,
      inputContract: 'f',
      outputContract: 'c',
      requiredPermissions: ['storage'],
    ),
  ]) {
    r.register(d);
  }
  return r;
}

class _NoAi implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'astronomy observatory — novel domain, no lib vocabulary patch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final result =
          await ExperienceCreationCoordinator(
            kernel: AnythingKernel(
              providerRegistry: _NoAi(),
              capabilityRegistry: _reg(),
            ),
            repository: SqliteExperienceRepository(
              dbName: 'p21_astro_${DateTime.now().microsecondsSinceEpoch}.db',
            ),
          ).createFromIntent(
            Intent.create(
              expression: '''
Create a professional application for managing a small astronomy observatory.
Track observations, telescopes, targets, sessions and observation notes.
Allow search and filtering.
Manage:
- observations
- telescopes
- targets
- sessions
- notes
''',
            ),
          );
      expect(result, isA<CreationCreated>(), reason: result.message);
      final pkg = (result as CreationCreated).package;
      final ids = pkg.data!.entities.map((e) => e.id).toSet();
      for (final frag in ['observation', 'telescope', 'target', 'session']) {
        expect(
          ids.any((id) => id.contains(frag)),
          isTrue,
          reason: 'missing ~$frag in $ids',
        );
      }
      expect(pkg.behavior.nodes.any((n) => n.type == 'dataMutation'), isTrue);
      expect(
        pkg.services.any(
          (s) => s.type == 'newsData' || s.type == 'weatherData',
        ),
        isFalse,
      );
    },
  );
}
