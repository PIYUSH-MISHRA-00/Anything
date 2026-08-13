/// IS-P22 — every generated records app gets a WebWeaveX "Discover" tab so it
/// can browse real-world data from the web, not only hand-entered records.
library;

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/core/contracts/intent.dart';
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

  test('a records app gains a WebWeaveX Discover tab + knowledge service', () async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());

    final result = await composition.intentRouter.route(
      Intent.create(expression: 'beekeeping hive inspection tracker'),
    );
    final pkg = (result.creationResult as CreationCreated).package;

    // Discover browse screen + a bottom-nav tab pointing to it.
    expect(pkg.interface.screens.any((s) => s.id == 'discover'), isTrue,
        reason: 'a Discover browse screen must be composed in');
    expect(
      pkg.interface.navigation?.items.any((i) => i.screenId == 'discover'),
      isTrue,
      reason: 'Discover must be reachable as a tab',
    );

    // WebWeaveX wiring: knowledge retrieval service + refresh behavior +
    // network capability, so the tab fetches live web data.
    expect(pkg.services.any((s) => s.type == 'knowledgeRetrieval'), isTrue);
    expect(pkg.behavior.nodes.any((n) => n.id == 'refreshData'), isTrue);
    expect(pkg.manifest.requiredCapabilities, contains('networkData'));

    // The app's own records surface is untouched (additive).
    expect(pkg.data!.entities, isNotEmpty);
    expect(
      pkg.interface.screens.any((s) => s.id != 'discover'),
      isTrue,
      reason: 'the records tabs must survive',
    );
  });
}
