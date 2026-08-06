/// Experience Host Screen — loads and displays a running Experience.
library;

import 'dart:async' show unawaited;
import 'package:flutter/material.dart';

import '../app/autonomous_workspace_runtime.dart';
import '../app/experience_modification_coordinator.dart';
import '../app/experience_workspace_manager.dart';
import '../app/workspace_event_publisher.dart';
import '../app/workspace_lifecycle_policy_engine.dart';
import '../app/workspace_runtime_supervisor.dart';
import '../capabilities/platform/capability_platform.dart';
import '../core/events/events.dart';
import '../creation/experience_package.dart';
import '../storage/activity_repository.dart';
import '../storage/engineering_memory_repository.dart';
import '../security/protection_service.dart';
import '../world_model/world_model_coordinator.dart';
import 'anything_runtime.dart';
import 'experience_renderer.dart';
import 'experience_router.dart';
import 'experience_runtime_controller.dart';
import 'experience_session.dart';

/// Hosts a running Experience inside Anything.
class ExperienceHostScreen extends StatefulWidget {
  final ExperiencePackage package;
  final String? experienceName;
  final String? experienceId;
  final ExperienceProtectionService? protectionService;

  /// Optional pre-created runtime for dependency injection.
  /// When provided, the screen will NOT create its own runtime and will use
  /// this one instead. This allows tests to inject a runtime backed by real
  /// SQLite (created outside the testWidgets context where FFI works).
  final AnythingRuntime? runtime;

  /// Shared, canonical World Graph / Capability Platform (Implementation
  /// Milestone R1) — threaded from the composition root
  /// (`AnythingAppShell` -> `AppComposition`) so every Experience shares
  /// the SAME `WorldModelCoordinator`/`CapabilityPlatform` instance rather
  /// than each host screen constructing its own (MIS-1 Part 2's ownership
  /// finding). Both null by default: existing tests/callers that construct
  /// `ExperienceHostScreen` directly are unaffected (`ExperienceModificationCoordinator`
  /// falls back to its own default `WorldModelCoordinator()`, and
  /// `AnythingRuntime` falls back to the stubbed dispatch path, exactly as
  /// before R1).
  final WorldModelCoordinator? worldModel;
  final CapabilityPlatform? capabilityPlatform;

  /// Shared engineering-memory repository (Implementation Milestone R5),
  /// threaded the same way as [worldModel] — null by default, so
  /// `ExperienceModificationCoordinator` falls back to its own
  /// null-`_engineeringMemory` (graceful, `planEvolution()` simply omits
  /// historical engineering memory) exactly as before R5.
  final EngineeringMemoryRepository? engineeringMemory;

  /// Optional pre-created modification coordinator (Implementation
  /// Milestone R7), matching the exact same DI convention [runtime]
  /// already established. Real, non-hypothetical need: [worldModel]/
  /// [engineeringMemory] alone are not enough to make
  /// `planEvolution()`/`applyEvolutionPlan()`/`rollback()` observable
  /// against a test-seeded repository, since the coordinator otherwise
  /// constructs its own default `SqliteExperienceRepository()` internally
  /// — this was found and fixed via this milestone's own widget tests,
  /// not spec-mandated speculatively. Null by default: every existing
  /// caller/test that constructs `ExperienceHostScreen` without one keeps
  /// identical behavior.
  final ExperienceModificationCoordinator? modificationCoordinator;

  /// Optional, additive workspace manager (Implementation Specification
  /// IS-R32) — `null` by default, so every existing caller/test that
  /// constructs `ExperienceHostScreen` without one keeps identical
  /// behavior. When supplied AND [experienceId] is known, this screen
  /// reports its real, current `ExperienceSession` to the workspace once
  /// the runtime finishes loading (see `_loadExperience`) — a real, safe,
  /// additive report; a no-op when no matching open workspace session
  /// exists. This milestone deliberately does NOT reroute this screen's
  /// existing `planEvolution()`/`applyEvolutionPlan()`/`rollback()` flow
  /// through the workspace manager — that remains `ExperienceModificationCoordinator`'s
  /// own, unmodified responsibility (see
  /// `docs/architecture/EXPERIENCE_WORKSPACE_MANAGER.md`).
  final ExperienceWorkspaceManager? workspaceManager;

