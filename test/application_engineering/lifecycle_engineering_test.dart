/// Vision V3 AEE — LifecycleEngineering: maps the real, M1-certified
/// Experience lifecycle into typed hooks, each pointing at the class that
/// actually realizes it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/lifecycle_engineering.dart';

void main() {
  const lifecycleEngineering = LifecycleEngineering();

  test('one hook per lifecycle stage, each naming a real implementing class', () {
    final result = lifecycleEngineering.plan();
    expect(result.hooks, hasLength(LifecycleHookKind.values.length));

    String realizedByOf(LifecycleHookKind kind) =>
        result.hooks.firstWhere((h) => h.kind == kind).realizedBy;

    expect(realizedByOf(LifecycleHookKind.onCreate), contains('CreationEngine'));
    expect(realizedByOf(LifecycleHookKind.onPersist), contains('SqliteExperienceRepository'));
    expect(realizedByOf(LifecycleHookKind.onOpen), contains('ExperienceOpeningCoordinator'));
    expect(realizedByOf(LifecycleHookKind.onClose), contains('AnythingRuntime'));
    expect(realizedByOf(LifecycleHookKind.onReopen), contains('ExperienceOpeningCoordinator'));
  });

  test('every hook decision cites the real M1 certification test as proof', () {
    final result = lifecycleEngineering.plan();
    for (final hook in result.hooks) {
      expect(hook.decision.rationale, contains('stage11_final_production_certification_test.dart'));
    }
  });
}
