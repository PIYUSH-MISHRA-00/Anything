/// Final forensic — capability shells must not require AI on device path.
library;

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
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

Future<CreationResult> _route(String prompt) async {
  SharedPreferences.setMockInitialValues({});
  return ExperienceCreationCoordinator(
    // Strict (production) policy: app generation requires an AI provider; local
    // capability shells (calc/timer/weather) still build.
    kernel: AnythingKernel(
      providerRegistry: _NoAi(),
      capabilityRegistry: _reg(),
      reasoner: CompositeApplicationReasoner(
        providerRegistry: _NoAi(),
        requireProviderForGeneration: true,
      ),
    ),
    repository: SqliteExperienceRepository(
      dbName: 'p_final_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  ).createFromIntent(Intent.create(expression: prompt));
}

Future<CreationCreated> _create(String prompt) async {
  final result = await _route(prompt);
  expect(
    result,
    isA<CreationCreated>(),
    reason: result is CreationProviderRequired
        ? 'must not require AI: ${result.message}'
        : result.message,
  );
  return result as CreationCreated;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('stopwatch without AI → timing controls', () async {
    final created = await _create(
      'Create a professional stopwatch application.',
    );
    final probe = PackageCapabilityProbe(created.package);
    expect(probe.hasTimingControls, isTrue);
    expect(probe.hasCalculationPad, isFalse);
  });

  test('scientific calculator without AI → scientific ops', () async {
    final created = await _create(
      'Create a professional scientific calculator.',
    );
    final probe = PackageCapabilityProbe(created.package);
    expect(probe.hasCalculationPad, isTrue);
    expect(probe.hasScientificOps, isTrue);
    expect(probe.hasTimingControls, isFalse);
  });

  test('weather without AI → knowledgeRetrieval service', () async {
    final created = await _create('Create a professional weather dashboard.');
    expect(
      created.package.services.any((s) => s.type == 'knowledgeRetrieval'),
      isTrue,
    );
    expect(
      created.package.capabilityDeclarations.any(
        (c) => c.capabilityId == 'knowledge',
      ),
      isTrue,
    );
  });

  // IS-P22: records apps are application GENERATION and now require an AI
  // provider — they are no longer built deterministically as a silent
  // substitute (that is what made every app look templated).
  test('task manager without AI → requires an AI provider', () async {
    final result = await _route('Create a professional task manager.');
    expect(result, isA<CreationProviderRequired>());
  });

  test('expense tracker without AI → requires an AI provider', () async {
    final result = await _route('Create a professional expense tracker.');
    expect(result, isA<CreationProviderRequired>());
  });
}