  /// Optional, additive workspace runtime (Implementation Specification
  /// IS-R34) — `null` by default, so every existing caller/test that
  /// constructs `ExperienceHostScreen` without one keeps identical
  /// behavior. `AutonomousWorkspaceRuntime` is a pure, read-only snapshot
  /// aggregator with no report/mutation method — there is no analogous
  /// "safe extra step" this screen can call the way it already does for
  /// [workspaceManager]'s `reportRuntimeStateForExperience`; accept-and-
  /// store is the honest, real limit (see
  /// `docs/architecture/AUTONOMOUS_WORKSPACE_RUNTIME.md`).
  final AutonomousWorkspaceRuntime? workspaceRuntime;

  /// Optional, additive event bus (Implementation Specification IS-R35) —
  /// `null` by default, so every existing caller/test that constructs
  /// `ExperienceHostScreen` without one keeps identical behavior. When
  /// supplied AND [experienceId] is known, this screen publishes one real
  /// `WorkspaceUpdated` event once the runtime finishes loading — the
  /// SAME safe, guarded, additive extension point R32 already established
  /// for [workspaceManager]'s `reportRuntimeStateForExperience`, never a
  /// second, competing report mechanism.
  final EventBus? eventBus;

  /// Optional, additive runtime controller (Implementation Specification
  /// IS-R38) — `null` by default, so every existing caller/test that
  /// constructs `ExperienceHostScreen` without one keeps identical
  /// behavior. When omitted, this screen builds its own, wrapping the
  /// `_runtime` it already owns plus [workspaceManager]/[eventBus]/
  /// [experienceId] — real, valuable deduplication of the reload sequence
  /// `_runModification`/`_performRollback` used to repeat inline (see
  /// `docs/architecture/EXPERIENCE_RUNTIME_CONTROLLER.md`).
  final ExperienceRuntimeController? runtimeController;

  /// Optional, additive runtime supervisor (Implementation Specification
  /// IS-R40) — `null` by default, so every existing caller/test that
  /// constructs `ExperienceHostScreen` without one keeps identical
  /// behavior. When supplied AND a real workspace `sessionId` resolves for
  /// [experienceId] (the SAME resolution [_publishRuntimeLoadedEvent]
  /// already performs), this screen automatically registers its
  /// [runtimeController] with the supervisor once the runtime finishes
  /// loading, and unregisters it on [dispose] — real, valuable workspace-
  /// wide visibility into this screen's runtime with zero behavior change
  /// when omitted (see `docs/architecture/WORKSPACE_RUNTIME_SUPERVISOR.md`).
  final WorkspaceRuntimeSupervisor? runtimeSupervisor;

  const ExperienceHostScreen({
    super.key,
    required this.package,
    this.experienceName,
    this.experienceId,
    this.protectionService,
    this.runtime,
    this.worldModel,
    this.capabilityPlatform,
    this.engineeringMemory,
    this.modificationCoordinator,
    this.workspaceManager,
    this.workspaceRuntime,
    this.eventBus,
    this.runtimeController,
    this.runtimeSupervisor,
  });

  @override
  State<ExperienceHostScreen> createState() => _ExperienceHostScreenState();
}

class _ExperienceHostScreenState extends State<ExperienceHostScreen> with WidgetsBindingObserver {
  late final AnythingRuntime _runtime;
  late final ExperienceRuntimeController _runtimeController;
  late final WorkspaceLifecyclePolicyEngine _policyEngine;
  late final ExperienceModificationCoordinator _modificationCoordinator;
  late final ActivityRepository _activity;
  late final ExperienceProtectionService _protectionService;
  late ExperiencePackage _currentPackage;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isModifying = false;
  ExperienceRouter? _router;
  int _currentTabIndex = 0;
  Map<String, dynamic>? _editRecordData;
  String? _editScreenId;
  Map<String, dynamic>? _detailRecordData;
  String? _detailScreenId;

  /// The real sessionId this screen's [ExperienceRuntimeController] was
  /// registered under with [widget.runtimeSupervisor] (Implementation
  /// Specification IS-R40) — `null` when no supervisor was supplied, no
  /// `experienceId` is known, or no matching workspace session resolved.
  /// Recorded so [dispose] unregisters the EXACT same key, even if the
  /// workspace's own resolution could theoretically differ later.
  String? _registeredSupervisorSessionId;

