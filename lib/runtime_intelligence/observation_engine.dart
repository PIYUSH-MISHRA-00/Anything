/// ObservationEngine — Autonomous Observation. Subscribes to the real,
/// already-broadcasting runtime streams (ExperienceRouter.events,
/// ExperienceQueryController.stateStream, ExperienceStateEngine.watch)
/// and records purely structural ObservationRecords. Never modifies the
/// runtime it observes, never reads record content, form values, or
/// search text — only structural facts (screen ids, entity ids, counts,
/// success/failure, timestamps).
///
/// A real, tested, attachable component — proven here by driving actual
/// ExperienceRouter/ExperienceQueryController/ExperienceStateEngine
/// instances in tests, exactly as the rest of the runtime test suite
/// does. Not yet auto-attached by ExperienceHostScreen in production
/// (a deliberate scope decision, documented in
/// docs/architecture/RUNTIME_INTELLIGENCE_LAYER.md, matching the same
/// "real capability, not yet wired into that pipeline" pattern already
/// established for ReviewMemory (V6) and EvolutionCoordinator (V7)).
library;

import 'dart:async';

import '../runtime/experience_router.dart';
import '../runtime/query_controller.dart';
import '../runtime/state_engine.dart';
import 'observation_context.dart';
import 'observation_memory.dart';
import 'observation_record.dart';
import 'ril_types.dart';

class ObservationEngine {
  final ObservationMemory memory;
  final ObservationContext context;
  final List<StreamSubscription<void>> _subscriptions = [];
  int _sequence = 0;

  ObservationEngine({required this.memory, required this.context});

  String _nextId() => 'obs-${context.sessionId}-${_sequence++}';

  /// Observes navigation: every push/pop/replace/tab-switch becomes a
  /// `navigation` record naming the destination screen id only — never
  /// the navigation arguments' content, only how many were passed.
  void observeRouter(ExperienceRouter router) {
    final subscription = router.events.listen((event) {
      memory.record(
        ObservationRecord(
          id: _nextId(),
          category: ObservationCategory.navigation,
          experienceId: context.experienceId,
          screenId: event.screenId,
          succeeded: true,
          count: event.arguments?.length,
          timestamp: event.timestamp,
        ),
      );
    });
    _subscriptions.add(subscription);
  }

  /// Observes query activity for one entity: search/filter/plain-read
  /// usage and success/failure, result COUNT only — never the search
  /// term, filter values, or the result records themselves.
  void observeQuery(ExperienceQueryController controller) {
    final subscription = controller.stateStream.listen((state) {
      final category = controller.searchTerm.isNotEmpty
          ? ObservationCategory.search
          : controller.filters.isNotEmpty
          ? ObservationCategory.filter
          : ObservationCategory.featureUsage;
      memory.record(
        ObservationRecord(
          id: _nextId(),
          category: category,
          experienceId: context.experienceId,
          entityId: controller.entityId,
          succeeded: state.status != QueryStatus.error,
          count: state.count,
          timestamp: DateTime.now(),
        ),
      );
    });
    _subscriptions.add(subscription);
  }

  /// Observes that a state variable changed — the fact of a change only,
  /// identified by its stable stateId, never the new value.
  void observeState(ExperienceStateEngine engine, String stateId) {
    final subscription = engine.watch(stateId).listen((_) {
      memory.record(
        ObservationRecord(
          id: _nextId(),
          category: ObservationCategory.featureUsage,
          experienceId: context.experienceId,
          entityId: stateId,
          succeeded: true,
          timestamp: DateTime.now(),
        ),
      );
    });
    _subscriptions.add(subscription);
  }

  /// Records a structural failure (e.g. a capability invocation that
  /// failed) — callers pass only ids, never error content/stack traces.
  void recordFailure({String? capabilityId, String? entityId}) {
    memory.record(
      ObservationRecord(
        id: _nextId(),
        category: ObservationCategory.failure,
        experienceId: context.experienceId,
        entityId: entityId,
        capabilityId: capabilityId,
        succeeded: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Records a structural capability invocation.
  void recordCapabilityUsage(String capabilityId, {bool succeeded = true}) {
    memory.record(
      ObservationRecord(
        id: _nextId(),
        category: ObservationCategory.capabilityUsage,
        experienceId: context.experienceId,
        capabilityId: capabilityId,
        succeeded: succeeded,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
