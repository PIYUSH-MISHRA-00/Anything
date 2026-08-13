/// Open-world generation through generic machinery (no domain factories):
/// record-shaped novel domains become records apps; genuinely non-records
/// domains honestly require AI rather than installing a wrong app.
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

  Future<CreationResult?> create(String expr) async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());
    final result =
        await composition.intentRouter.route(Intent.create(expression: expr));
    return result.creationResult;
  }

  test('novel record-shaped domain → multi-entity records app (no AI)', () async {
    final cr = await create(
        'Create a marine equipment rental management application for a small '
        'harbor with equipment inventory, customers, reservations and '
        'maintenance tracking.');
    expect(cr, isA<CreationCreated>());
    final pkg = (cr as CreationCreated).package;
    expect(pkg.manifest.tags, contains('collection'));
    expect(pkg.data!.entities.length, greaterThanOrEqualTo(2),
        reason: 'the listed subjects become entities, generically');
    // A records app (keeps its own list/form tabs), not the network-reference
    // search shell. It also gains a WebWeaveX "Discover" tab (networkData),
    // but its records surface is intact and it is not the reference_main shell.
    expect(pkg.interface.screens.any((s) => s.id == 'reference_main'), isFalse);
    expect(pkg.interface.screens.any((s) => s.id != 'discover'), isTrue);
  });

  test('non-records domain honestly requires AI, not a wrong records app', () async {
    // Messaging is conversations/real-time, not CRUD records. With no provider
    // the honest result is "needs AI" — never a todo/search substitute.
    final cr = await create('Create a modern messaging application.');
    expect(cr, isA<CreationProviderRequired>());
  });
}