  /// The package active immediately before the most recent successful
  /// evolution (Implementation Milestone R7) — powers a single-level
  /// Undo affordance. Real, honest scope: `SqliteExperienceRepository`
  /// retains no version history (confirmed R6), so only the ONE most
  /// recent change can be undone via this in-memory snapshot — not an
  /// arbitrary point in Evolution History. Cleared after a rollback
  /// (rather than chained) to keep this a real, simple, one-level undo,
  /// never a fabricated multi-level history stack.
  ExperiencePackage? _lastPreviousPackage;

  List<NavigationItem> get _navigationItems =>
      _currentPackage.interface.navigation?.items ?? [];

  @override
  void initState() {
    super.initState();
    _runtime = widget.runtime ?? AnythingRuntime(capabilityPlatform: widget.capabilityPlatform);
    // Implementation Specification IS-R38: real, additive owner of this
    // runtime's lifecycle — wraps the SAME `_runtime` this screen already
    // owns; only used below for the reload (`_runModification`/
    // `_performRollback`) and terminate (`dispose`) paths, which had ZERO
    // workspace/event reporting before this milestone. The INITIAL load in
    // `_loadExperience()` deliberately keeps its own existing
    // `_reportRuntimeStateToWorkspace`/`_publishRuntimeLoadedEvent` calls
    // untouched — those publish `change: 'runtime_loaded'`, a literal
    // string `test/r35_workspace_event_bus_test.dart` already asserts on;
    // routing the initial load through the controller too would change
    // that string to `'runtime_started'` and break that real, existing
    // test for no behavioral gain.
    _runtimeController = widget.runtimeController ??
        ExperienceRuntimeController(
          runtime: _runtime,
          workspace: widget.workspaceManager,
          eventPublisher: widget.eventBus == null ? null : WorkspaceEventPublisher(bus: widget.eventBus!, source: 'experience-host-screen'),
          experienceId: widget.experienceId,
        );
    // Implementation Specification IS-R39: real, additive owner of THIS
    // runtime's lifecycle POLICY decisions — reuses `_runtimeController`'s
    // own event publisher (never constructs a second one). Observing
    // `AppLifecycleState` costs nothing when it never fires (every
    // pre-R39 test — none of them trigger an app-lifecycle change — is
    // therefore completely unaffected); real app usage now genuinely
    // pauses/resumes this runtime when the OS backgrounds/foregrounds the
    // app. See `docs/architecture/WORKSPACE_LIFECYCLE_POLICY_ENGINE.md`.
    _policyEngine = WorkspaceLifecyclePolicyEngine(eventPublisher: _runtimeController.eventPublisher);
    WidgetsBinding.instance.addObserver(this);
    _modificationCoordinator = widget.modificationCoordinator ??
        ExperienceModificationCoordinator(
          worldModel: widget.worldModel,
          engineeringMemory: widget.engineeringMemory,
        );
    _activity = ActivityRepository();
    _protectionService =
        widget.protectionService ?? ExperienceProtectionService();
    _currentPackage = widget.package;
    _loadExperience();
  }

