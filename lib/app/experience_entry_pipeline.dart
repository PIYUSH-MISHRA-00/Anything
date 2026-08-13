/// ExperienceEntryPipeline — Implementation Specification IS-R45. The ONE
/// canonical entry mechanism every real production Experience-opening path
/// flows through — a thin, real composition over `IntentExecutionPipeline`
/// (R37, unmodified), `ExperienceOpeningCoordinator` (unmodified),
/// `ExperienceWorkspaceManager` (unmodified logic, one new additive method),
/// and `ExperienceActivationManager` (R44, unmodified) — never a second
/// scheduler, never a second Navigator, never a second AI boundary.
///
/// REALITY before R45 (confirmed by reading source): `HomeScreen` had 4 real
/// entry-triggering call sites, all funneling through `_openViaCoordinator()`
/// -> `ExperienceOpeningCoordinator.openExperience()` -> directly calling
/// `ExperienceActivationManager.activate()` with `sessionId: null` always
/// (since no workspace session was ever registered for this path) — meaning
/// every one of these entries silently bypassed workspace registration and
/// scheduler participation. Only the Workspace Switcher's `EntryBySession`
/// case (already registered, R44) was fully correct.
///
/// `Intent` (`lib/core/contracts/intent.dart`) has NO field referencing a
/// specific, explicit `experienceId` — it is purely expression/text-driven.
/// `CreationOpened` is produced only when `AnythingKernel.processIntent()`
/// itself internally fuzzy-matches intent text to an existing Experience —
/// never from a caller-supplied identifier. Routing an explicit, already-known
/// `experienceId` (Recent list, birth completion, protection resume) through
/// `ExperienceWorkspaceManager.openExperience(Intent)` would therefore be
/// unreliable AND would wrongly introduce a real Kernel/AI-adjacent decision
/// into a path that today, correctly, needs zero reasoning and zero AI
/// provider. This pipeline never does that — `activateExperience()`/
/// `activateProtectedExperience()` register workspace sessions via the new
/// `ExperienceWorkspaceManager.openExistingExperience()` (additive,
/// Kernel-free) instead.
///
/// EXPERIENCE OPENING COORDINATOR — "refactor to consume the unified entry
/// pipeline" is interpreted here as: the overall real production FLOW now
/// consumes `ExperienceOpeningCoordinator` only THROUGH this pipeline
/// (`HomeScreen` no longer calls it directly at all) — `ExperienceOpeningCoordinator`
/// itself remains a low-level, trusted loading/validation/protection service
/// with no knowledge of workspace/scheduler/activation concepts, called BY
/// this pipeline, never the reverse (inverting that dependency would be
/// circular/backwards layering). Its own real logic is reused verbatim, never
/// duplicated — this file contains zero package-loading/validation/protection
/// logic of its own.
///
/// ENTRY SOURCES: Create New Experience (`submitIntent`, real, unchanged
/// Intent/Kernel path), Recent List + Restore Session (`activateExperience`
/// — loading an already-persisted Experience by id IS itself a form of
/// restore; no separate snapshot-specific restore trigger exists in
/// production today, so none is fabricated here), Workspace Switcher
/// (`activateRunningSession`, reused by `WorkspaceSwitcherSheet`). Future
/// Deep Links/Notifications are NOT built this milestone — `activateExperience`
/// is the real, honest integration point any such future source would call.
///
/// EVENTS: no new `AnythingEvent` subtype, no new publish call here — every
/// composed piece (`IntentExecutionPipeline`, `ExperienceActivationManager`)
/// already publishes real `WorkspaceUpdated` events for its own real
/// transitions.
library;

import 'package:flutter/material.dart' hide Intent;

import '../capabilities/builtin/ai_capability.dart';
import '../capabilities/platform/capability_platform.dart';
import '../core/contracts/intent.dart';
import '../core/contracts/protection_provider.dart';
import '../core/events/events.dart';
import '../creation/experience_package.dart';
import '../runtime/experience_host_screen.dart';
import '../runtime/experience_runtime_controller.dart';
import '../storage/engineering_memory_repository.dart';
import '../world_model/world_model_coordinator.dart';
import 'autonomous_workspace_runtime.dart';
import 'experience_activation_manager.dart';
import 'experience_opening_coordinator.dart';
import 'experience_workspace_manager.dart';
import 'intent_execution_pipeline.dart';
import 'universal_intent_router.dart';
import 'workspace_runtime_supervisor.dart';
import 'workspace_scheduling_engine.dart';

class ExperienceEntryPipeline {
  final IntentExecutionPipeline intentExecutionPipeline;
  final ExperienceOpeningCoordinator openingCoordinator;
  final ExperienceActivationManager activationManager;
  final ExperienceWorkspaceManager? workspaceManager;
  final WorldModelCoordinator? worldModel;
  final CapabilityPlatform? capabilityPlatform;
  final EngineeringMemoryRepository? engineeringMemory;
  final AutonomousWorkspaceRuntime? workspaceRuntime;
  final EventBus? eventBus;
  final WorkspaceRuntimeSupervisor? runtimeSupervisor;
  final WorkspaceSchedulingEngine? scheduler;
  final AiProvider? aiProvider;

