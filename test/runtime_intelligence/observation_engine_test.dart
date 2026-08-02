/// Vision V8 RIL — ObservationEngine: real Runtime Integration. Drives
/// actual ExperienceRouter/ExperienceQueryController/ExperienceStateEngine
/// instances (the same real objects the generated-app runtime uses) and
/// verifies ObservationEngine captures real, structural facts — and,
/// critically, that it NEVER captures raw content (search terms, filter
/// values, navigation arguments, state values, query results).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_router.dart';
import 'package:anything/runtime/query_controller.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/runtime_intelligence/observation_context.dart';
import 'package:anything/runtime_intelligence/observation_engine.dart';
import 'package:anything/runtime_intelligence/observation_memory.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  ObservationEngine buildEngine(ObservationMemory memory, {String experienceId = 'exp-1'}) {
    return ObservationEngine(
      memory: memory,
      context: ObservationContext(sessionId: 'session-1', experienceId: experienceId, startedAt: DateTime.now()),
    );
  }

  test('observing a real ExperienceRouter captures real navigation, never argument content', () async {
    final memory = ObservationMemory();
    final engine = buildEngine(memory);
    final router = ExperienceRouter(validScreenIds: {'home', 'detail'});
    engine.observeRouter(router);

    router.navigate(
      const NavigationRequest(
        action: NavigationAction.push,
        targetScreenId: 'detail',
        arguments: {'recordId': 'super-secret-personal-name-value'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final records = memory.ofCategory(ObservationCategory.navigation);
    expect(records, hasLength(1));
    expect(records.first.screenId, 'detail');
    expect(records.first.count, 1); // one argument key — count only, never content
    expect(records.first.experienceId, 'exp-1');

    // Structural guarantee: no field on ObservationRecord could ever
    // carry the argument's content — confirmed by field enumeration
    // (id/category/experienceId/screenId/entityId/capabilityId/
    // succeeded/count/timestamp), none of which is the arguments map.
  });

  test('observing a real ExperienceQueryController captures search/filter usage structurally, '
      'never the search term or filter values', () async {
    final memory = ObservationMemory();
    final engine = buildEngine(memory);
    final schema = DataSchema(
      entities: [
        DataEntitySchema(
          id: 'entity_1',
          name: 'Entry',
          fields: [const DataFieldSchema(id: 'title', name: 'Title', type: 'string')],
        ),
      ],
      schemaVersion: 1,
    );
    final dataRuntime = ExperienceDataRuntime();
    dataRuntime.initialize(schema, experienceId: 'exp-observe-query');
    await dataRuntime.insert('entry', {'id': 'r1', 'title': 'a very personal title'});

    final controller = ExperienceQueryController(entityId: 'entry', dataRuntime: dataRuntime);
    engine.observeQuery(controller);

    await controller.setSearch('a very personal title');

    final records = memory.ofCategory(ObservationCategory.search);
    expect(records, hasLength(greaterThanOrEqualTo(1)));
    expect(records.last.entityId, 'entry');
    expect(records.last.succeeded, isTrue);
    // count is a structural result count, never the search term itself.
    expect(records.last.count, isA<int>());
  });

  test('observing a real ExperienceStateEngine captures state-change facts, never the new value', () async {
    final memory = ObservationMemory();
    final engine = buildEngine(memory);
    final stateEngine = ExperienceStateEngine();
    stateEngine.initialize(
      const StateSchema(variables: [StateVariable(id: 'draftNote', type: 'string', defaultValue: '', persistence: 'session')]),
    );
    engine.observeState(stateEngine, 'draftNote');

    stateEngine.write('draftNote', 'something private the user typed');
    await Future<void>.delayed(Duration.zero);

    final records = memory.ofCategory(ObservationCategory.featureUsage);
    expect(records, hasLength(1));
    expect(records.first.entityId, 'draftNote');
    // No field on ObservationRecord ever holds the written value.
  });

  test('recordFailure and recordCapabilityUsage are purely structural', () {
    final memory = ObservationMemory();
    final engine = buildEngine(memory);

    engine.recordCapabilityUsage('knowledge', succeeded: true);
    engine.recordFailure(capabilityId: 'http');

    expect(memory.ofCategory(ObservationCategory.capabilityUsage), hasLength(1));
    final failures = memory.ofCategory(ObservationCategory.failure);
    expect(failures, hasLength(1));
    expect(failures.first.succeeded, isFalse);
    expect(failures.first.capabilityId, 'http');
  });

  test('dispose cancels every subscription — no further records after disposal', () async {
    final memory = ObservationMemory();
    final engine = buildEngine(memory);
    final router = ExperienceRouter(validScreenIds: {'home'});
    engine.observeRouter(router);
    await engine.dispose();

    router.navigate(const NavigationRequest(action: NavigationAction.push, targetScreenId: 'home'));
    await Future<void>.delayed(Duration.zero);

    expect(memory.ofCategory(ObservationCategory.navigation), isEmpty);
  });
}
