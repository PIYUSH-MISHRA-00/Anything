/// IS-P28 — a generated multi-entity records app persists a created record
/// end-to-end (intent → package → runtime submitForm(create) → query).
/// Guards against the create→dataMutation wiring or data-runtime init
/// regressing for underscore/multi-word entity ids.
library;

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/anything_runtime.dart';
import 'package:anything/runtime/behavior_interpreter.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/state_engine.dart';
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

  test('generated records app persists a created record end-to-end', () async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());

    final result = await composition.intentRouter.route(
      Intent.create(
        expression: 'beekeeping hive inspection and honey harvest tracker',
      ),
    );
    final cr = result.creationResult;
    expect(cr, isA<CreationCreated>(), reason: 'must create, not fail');
    final pkg = (cr as CreationCreated).package;
    expect(pkg.data, isNotNull, reason: 'a records app must have a data schema');

    final entityId = pkg.data!.entities.first.id;
    final dataRuntime = ExperienceDataRuntime();
    final runtime = AnythingRuntime(dataRuntime: dataRuntime);
    final session = await runtime.openExperience(pkg);
    expect(session.status, SessionStatus.running, reason: 'session must open');

    await runtime.dispatchEvent('submitForm', data: {
      'entityId': entityId,
      'mode': 'create',
      'values': {'note': 'Queen present', 'quantity': '3'},
    });

    // Note: ExperienceDatabase persists to disk keyed by the (deterministic)
    // experienceId, so records survive across runs — assert presence, not count.
    final records = await dataRuntime.query(entityId);
    expect(records, isNotEmpty,
        reason: 'create must persist a record into $entityId');
    expect(records.any((r) => r['note'] == 'Queen present'), isTrue,
        reason: 'the submitted values must be persisted');
  });

  // Regression for the on-device defect: a generated package can have an
  // entity id ("workout_log") that differs from its create event's noun
  // ("add_workout"). submitForm(entityId: workout_log) must still resolve to
  // that event via the mutation's entity binding, or the insert silently
  // never runs (records table stays empty). See behavior_interpreter
  // _resolveGenericEvent.
  test('submitForm resolves when event noun != entity id', () async {
    final composition = AppComposition.freshForTesting();
    addTearDown(() => composition.experienceRepository.close());
    final result = await composition.intentRouter.route(
      Intent.create(expression: 'beekeeping hive inspection tracker'),
    );
    final pkg = (result.creationResult as CreationCreated).package;

    final dataRuntime = ExperienceDataRuntime();
    dataRuntime.initialize(pkg.data!,
        experienceId: pkg.manifest.experienceId);
    final stateEngine = ExperienceStateEngine()..initialize(pkg.state);

    // Divergent graph: entity id `workout_log`, event noun `add_workout`.
    const graph = BehaviorGraph(
      nodes: [
        BehaviorNode(
            id: 'add_workout_event',
            type: 'event',
            config: {'eventId': 'add_workout'}),
        BehaviorNode(
            id: 'add_workout_create_data',
            type: 'dataMutation',
            config: {'operation': 'create', 'entity': 'workout_log'}),
      ],
      edges: [
        BehaviorEdge(from: 'add_workout_event', to: 'add_workout_create_data'),
      ],
    );
    final ctx = BehaviorExecutionContext(
      session: ExperienceSession(
        id: 's1',
        experienceId: pkg.manifest.experienceId,
        package: pkg,
        status: SessionStatus.running,
        startedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ),
      stateEngine: stateEngine,
      dataRuntime: dataRuntime,
      serviceResolver: ExperienceServiceResolver(),
    );

    await BehaviorInterpreter().execute(graph, 'submitForm',
        context: ctx,
        data: {
          'entityId': 'workout_log',
          'mode': 'create',
          'values': {'exercise_name': 'Squat', 'sets': '5'},
        });

    final recs = await dataRuntime.query('workout_log');
    expect(recs.any((r) => r['exercise_name'] == 'Squat'), isTrue,
        reason: 'insert must run despite event noun/entity-id divergence');
  });
}