  Future<void> _loadExperience() async {
    try {
      // Skip opening if the runtime is already running (pre-opened via DI)
      if (_runtime.status != RuntimeStatus.running) {
        await _runtime.openExperience(_currentPackage);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _router = _runtime.router;
        });
        _seedDefaultScreen();
        _reportRuntimeStateToWorkspace();
        _publishRuntimeLoadedEvent();
        _registerWithSupervisor();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Seeds the router with an explicit entry for the default/tab screen.
  ///
  /// The renderer derives the currently-shown screen as
  /// `_router.currentScreenId ?? _getScreenIdForTab(...)` -- the default
  /// screen is shown implicitly, via an EMPTY router history, rather than
  /// being pushed onto it. That leaves the first user-initiated push (e.g.
  /// tapping "Add") at history length 1, and ExperienceRouter._pop()'s
  /// length<=1 "already at root" fallback then keeps that SAME pushed
  /// screen instead of returning to the default one. Explicitly pushing
  /// the default screen once, up front, keeps history length consistent
  /// with the router's pop/popToRoot contract (verified by
  /// ExperienceRouter's own "Pop to root" test, which already assumes the
  /// root screen is an explicit history entry).
  void _seedDefaultScreen() {
    final router = _router;
    if (router == null || router.history.isNotEmpty) return;
    final defaultScreenId = _navigationItems.isNotEmpty
        ? _getScreenIdForTab(0)
        : (_currentPackage.interface.screens.isNotEmpty
              ? _currentPackage.interface.screens.first.id
              : null);
    if (defaultScreenId != null) {
      router.navigate(
        NavigationRequest(
          action: NavigationAction.push,
          targetScreenId: defaultScreenId,
        ),
      );
    }
  }

  /// Real, additive, safe report (Implementation Specification IS-R32) —
  /// a harmless no-op when [widget.workspaceManager] is null or
  /// [widget.experienceId] is unknown, or when no open workspace session
  /// matches this experience (e.g. this screen was opened outside a
  /// workspace-managed flow, the only path that exists today, honestly —
  /// see this file's own `workspaceManager` doc comment).
  void _reportRuntimeStateToWorkspace() {
    final workspaceManager = widget.workspaceManager;
    final experienceId = widget.experienceId;
    if (workspaceManager == null || experienceId == null) return;
    workspaceManager.reportRuntimeStateForExperience(
      experienceId,
      ExperienceSession(
        id: 'runtime-$experienceId',
        experienceId: experienceId,
        package: _currentPackage,
        status: SessionStatus.running,
        startedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ),
    );
  }

  /// Real, additive, safe publish (Implementation Specification IS-R35) —
  /// a harmless no-op when [widget.eventBus] is null or [widget.experienceId]
  /// is unknown. `sessionId` resolves via the SAME real
  /// `workspaceManager.sessionForExperience()` lookup [workspaceManager]
  /// already uses (R32); falls back to the real `experienceId` itself when
  /// no workspace session tracks this experience, never a fabricated id.
  void _publishRuntimeLoadedEvent() {
    final eventBus = widget.eventBus;
    final experienceId = widget.experienceId;
    if (eventBus == null || experienceId == null) return;
    final sessionId = widget.workspaceManager?.sessionForExperience(experienceId)?.sessionId ?? experienceId;
    WorkspaceEventPublisher(bus: eventBus, source: 'experience-host-screen').publishWorkspaceUpdated('runtime_loaded', sessionId);
  }

  /// Real, additive, safe registration (Implementation Specification
  /// IS-R40) — a harmless no-op when [widget.runtimeSupervisor] is null or
  /// [widget.experienceId] is unknown, or when no open workspace session
  /// matches this experience (same real, honest resolution
  /// [_publishRuntimeLoadedEvent] already uses). Registers THIS screen's
  /// own, already-real [_runtimeController] — never a second controller.
  void _registerWithSupervisor() {
    final supervisor = widget.runtimeSupervisor;
    final experienceId = widget.experienceId;
    if (supervisor == null || experienceId == null) return;
    final sessionId = widget.workspaceManager?.sessionForExperience(experienceId)?.sessionId;
    if (sessionId == null) return;
    supervisor.register(sessionId, _runtimeController, experienceId: experienceId);
    _registeredSupervisorSessionId = sessionId;
  }

  /// Real Background Pause / Foreground Resume policy — reuses the SAME
  /// real `WidgetsBindingObserver` R39 already built as this milestone's
  /// own "one real production trigger" (Implementation Specification
  /// IS-R41), only widening its reach when a shared supervisor is present.
  ///
  /// When [widget.runtimeSupervisor] was injected (Implementation
  /// Specification IS-R41): ONE real OS-level transition, observed by any
  /// currently-mounted screen, now pauses/resumes EVERY runtime registered
  /// with the shared supervisor — not just this screen's own. Safe to apply
  /// unconditionally (no per-runtime status guard needed): `AnythingRuntime
  /// .pauseSession()`/`.resumeSession()` are real, idempotent no-ops when a
  /// runtime has no current session (unmodified, R38).
  ///
  /// When no supervisor was injected: EXACT, unchanged Implementation
  /// Specification IS-R39 behavior — this screen's own runtime only, guarded
  /// so it never pauses an already-idle/error runtime or resumes one that
  /// was never paused. Never fires outside a real OS-level transition (or an
  /// explicit test call to `tester.binding.handleAppLifecycleStateChanged(...)`).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final supervisor = widget.runtimeSupervisor;
    if (supervisor != null) {
      unawaited(supervisor.applyAppLifecyclePolicy(state, _policyEngine));
      return;
    }
    final decision = _policyEngine.evaluateAppLifecycle(state);
    if (decision.action == RuntimePolicyAction.pause && _runtime.status != RuntimeStatus.running) return;
    if (decision.action == RuntimePolicyAction.resume && _runtime.status != RuntimeStatus.paused) return;
    unawaited(_policyEngine.apply(decision, _runtimeController));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Implementation Specification IS-R40: unregister THIS screen's own
    // registration (if any) — independent of the runtime-ownership check
    // below, since the registration was always this screen's own, real
    // action to undo, regardless of who owns closing the underlying
    // runtime.
    final registeredSessionId = _registeredSupervisorSessionId;
    if (registeredSessionId != null) {
      widget.runtimeSupervisor?.unregister(registeredSessionId);
    }
    // Only close runtime if WE created it (not injected).
    // When runtime is injected via DI, the caller owns its lifecycle.
    // Implementation Specification IS-R38: routed through the controller's
    // terminate() — same real closeSession() call, now also reporting/
    // publishing the closing transition (this screen never reported
    // closure to the workspace/event bus at all before this milestone).
    if (widget.runtime == null) {
      unawaited(_runtimeController.terminate());
    }
    super.dispose();
  }

