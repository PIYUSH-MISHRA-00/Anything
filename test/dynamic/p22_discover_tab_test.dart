/// IS-P22 — the WebWeaveX "Discover" composer turns a local-CRUD records app
/// into one that can browse real-world data from the web.
///
/// NOTE: `composeDiscoverTab` is built and unit-tested here but is NOT yet
/// wired into the production creation path — enabling it hung a records
/// Experience's open-path `pumpAndSettle` (see creation_coordinator). This test
/// exercises the composer directly on a real generated package.
library;

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('composeDiscoverTab adds a WebWeaveX browse tab to a records app', () async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());

    final result = await composition.intentRouter.route(
      Intent.create(expression: 'beekeeping hive inspection tracker'),
    );
    final base = (result.creationResult as CreationCreated).package;
    // Baseline (production path) is local CRUD — no Discover yet.
    expect(base.interface.screens.any((s) => s.id == 'discover'), isFalse);

    final pkg = const NetworkReferenceInterfaceFactory().composeDiscoverTab(
      base,
      subject: base.data!.entities.first.name,
    );

    // Discover browse screen + a bottom-nav tab pointing to it.
    expect(pkg.interface.screens.any((s) => s.id == 'discover'), isTrue);
    expect(
      pkg.interface.navigation?.items.any((i) => i.screenId == 'discover'),
      isTrue,
    );
    // WebWeaveX wiring: knowledge retrieval service + refresh behavior + cap.
    expect(pkg.services.any((s) => s.type == 'knowledgeRetrieval'), isTrue);
    expect(pkg.behavior.nodes.any((n) => n.id == 'refreshData'), isTrue);
    expect(
      pkg.capabilityDeclarations.any((c) => c.capabilityId == 'networkData'),
      isTrue,
    );
    // Additive: the app's own records tabs survive.
    expect(pkg.data!.entities, isNotEmpty);
    expect(pkg.interface.screens.any((s) => s.id != 'discover'), isTrue);

    // Idempotent.
    final again = const NetworkReferenceInterfaceFactory()
        .composeDiscoverTab(pkg, subject: 'x');
    expect(
      again.interface.screens.where((s) => s.id == 'discover').length,
      1,
    );
  });
}
