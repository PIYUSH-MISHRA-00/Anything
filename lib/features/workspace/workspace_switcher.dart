/// Workspace Experience Switcher — Implementation Specification IS-R43/R44/R45.
///
/// Displays currently-running Experiences (the real, active session and
/// every real background session) and lets the user select a background
/// session to bring to the foreground — through `WorkspaceSchedulingEngine`
/// (R42, unmodified), never by re-deriving workspace bookkeeping itself.
///
/// REALITY (confirmed by reading source before writing this file):
/// `WorkspaceRuntimeSupervisor.register()` (R40, unmodified) throws a real
/// `StateError` on a duplicate `sessionId` — and Flutter's `Navigator`
/// keeps earlier-pushed routes mounted (not disposed) when a later route is
/// pushed on top (R41's own established reality). Naively pushing a NEW
/// `ExperienceHostScreen` for a session whose original screen instance is
/// still mounted further down the stack would therefore throw on
/// re-registration. R43 deferred solving this; R44's `ExperienceActivationManager`
/// (`lib/app/experience_activation_manager.dart`, unmodified here) is the
/// real fix — it tracks the real, already-pushed `Route` per `sessionId` and
/// pops back to it instead of pushing a duplicate.
///
/// R45: the "select a background session" action's route-construction logic
/// (previously inline here) is now extracted into
/// `ExperienceEntryPipeline.activateRunningSession()` — the ONE, real,
/// canonical entry mechanism every production Experience-opening path flows
/// through, shared with `HomeScreen`'s own call sites. Zero behavior
/// change: this is a mechanical extraction of the exact same real logic
/// (reusing the SAME real, already-running `ExperienceRuntimeController`/
/// `AnythingRuntime` via `WorkspaceRuntimeSupervisor.lookup()`, injected
/// through `ExperienceHostScreen`'s established `runtime:`/
/// `runtimeController:` DI parameters — never a freshly-constructed one),
/// verified by this file's own, unchanged test assertions.
library;

import 'package:flutter/material.dart';

import '../../app/autonomous_workspace_runtime.dart';
import '../../app/experience_entry_pipeline.dart';
import '../../app/experience_orchestrator.dart';
import '../../app/workspace_scheduling_engine.dart';

/// Opens the Workspace Experience Switcher as a modal bottom sheet — the
/// same `showModalBottomSheet` pattern `ExperienceHostScreen` already uses
/// for its own "Change this app"/"Evolution history" sheets.
Future<void> showWorkspaceSwitcher(
  BuildContext context,
  WorkspaceSchedulingEngine scheduler, {
  required ExperienceEntryPipeline entryPipeline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => WorkspaceSwitcherSheet(
      scheduler: scheduler,
      entryPipeline: entryPipeline,
    ),
  );
}

/// The real Switcher UI — a real, independently-pumpable widget (never
/// hidden inside a builder closure only) so it can be tested directly.
class WorkspaceSwitcherSheet extends StatefulWidget {
  final WorkspaceSchedulingEngine scheduler;

  /// The unified entry pipeline (Implementation Specification IS-R45) —
  /// used both for its own `activateRunningSession()` (the real
  /// navigation step) and its carried `runtimeSupervisor` (to resolve the
  /// real, already-running controller for a selected background session).
  final ExperienceEntryPipeline entryPipeline;

  /// The ONE orchestrator (IS-R62). Additive and defaulted: before R62 the
  /// no-live-runtime branch below reached `scheduler.scheduleForeground()`
  /// DIRECTLY, bypassing the R45 entry pipeline entirely — one of the two
  /// bypasses the Phase 1 audit found. It now states an execution request and
  /// lets the orchestrator forward it, which for a `userInitiated` trigger
  /// with a real session is the same single scheduler call as before.
  final ExperienceOrchestrator? orchestrator;

  const WorkspaceSwitcherSheet({
    super.key,
    required this.scheduler,
    required this.entryPipeline,
    this.orchestrator,
  });

  @override
  State<WorkspaceSwitcherSheet> createState() => _WorkspaceSwitcherSheetState();
}

class _WorkspaceSwitcherSheetState extends State<WorkspaceSwitcherSheet> {
  /// "Refresh workspace state" — a real, on-demand re-read via `setState()`
  /// (`foregroundExperience()`/`backgroundExperiences()` are pure,
  /// synchronous reads, not a stream/listenable — this codebase has never
  /// used a reactive state-management framework for workspace state and
  /// this milestone does not introduce one).
  void _refresh() => setState(() {});

  /// Selects a background session — real runtime activation AND real
  /// navigation, through `ExperienceEntryPipeline.activateRunningSession()`
  /// (Implementation Specification IS-R45, extracted from this widget's own
  /// R44 logic verbatim). Falls back to the real, honest R43 behavior
  /// (schedule only + a snackbar) when the session's real runtime/package
  /// is unavailable — a real, honest edge case (e.g. the session is tracked
  /// by the workspace but was never registered with the supervisor), never
  /// a fabricated navigation.
  Future<void> _selectForeground(
    String sessionId,
    String? name,
    SessionRuntimeStatus session,
  ) async {
    final controller = widget.entryPipeline.runtimeSupervisor?.lookup(
      sessionId,
    );
    final package = session.runtimeState?.package;

    if (controller == null || package == null) {
      await (widget.orchestrator ??
              ExperienceOrchestrator(scheduler: widget.scheduler))
          .orchestrate(
            ExecutionRequest(
              trigger: ExecutionTrigger.workspaceSwitch,
              sessionId: sessionId,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(showCloseIcon: true, 
          content: Text(
            'Switched to ${name ?? 'app'}. Reopen it from Recent to view.',
          ),
        ),
      );
      return;
    }

    // Capture the real, stable NavigatorState BEFORE popping this sheet —
    // this widget's own `context` becomes unusable once its route is
    // popped, but the NavigatorState itself (the same one HomeScreen's own
    // real navigation call sites use) remains valid.
    final navigator = Navigator.of(context);
    navigator.pop();
    await widget.entryPipeline.activateRunningSession(
      navigator,
      sessionId,
      controller: controller,
      package: package,
      experienceId: session.experienceId,
      experienceName: session.experienceName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final SessionRuntimeStatus? active = widget.scheduler
        .foregroundExperience();
    final List<SessionRuntimeStatus> background = widget.scheduler
        .backgroundExperiences();

    // Bounded-height + scrollable, matching ExperienceHostScreen's own
    // established "Evolution history" bottom-sheet pattern exactly — an
    // unbounded Column here overflows once the sheet is hosted in a real
    // modal-bottom-sheet route (or any bounded ancestor), and a running
    // workspace can genuinely have more sessions than fit on screen.
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Running apps', style: theme.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                  ),
                ],
              ),
              if (active == null && background.isEmpty)
                const Expanded(
                  child: Center(child: Text('No apps are currently running.')),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (active != null)
                        ListTile(
                          leading: const Icon(Icons.auto_awesome),
                          title: Text(
                            active.experienceName ?? active.sessionId,
                          ),
                          subtitle: const Text('Active'),
                          trailing: const Chip(label: Text('Foreground')),
                        ),
                      for (final session in background)
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: Text(
                            session.experienceName ?? session.sessionId,
                          ),
                          subtitle: const Text('Background'),
                          onTap: () => _selectForeground(
                            session.sessionId,
                            session.experienceName,
                            session,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