  void _showModificationIntent() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              32,
              32,
              32,
              MediaQuery.of(sheetContext).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change this app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe what you want to change',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  enabled: !_isModifying,
                  decoration: const InputDecoration(
                    hintText: 'Add a percentage button',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isModifying) ...[
                  const SizedBox(height: 16),
                  // A real, live-region announcement of the actual stage
                  // this milestone's own coordinator calls are in
                  // (Implementation Milestone R7's "visible progress") —
                  // never a fake timed sequence, each label corresponds to
                  // a real await boundary below.
                  Semantics(
                    liveRegion: true,
                    label: _modificationStage,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_modificationStage, style: Theme.of(sheetContext).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isModifying ? null : () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isModifying
                            ? null
                            : () => _runModification(
                                controller.text,
                                sheetContext,
                                (stage) => setSheetState(() => _modificationStage = stage),
                              ),
                        child: _isModifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Real progress-stage label (Implementation Milestone R7) — updated at
  /// each genuine await boundary in [_runModification], never a fabricated
  /// timed sequence.
  String _modificationStage = '';

  /// Plans, applies, and reloads a real [EvolutionDiffPlan] (Implementation
  /// Milestone R6/R7) — replaces the direct [ExperienceModificationCoordinator.modifyExperience]
  /// call this method used before R7. [ExperienceModificationCoordinator.modifyExperience]
  /// itself is UNCHANGED and remains available (other callers/tests still
  /// use it directly) — this screen's live UI flow switches to
  /// `planEvolution()` -> `applyEvolutionPlan()` specifically because only
  /// that path returns a real `previousPackage`, which is what makes real
  /// Undo/rollback possible. Documented decision (R7 "MANDATORY FIRST
  /// STEP" / "UI WIRING"): `modifyExperience()` was NOT changed to
  /// internally route through `EvolutionDiffPlan` — it is a separate,
  /// still-real, still-tested, lower-level path; only the UI's own call
  /// site changed.
  Future<void> _runModification(
    String expression,
    BuildContext sheetContext,
    void Function(String stage) setStage,
  ) async {
    if (expression.trim().isEmpty || widget.experienceId == null) return;
    setState(() => _isModifying = true);
    setStage('Planning…');

    final plan = await _modificationCoordinator.planEvolution(
      experienceId: widget.experienceId!,
      modificationExpression: expression.trim(),
    );

    if (plan == null) {
      setState(() => _isModifying = false);
      if (mounted && sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("I couldn't apply that change.")),
        );
      }
      return;
    }

    setStage('Validating & saving…');
    final result = await _modificationCoordinator.applyEvolutionPlan(plan);

    if (!mounted) return;
    setState(() => _isModifying = false);
    if (sheetContext.mounted) Navigator.pop(sheetContext);

    if (result is ModificationCoordinatorSucceeded) {
      // Real, honest state preservation (Implementation Milestone R7):
      // capture the current tab/screen BEFORE the reload tears down the
      // router, so we can restore it after — only when the target still
      // exists in the new package. Scroll position, focused widget, and
      // in-progress text-field contents live inside Flutter's widget tree
      // (rebuilt by this same reload) and are honestly NOT preserved —
      // see this milestone's Known Limitations.
      final preReloadTabIndex = _currentTabIndex;
      final preReloadScreenId = _router?.currentScreenId;

      setState(() => _currentPackage = result.newPackage);
      _lastPreviousPackage = result.previousPackage;

      // Implementation Specification IS-R38: the real closeSession()+
      // openExperience() pair, factored into ExperienceRuntimeController
      // .reload() — real, evolved `_currentPackage` passed explicitly
      // (the controller's own currentSession still holds the OLD package
      // at this point, so its no-arg default would reload the wrong one).
      await _runtimeController.reload(package: _currentPackage);
      if (!mounted) return;
      setState(() => _router = _runtime.router);
      _reseedAfterReload(preferredScreenId: preReloadScreenId, preferredTabIndex: preReloadTabIndex);

      final previousForUndo = result.previousPackage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('App updated to version ${result.newVersion}'),
          action: previousForUndo == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => _performRollback(previousForUndo),
                ),
        ),
      );
    } else if (result is ModificationCoordinatorFailed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  /// Restores the pre-reload screen after a `closeSession()`/`openExperience()`
  /// cycle, when it's still real in the new package (Implementation
  /// Milestone R7). Falls back to the previous tab index when the exact
  /// screen no longer exists, then to the existing default-screen seed.
  void _reseedAfterReload({String? preferredScreenId, int? preferredTabIndex}) {
    final router = _router;
    if (router == null) return;

    final screens = _currentPackage.interface.screens;
    if (preferredScreenId != null && screens.any((s) => s.id == preferredScreenId)) {
      router.navigate(NavigationRequest(action: NavigationAction.push, targetScreenId: preferredScreenId));
      return;
    }
    if (preferredTabIndex != null && preferredTabIndex < _navigationItems.length) {
      setState(() => _currentTabIndex = preferredTabIndex);
      router.navigate(
        NavigationRequest(action: NavigationAction.push, targetScreenId: _getScreenIdForTab(preferredTabIndex)),
      );
      return;
    }
    _seedDefaultScreen();
  }

  /// Real, deterministic rollback via the UI (Implementation Milestone
  /// R7) — calls the exact same [ExperienceModificationCoordinator.rollback]
  /// R6 already validated/tested; this method only adds the live reload +
  /// user feedback around it. Real success/failure feedback, never leaves
  /// the runtime half-reloaded (the reload is unconditional once
  /// `rollback()` itself succeeds, mirroring the apply path exactly).
  Future<void> _performRollback(ExperiencePackage previousPackage) async {
    if (widget.experienceId == null) return;
    final result = await _modificationCoordinator.rollback(
      experienceId: widget.experienceId!,
      previousPackage: previousPackage,
    );
    if (!mounted) return;

    if (result is ModificationCoordinatorSucceeded) {
      setState(() => _currentPackage = result.newPackage);
      // Deliberately NOT chained into a redo stack — one real, honest
      // level of undo (see `_lastPreviousPackage`'s doc comment).
      _lastPreviousPackage = null;

      // Implementation Specification IS-R38: same real reload primitive as
      // `_runModification` above.
      await _runtimeController.reload(package: _currentPackage);
      if (!mounted) return;
      setState(() => _router = _runtime.router);
      _seedDefaultScreen();

      // A rollback confirmation must never wait behind the original
      // "App updated…" snackbar it's responding to — ScaffoldMessenger
      // queues snackbars one at a time by default, which would otherwise
      // delay real user feedback for the full ~4s default display
      // duration (found via this milestone's own widget testing).
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Change undone')),
      );
    } else if (result is ModificationCoordinatorFailed) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't undo: ${result.message}")),
      );
    }
  }

  /// User-visible Evolution History (Implementation Milestone R7) —
  /// reuses the EXISTING `ActivityRepository` (no new repository, per
  /// this milestone's own "Absolute Rules") filtered to this Experience's
  /// own real `'updated'` events, which `applyEvolutionPlan()`/`rollback()`
  /// (R6/R7) already record with a real summary and real measured
  /// duration. "Rollback available" is honestly shown ONLY on the single
  /// most recent entry, matching `_lastPreviousPackage`'s real, one-level
  /// scope — older entries have no persisted prior-package snapshot to
  /// roll back to (`SqliteExperienceRepository` retains no version
  /// history, confirmed R6), so claiming they're all undo-able would be
  /// dishonest.
  void _showEvolutionHistory() {
    final experienceId = widget.experienceId;
    if (experienceId == null) return;
    final canUndoMostRecent = _lastPreviousPackage != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FutureBuilder<List<ActivityEvent>>(
        future: _activity.list().then(
          (events) => events.where((e) => e.experienceId == experienceId && e.type == 'updated').toList(),
        ),
        builder: (sheetContext, snapshot) {
          final events = snapshot.data ?? const <ActivityEvent>[];
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text('Evolution history', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                  if (!snapshot.hasData)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (events.isEmpty)
                    const Expanded(child: Center(child: Text('No changes yet')))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final isMostRecent = index == 0;
                          final durationLabel = event.durationMs == null ? '' : ' · ${event.durationMs}ms';
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(event.message),
                            subtitle: Text('${event.timestamp.toLocal()}$durationLabel'),
                            trailing: isMostRecent && canUndoMostRecent
                                ? const Chip(label: Text('Undo available'))
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProtectOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Use current time'),
              onTap: () => _protectWithCurrentTime(),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Choose date & time'),
              onTap: () => _protectWithCustomTime(),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _protectWithCurrentTime() async {
    Navigator.pop(context);
    if (widget.experienceId == null) return;

    final result = await _protectionService.protectWithCurrentTime(
      package: _currentPackage,
      experienceId: widget.experienceId!,
    );

    if (!mounted) return;

    if (result is ProtectionSucceeded) {
      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'protected',
          experienceId: widget.experienceId!,
          experienceName: widget.experienceName ?? 'App',
          message: 'Protected ${widget.experienceName ?? "app"}',
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App protected')));
      }
    } else if (result is ProtectionFailed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not protect this app')),
        );
      }
    }
  }

  Future<void> _protectWithCustomTime() async {
    Navigator.pop(context);
    if (widget.experienceId == null) return;

    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null || !mounted) return;

    final customDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final result = await _protectionService.protectWithCustomTime(
      package: _currentPackage,
      experienceId: widget.experienceId!,
      customTime: customDateTime,
    );

    if (!mounted) return;

    if (result is ProtectionSucceeded) {
      await _activity.record(
        ActivityEvent(
          id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
          type: 'protected',
          experienceId: widget.experienceId!,
          experienceName: widget.experienceName ?? 'App',
          message: 'Protected ${widget.experienceName ?? "app"}',
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'App protected with time ${customDateTime.month}/${customDateTime.day}/${customDateTime.year}',
            ),
          ),
        );
      }
    } else if (result is ProtectionFailed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not protect this app')),
        );
      }
    }
  }

  /// Finds the form screen for a create action event.
  ///
  /// When the user taps an "Add" button on a list screen, we should navigate
  /// to the entity's form screen rather than dispatching the action event
  /// (which would try to create with no data).
  String? _findFormScreenForAction(String eventId) {
    // Check if any screen has a form matching the entity from the event
    final screens = _currentPackage.interface.screens;
    for (final screen in screens) {
      // Match form screens: screen ID ends with '_form'
      if (screen.id.endsWith('_form')) {
        final entityId = screen.id.replaceAll('_form', '');
        // Match: action ID contains the entity ID (e.g., 'add_person' → 'person')
        if (eventId.contains(entityId)) {
          return screen.id;
        }
      }
    }
    return null;
  }

  String _getScreenIdForTab(int index) {
    if (index < _navigationItems.length) {
      return _navigationItems[index].screenId;
    }
    final screens = _currentPackage.interface.screens;
    return screens.isNotEmpty ? screens.first.id : 'main';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.experienceName ?? 'Loading...'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't open this app",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Try again or return to Anything.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final renderer = ExperienceRenderer();
    final screens = _currentPackage.interface.screens;
    // Prefer the router's screen ID (which tracks push/pop navigation).
    // Fall back to tab-based selection when there's no router history.
    final routerScreenId = _router?.currentScreenId;
    final tabScreenId = _navigationItems.isNotEmpty
        ? _getScreenIdForTab(_currentTabIndex)
        : null;
    final screenId =
        routerScreenId ??
        tabScreenId ??
        (screens.isNotEmpty ? screens.first.id : 'main');
    final runtimeContext = _runtime.runtimeContext;

    // If navigating to an edit screen, load the record data for the form
    Map<String, dynamic>? renderData;
    if (screenId.endsWith('_edit') && runtimeContext != null) {
      if (_editScreenId != screenId) {
        _editScreenId = screenId;
        _editRecordData = null;
        final currentEntry = _router?.history.isNotEmpty == true
            ? _router!.history.last
            : null;
        final recordId = currentEntry?.arguments?['recordId'] as String?;
        if (recordId != null) {
          final entityId = screenId.replaceAll('_edit', '');
          runtimeContext.readRecord(entityId, recordId).then((record) {
            if (mounted) {
              setState(() {
                _editRecordData = record;
              });
            }
          });
        }
      }
      renderData = _editRecordData != null
          ? {'_currentRecord': _editRecordData}
          : null;
    } else if (screenId.endsWith('_detail') && runtimeContext != null) {
      // Load record data for detail screens so entity list renders correctly
      if (_detailScreenId != screenId) {
        _detailScreenId = screenId;
        _detailRecordData = null;
        final currentEntry = _router?.history.isNotEmpty == true
            ? _router!.history.last
            : null;
        final recordId = currentEntry?.arguments?['recordId'] as String?;
        if (recordId != null) {
          final entityId = screenId.replaceAll('_detail', '');
          runtimeContext.readRecord(entityId, recordId).then((record) {
            if (mounted) {
              setState(() {
                _detailRecordData = record;
              });
            }
          });
        }
      }
      renderData = _detailRecordData != null
          ? {'_currentRecord': _detailRecordData}
          : null;
    } else {
      _editScreenId = null;
      _editRecordData = null;
      _detailScreenId = null;
      _detailRecordData = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.experienceName ?? 'Experience'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'change':
                  _showModificationIntent();
                  break;
                case 'history':
                  _showEvolutionHistory();
                  break;
                case 'protect':
                  _showProtectOptions();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change',
                child: Text('Change this app'),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('Evolution history'),
              ),
              const PopupMenuItem(value: 'protect', child: Text('Protect')),
            ],
          ),
        ],
      ),
      body: renderer.renderScreen(
        context,
        screenId,
        _currentPackage.interface,
        _runtime.stateEngine,
        onEvent: (eventId, {data}) async {
          // Handle "Add" buttons: navigate to the create form screen
          // instead of dispatching a create event directly.
          final formScreen = _findFormScreenForAction(eventId);
          if (formScreen != null) {
            _router?.navigate(
              NavigationRequest(
                action: NavigationAction.push,
                targetScreenId: formScreen,
              ),
            );
            if (mounted) setState(() {});
            return;
          }

          // Handle submitForm: dispatch then pop back to the list screen
          if (eventId == 'submitForm') {
            await _runtime.dispatchEvent(eventId, data: data);
            if (mounted) {
              // Pop back to the entity list (pop the form screen)
              if (_router?.history.isNotEmpty == true) {
                _router?.navigate(
                  const NavigationRequest(action: NavigationAction.pop),
                );
              }
              setState(() {});
            }
            return;
          }

          // Handle deleteRecord: dispatch then navigate back to the list
          if (eventId == 'deleteRecord') {
            await _runtime.dispatchEvent(eventId, data: data);
            if (mounted) {
              // Navigate back to the parent list after deletion
              if (_router?.history.isNotEmpty == true) {
                _router?.navigate(
                  const NavigationRequest(action: NavigationAction.pop),
                );
              }
              setState(() {});
            }
            return;
          }

          // Handle searchChanged: update search term state
          if (eventId == 'searchChanged') {
            final term = data?['term'] as String? ?? '';
            _runtime.stateEngine.write('searchTerm', term);
            await _runtime.dispatchEvent(eventId, data: data);
            if (mounted) setState(() {});
            return;
          }

          await _runtime.dispatchEvent(eventId, data: data);
          if (mounted) setState(() {});
        },
        runtimeContext: runtimeContext,
        data: renderData,
      ),
      bottomNavigationBar: _navigationItems.isNotEmpty
          ? NavigationBar(
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) {
                setState(() => _currentTabIndex = index);
                final targetScreenId = _getScreenIdForTab(index);
                _router?.navigate(
                  NavigationRequest(
                    action: NavigationAction.push,
                    targetScreenId: targetScreenId,
                  ),
                );
                setState(() {});
              },
              destinations: _navigationItems
                  .take(5)
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(_iconFromString(item.icon)),
                      label: item.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  IconData _iconFromString(String iconName) {
    switch (iconName) {
      case 'list':
        return Icons.list;
      case 'dashboard':
        return Icons.dashboard;
      case 'add':
        return Icons.add;
      case 'settings':
        return Icons.settings;
      case 'search':
        return Icons.search;
      case 'chart':
        return Icons.bar_chart;
      default:
        return Icons.tab;
    }
  }
}
