/// IS-P29 — "Change this app" can add a live WebWeaveX Discover/browse surface
/// via the AI planner's `addWebBrowse` operation. Proves the op flows through
/// `ExperienceModificationCoordinator.planEvolution` and composes a real
/// Discover tab (knowledgeRetrieval service) onto an existing records app.
library;

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/app/experience_modification_coordinator.dart';
import 'package:anything/capabilities/builtin/ai_capability.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/world_model/world_model_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeAi implements AiProvider {
  final String reply;
  const _FakeAi(this.reply);
  @override
  Future<String> generate(String prompt, {String? systemPrompt}) async => reply;
}

/// Rebuild [pkg] with any Discover screen + nav item removed, so we can prove
/// `addWebBrowse` re-adds it (a freshly-created records app already has one).
ExperiencePackage _stripDiscover(ExperiencePackage pkg) {
  final nav = pkg.interface.navigation;
  return ExperiencePackage(
    packageVersion: pkg.packageVersion,
    manifest: pkg.manifest,
    interface: InterfaceDefinition(
      screens: pkg.interface.screens.where((s) => s.id != 'discover').toList(),
      navigation: nav == null
          ? null
          : NavigationDefinition(
              type: nav.type,
              items:
                  nav.items.where((i) => i.screenId != 'discover').toList(),
            ),
    ),
    behavior: pkg.behavior,
    state: pkg.state,
    data: pkg.data,
    services: pkg.services,
    networkDeclarations: pkg.networkDeclarations,
    capabilityDeclarations: pkg.capabilityDeclarations,
    permissionDeclarations: pkg.permissionDeclarations,
    protection: pkg.protection,
    provenance: pkg.provenance,
    integrity: pkg.integrity,
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AI addWebBrowse op composes a live WebWeaveX Discover tab onto an existing app', () async {
    final composition = AppComposition.freshForTesting();
    final repository = composition.experienceRepository;
    addTearDown(() => repository.close());

    // Real records app from the creation pipeline (has entities + entityList).
    final created = await composition.intentRouter.route(
      Intent.create(expression: 'houseplant watering log'),
    );
    final full = (created.creationResult as CreationCreated).package;
    final id = full.manifest.experienceId;

    // Strip the auto-composed Discover tab so we can prove modification re-adds it.
    final stripped = _stripDiscover(full);
    expect(stripped.interface.screens.any((s) => s.id == 'discover'), isFalse);
    await repository.savePackage(stripped);

    final coordinator = ExperienceModificationCoordinator(
      repository: repository,
      worldModel: WorldModelCoordinator(),
      aiProvider: const _FakeAi(
        '[{"type":"addWebBrowse","params":{"subject":"houseplants"}}]',
      ),
    );
    final plan = await coordinator.planEvolution(
      experienceId: id,
      modificationExpression: 'let me browse real houseplants from the web',
    );

    expect(plan, isNotNull);
    final candidate = plan!.candidatePackage!;
    expect(candidate.interface.screens.any((s) => s.id == 'discover'), isTrue,
        reason: 'the WebWeaveX Discover screen must be composed back in');
    expect(candidate.services.any((s) => s.type == 'knowledgeRetrieval'), isTrue,
        reason: 'the live web browse needs the knowledgeRetrieval service');
    expect(
      candidate.interface.navigation?.items.any((i) => i.screenId == 'discover'),
      isTrue,
      reason: 'Discover must be reachable as a tab',
    );
  });
}