  const ExperienceEntryPipeline({
    required this.intentExecutionPipeline,
    required this.openingCoordinator,
    required this.activationManager,
    this.workspaceManager,
    this.worldModel,
    this.capabilityPlatform,
    this.engineeringMemory,
    this.workspaceRuntime,
    this.eventBus,
    this.runtimeSupervisor,
    this.scheduler,
    this.aiProvider,
  });

  /// Create New Experience — a thin, real forward to the existing,
  /// unmodified `IntentExecutionPipeline.execute()` (R37). Returns the raw
  /// `RoutingResult` for the caller's own UI branching (birth sequence,
  /// clarification/provider-required snackbars) — this pipeline never owns
  /// that UI orchestration, matching `HomeScreen._createExperience()`'s own
  /// real, existing contract exactly.
  Future<RoutingResult> submitIntent(
    Intent intent, {
    RouteTarget target = const RouteTarget.newExperience(),
  }) {
    return intentExecutionPipeline.execute(intent, target: target);
  }

  /// Recent List / birth completion / `CreationOpened` reopen / Restore
  /// Session — opens an already-known `experienceId` via the real,
  /// unmodified `ExperienceOpeningCoordinator.openExperience()`, then, on
  /// `OpenReady`, registers a real workspace session (if one isn't already
  /// open for it) and activates it. Returns the real `OpenResult` so the
  /// caller can react to `OpenProtectionInputRequired`/`OpenNotFound`/
  /// `OpenInvalid`/`OpenFailed` exactly as before.
  Future<OpenResult> activateExperience(
    NavigatorState navigator,
    String experienceId,
  ) async {
    final result = await openingCoordinator.openExperience(experienceId);
    if (result is OpenReady) await _registerAndActivate(navigator, result);
    return result;
  }

  /// Protection Resume — same real contract as [activateExperience], via
  /// the real, unmodified `ExperienceOpeningCoordinator.openProtectedExperienceWithSeed()`.
  Future<OpenResult> activateProtectedExperience(
    NavigatorState navigator, {
    required String experienceId,
    required TimeSeed timeSeed,
  }) async {
    final result = await openingCoordinator.openProtectedExperienceWithSeed(
      experienceId: experienceId,
      timeSeed: timeSeed,
    );
    if (result is OpenReady) await _registerAndActivate(navigator, result);
    return result;
  }

  Future<void> _registerAndActivate(
    NavigatorState navigator,
    OpenReady result,
  ) async {
    var sessionId = workspaceManager
        ?.sessionForExperience(result.experienceId)
        ?.sessionId;
    if (sessionId == null && workspaceManager != null) {
      final started = await workspaceManager!.openExistingExperience(
        experienceId: result.experienceId,
        experienceName: result.experienceName,
      );
      sessionId = started.sessionId;
    }
    await activationManager.activate(
      navigator,
      sessionId,
      createRoute: () => MaterialPageRoute(
        builder: (_) => ExperienceHostScreen(
          package: result.package,
          experienceName: result.experienceName,
          experienceId: result.experienceId,
          worldModel: worldModel,
          capabilityPlatform: capabilityPlatform,
          engineeringMemory: engineeringMemory,
          workspaceManager: workspaceManager,
          workspaceRuntime: workspaceRuntime,
          eventBus: eventBus,
          runtimeSupervisor: runtimeSupervisor,
          scheduler: scheduler,
          aiProvider: aiProvider,
        ),
      ),
    );
  }

  /// Workspace Switcher — activates a session that ALREADY has a real,
  /// registered `ExperienceRuntimeController`/running `AnythingRuntime`
  /// (via [controller]/[package], resolved by the caller through
  /// `WorkspaceRuntimeSupervisor.lookup()`). Reuses that SAME live
  /// controller/runtime, never constructing a fresh one — deliberately does
  /// NOT pass `runtimeSupervisor:` to the reconstructed screen, since
  /// [controller] is already registered under it and
  /// `ExperienceHostScreen._registerWithSupervisor()` (unmodified) would
  /// otherwise raise `WorkspaceRuntimeSupervisor.register()`'s real
  /// duplicate-sessionId `StateError`. Extracted verbatim from
  /// `WorkspaceSwitcherSheet`'s own R44 logic — real unification, zero
  /// behavior change.
  Future<void> activateRunningSession(
    NavigatorState navigator,
    String sessionId, {
    required ExperienceRuntimeController controller,
    required ExperiencePackage package,
    String? experienceId,
    String? experienceName,
  }) {
    return activationManager.activate(
      navigator,
      sessionId,
      createRoute: () => MaterialPageRoute(
        builder: (_) => ExperienceHostScreen(
          package: package,
          experienceName: experienceName,
          experienceId: experienceId,
          workspaceManager: workspaceManager,
          runtime: controller.runtime,
          runtimeController: controller,
          scheduler: scheduler,
        ),
      ),
    );
  }
}
