/// IntentExecutionPipeline — Implementation Specification IS-R37. The ONE
/// canonical production path from a user's `Intent` to engineering
/// execution: a thin, real composition over `UniversalIntentRouter` (R33)
/// and `WorkspaceEventPublisher` (R35) — never a new decision layer, never
/// a second router/coordinator.
///
/// REALITY before R37 (confirmed by reading source): the ONE real, live
/// production intent-entry point, `HomeScreen._createExperience()`
/// (`lib/features/home/home_screen.dart`), called
/// `ExperienceCreationCoordinator.createFromIntent()` directly — bypassing
/// `UniversalIntentRouter` entirely. Every session created this way was
/// never registered in `ExperienceWorkspaceManager`, despite R32-R36 wiring
/// `workspaceManager`/`intentRouter`/`workspaceRuntime`/`eventBus` as
/// optional `HomeScreen` fields (all accept-and-store-only until now).
///
/// This class exists only to give that real entry point ONE thing to call:
/// `execute()` invokes the router (unchanged, R33), then publishes the
/// resulting real `IntentRouted` event (unchanged, R35) — no new result
/// type. `RoutingResult` (already real, already typed, already returned by
/// `UniversalIntentRouter.route()`) IS the typed execution result this
/// specification asks for.
library;

import '../core/contracts/intent.dart';
import 'universal_intent_router.dart';
import 'workspace_event_publisher.dart';

class IntentExecutionPipeline {
  final UniversalIntentRouter _router;
  final WorkspaceEventPublisher _eventPublisher;

  const IntentExecutionPipeline({
    required UniversalIntentRouter router,
    required WorkspaceEventPublisher eventPublisher,
  }) : _router = router,
       _eventPublisher = eventPublisher;

  /// Accepts one user [intent], invokes the real `UniversalIntentRouter`
  /// (structural dispatch only — zero new reasoning, matching the router's
  /// own documented "never semantic interpretation" rule), publishes a real
  /// `IntentRouted` event for the outcome, and returns the router's own
  /// real, typed [RoutingResult] unmodified.
  Future<RoutingResult> execute(
    Intent intent, {
    RouteTarget? target,
    String? correlationId,
  }) async {
    final result = await _router.route(intent, target: target);
    _eventPublisher.publishIntentRouted(result, correlationId: correlationId);
    return result;
  }
}
