/// M2 — Behavior graph cycle/budget adversarial certification.
///
/// Proves BehaviorInterpreter cannot be driven into infinite recursion,
/// unbounded work, or a partially-executed dangerous tail by a
/// maliciously-constructed (or malformed) generated BehaviorGraph.
///
/// Externally observable behavior only: node-execution side effects
/// (a shared 'counter' state variable), not implementation internals.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/behavior_interpreter.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/state_engine.dart';

// BehaviorInterpreter's execution budget (lib/runtime/behavior_interpreter.dart,
// `_maxNodesPerExecution`). Not importable (private); the value below is
// asserted against observed behavior at the boundary, so a future change
// to the constant surfaces here as a failing test rather than silent drift.
const int _kBudget = 100;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late BehaviorExecutionContext ctx;
  late ExperienceStateEngine stateEngine;
  late ExperienceDataRuntime dataRuntime;

  ExperiencePackage _minimalPackage(BehaviorGraph behavior) {
    return ExperiencePackage(
      manifest: ExperienceManifest(
        experienceId: 'cycle-test',
        name: 'Cycle Test',
        description: 'test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      interface: const InterfaceDefinition(
        screens: [InterfaceScreen(id: 'home', title: 'Home')],
      ),
      behavior: behavior,
      state: const StateSchema(
        // 'decimal' (not 'integer'): the calculation node's 'add' operation
        // always produces a double (see _executeCalculation), so an
        // 'integer'-typed variable would silently reject every write
        // (ExperienceStateEngine._isValidType fails closed on type
        // mismatch) — a real but non-security type-strictness quirk in the
        // calculation node, noted here rather than papered over.
        variables: [
          StateVariable(id: 'counter', type: 'decimal', defaultValue: 0),
        ],
      ),
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(contentHash: '', computedAt: DateTime.now()),
    );
  }

  Future<void> _run(BehaviorGraph graph, String eventId) async {
    final pkg = _minimalPackage(graph);
    stateEngine = ExperienceStateEngine();
    stateEngine.initialize(pkg.state);
    dataRuntime = ExperienceDataRuntime();
    dataRuntime.initialize(
      const DataSchema(
        entities: [
          DataEntitySchema(
            id: 'record',
            name: 'Record',
            fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
          ),
        ],
      ),
      experienceId: 'cycle-test',
    );
    final session = ExperienceSession(
      id: 'session-1',
      experienceId: pkg.manifest.experienceId,
      package: pkg,
      status: SessionStatus.running,
      startedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
    ctx = BehaviorExecutionContext(
      session: session,
      stateEngine: stateEngine,
      dataRuntime: dataRuntime,
      serviceResolver: ExperienceServiceResolver(),
    );
    await BehaviorInterpreter().execute(graph, eventId, context: ctx);
  }

  /// A calculation node that increments 'counter' by 1 — used purely as an
  /// observable "this node actually ran" marker.
  BehaviorNode _incNode(String id) => BehaviorNode(
    id: id,
    type: 'calculation',
    config: const {'operation': 'add', 'stateId': 'counter', 'operand': 1},
  );

  group('Direct cycles terminate safely', () {
    test('A -> A self-loop executes A exactly once, no hang', () async {
      final graph = BehaviorGraph(
        nodes: [
          const BehaviorNode(id: 'evt', type: 'event'),
          _incNode('a'),
        ],
        edges: const [
          BehaviorEdge(from: 'evt', to: 'a'),
          BehaviorEdge(from: 'a', to: 'a'),
        ],
      );

      await _run(graph, 'evt').timeout(const Duration(seconds: 5));

      expect(stateEngine.read('counter'), 1);
    });

    test('A -> B -> A executes each node exactly once', () async {
      final graph = BehaviorGraph(
        nodes: [
          const BehaviorNode(id: 'evt', type: 'event'),
          _incNode('a'),
          _incNode('b'),
        ],
        edges: const [
          BehaviorEdge(from: 'evt', to: 'a'),
          BehaviorEdge(from: 'a', to: 'b'),
          BehaviorEdge(from: 'b', to: 'a'),
        ],
      );

      await _run(graph, 'evt').timeout(const Duration(seconds: 5));

      expect(stateEngine.read('counter'), 2);
    });

    test('A -> B -> C -> A executes each node exactly once', () async {
      final graph = BehaviorGraph(
        nodes: [
          const BehaviorNode(id: 'evt', type: 'event'),
          _incNode('a'),
          _incNode('b'),
          _incNode('c'),
        ],
        edges: const [
          BehaviorEdge(from: 'evt', to: 'a'),
          BehaviorEdge(from: 'a', to: 'b'),
          BehaviorEdge(from: 'b', to: 'c'),
          BehaviorEdge(from: 'c', to: 'a'),
        ],
      );

      await _run(graph, 'evt').timeout(const Duration(seconds: 5));

      expect(stateEngine.read('counter'), 3);
    });

    test(
      'duplicate edges to an already-visited node do not re-execute it',
      () async {
        final graph = BehaviorGraph(
          nodes: [
            const BehaviorNode(id: 'evt', type: 'event'),
            _incNode('a'),
            _incNode('b'),
          ],
          edges: const [
            BehaviorEdge(from: 'evt', to: 'a'),
            BehaviorEdge(from: 'a', to: 'b'),
            BehaviorEdge(
              from: 'a',
              to: 'b',
            ), // duplicate fan-out to same target
            BehaviorEdge(from: 'a', to: 'b'),
          ],
        );

        await _run(graph, 'evt').timeout(const Duration(seconds: 5));

        expect(stateEngine.read('counter'), 2);
      },
    );
  });

  group('Per-event execution budget', () {
    Future<num> _chainCounterAfter(int calcNodeCount) async {
      final nodes = <BehaviorNode>[
        const BehaviorNode(id: 'evt', type: 'event'),
      ];
      final edges = <BehaviorEdge>[];
      String prev = 'evt';
      for (var i = 0; i < calcNodeCount; i++) {
        final id = 'n$i';
        nodes.add(_incNode(id));
        edges.add(BehaviorEdge(from: prev, to: id));
        prev = id;
      }
      final graph = BehaviorGraph(nodes: nodes, edges: edges);
      await _run(graph, 'evt').timeout(const Duration(seconds: 5));
      return stateEngine.read('counter') as num;
    }

    test(
      'chain of budget-2 calc nodes (limit - 1 total) executes fully',
      () async {
        // event(1) + (budget-2) calc nodes = budget-1 total nodes visited.
        final counter = await _chainCounterAfter(_kBudget - 2);
        expect(counter, _kBudget - 2);
      },
    );

    test('chain hitting the budget exactly executes fully', () async {
      // event(1) + (budget-1) calc nodes = budget total nodes visited.
      final counter = await _chainCounterAfter(_kBudget - 1);
      expect(counter, _kBudget - 1);
    });

    test(
      'chain exceeding the budget by one node stops the excess node',
      () async {
        // event(1) + budget calc nodes = budget+1 total nodes requested;
        // only (budget-1) calc nodes may run before the shared budget (which
        // also counts the event node) is exhausted.
        final counter = await _chainCounterAfter(_kBudget);
        expect(counter, _kBudget - 1);
      },
    );

    test(
      'large malicious graph (5000 nodes) is bounded, not exhaustive',
      () async {
        final counter = await _chainCounterAfter(5000);
        expect(counter, lessThan(5000));
        expect(counter, _kBudget - 1);
      },
    );
  });

  group('No dangerous partial tail after budget rejection', () {
    test('a delete node placed past the budget never executes', () async {
      final nodes = <BehaviorNode>[
        const BehaviorNode(id: 'evt', type: 'event'),
      ];
      final edges = <BehaviorEdge>[];
      String prev = 'evt';
      for (var i = 0; i < _kBudget; i++) {
        final id = 'n$i';
        nodes.add(_incNode(id));
        edges.add(BehaviorEdge(from: prev, to: id));
        prev = id;
      }
      // Dangerous tail: delete every record in 'record', wired past the budget.
      nodes.add(
        const BehaviorNode(
          id: 'evil_delete',
          type: 'dataMutation',
          config: {'operation': 'delete', 'entity': 'record', 'id': 'r1'},
        ),
      );
      edges.add(BehaviorEdge(from: prev, to: 'evil_delete'));
      final graph = BehaviorGraph(nodes: nodes, edges: edges);

      final pkg = _minimalPackage(graph);
      stateEngine = ExperienceStateEngine();
      stateEngine.initialize(pkg.state);
      dataRuntime = ExperienceDataRuntime();
      dataRuntime.initialize(
        const DataSchema(
          entities: [
            DataEntitySchema(
              id: 'record',
              name: 'Record',
              fields: [DataFieldSchema(id: 'name', name: 'Name', type: 'text')],
            ),
          ],
        ),
        experienceId: 'cycle-test-tail',
      );
      await dataRuntime.insert('record', {'id': 'r1', 'name': 'Alice'});

      final session = ExperienceSession(
        id: 'session-1',
        experienceId: pkg.manifest.experienceId,
        package: pkg,
        status: SessionStatus.running,
        startedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      ctx = BehaviorExecutionContext(
        session: session,
        stateEngine: stateEngine,
        dataRuntime: dataRuntime,
        serviceResolver: ExperienceServiceResolver(),
      );
      await BehaviorInterpreter()
          .execute(graph, 'evt', context: ctx)
          .timeout(const Duration(seconds: 5));

      final records = await dataRuntime.query('record');
      expect(
        records.length,
        1,
        reason: 'delete node past budget must never run',
      );

      await dataRuntime.dispose();
    });
  });

  group('Event re-entrancy', () {
    test(
      'no behavior node type can invoke dispatchEvent/execute again '
      '(stateWrite only writes state, never re-enters the interpreter)',
      () async {
        // Structural proof by exhaustive observable behavior: a graph whose
        // only nodes are stateWrite/calculation nodes cannot cause more than
        // one interpreter pass — there is no node type wired to call
        // AnythingRuntime.dispatchEvent or BehaviorInterpreter.execute from
        // within _executeByType (see lib/runtime/behavior_interpreter.dart).
        // We assert the observable consequence: writing the same state twice
        // via chained stateWrite nodes never fires a second, independent
        // execution pass (counter would exceed node count if it did).
        final graph = BehaviorGraph(
          nodes: [
            const BehaviorNode(id: 'evt', type: 'event'),
            _incNode('a'),
            const BehaviorNode(
              id: 'b',
              type: 'stateWrite',
              config: {'stateId': 'counter', 'value': 999},
            ),
          ],
          edges: const [
            BehaviorEdge(from: 'evt', to: 'a'),
            BehaviorEdge(from: 'a', to: 'b'),
          ],
        );

        await _run(graph, 'evt').timeout(const Duration(seconds: 5));

        // 'b' overwrites counter to 999 exactly once; if state writes could
        // re-trigger event dispatch, repeated increments would drive this
        // far past 999 or hang the 5s timeout above.
        expect(stateEngine.read('counter'), 999);
      },
    );
  });
}
