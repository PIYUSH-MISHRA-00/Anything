/// Workspace Experience Switcher — Implementation Specification IS-R43/R44.
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
/// This Switcher now routes its "select a background session" action
/// through `activationManager.activate()` — the real runtime effect
/// (target resumes, siblings pause) AND real navigation (revealing that
/// session's actual, already-running screen) both happen for real. Building
/// the target route reuses the SAME real, already-running
/// `ExperienceRuntimeController`/`AnythingRuntime` the background session's
/// own screen instance is using (via `WorkspaceRuntimeSupervisor.lookup()`),
/// injected through `ExperienceHostScreen`'s established `runtime:`/
/// `runtimeController:` DI parameters — never a freshly-constructed one.
library;

import 'package:flutter/material.dart';

import '../../app/autonomous_workspace_runtime.dart';
import '../../app/experience_activation_manager.dart';
import '../../app/experience_workspace_manager.dart';
import '../../app/workspace_runtime_supervisor.dart';
import '../../app/workspace_scheduling_engine.dart';
import '../../runtime/experience_host_screen.dart';

/// Opens the Workspace Experience Switcher as a modal bottom sheet — the
/// same `showModalBottomSheet` pattern `ExperienceHostScreen` already uses
/// for its own "Change this app"/"Evolution history" sheets.
Future<void> showWorkspaceSwitcher(
  BuildContext context,
  WorkspaceSchedulingEngine scheduler, {
  required ExperienceActivationManager activationManager,
  required WorkspaceRuntimeSupervisor runtimeSupervisor,
  ExperienceWorkspaceManager? workspaceManager,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => WorkspaceSwitcherSheet(
      scheduler: scheduler,
      activationManager: activationManager,
      runtimeSupervisor: runtimeSupervisor,
      workspaceManager: workspaceManager,
    ),
  );
}

/// The real Switcher UI — a real, independently-pumpable widget (never
/// hidden inside a builder closure only) so it can be tested directly.
class WorkspaceSwitcherSheet extends StatefulWidget {
  final WorkspaceSchedulingEngine scheduler;
  final ExperienceActivationManager activationManager;
  final WorkspaceRuntimeSupervisor runtimeSupervisor;

  /// Optional — threaded into the revealed `ExperienceHostScreen` the same
  /// way `HomeScreen`'s own call sites already do; `null` is a safe,
  /// honest default (matches every other optional DI field in this
  /// codebase).
  final ExperienceWorkspaceManager? workspaceManager;

  const WorkspaceSwitcherSheet({
    super.key,
    required this.scheduler,
    required this.activationManager,
    required this.runtimeSupervisor,
    this.workspaceManager,
  });

  @override
  State<WorkspaceSwitcherSheet> createState() =>
      _WorkspaceSwitcherSheetState();
}

class _WorkspaceSwitcherSheetState extends State<WorkspaceSwitcherSheet> {
  /// "Refresh workspace state" — a real, on-demand re-read via `setState()`
  /// (`foregroundExperience()`/`backgroundExperiences()` are pure,
  /// synchronous reads, not a stream/listenable — this codebase has never
  /// used a reactive state-management framework for workspace state and
  /// this milestone does not introduce one).
  void _refresh() => setState(() {});

  /// Selects a background session — real runtime activation AND real
  /// navigation, through the one real `ExperienceActivationManager`
  /// (Implementation Specification IS-R44). Falls back to the real,
  /// honest R43 behavior (schedule only + a snackbar) when the session's
  /// real runtime/package is unavailable — a real, honest edge case
  /// (e.g. the session is tracked by the workspace but was never
  /// registered with the supervisor), never a fabricated navigation.
  Future<void> _selectForeground(String sessionId, String? name, SessionRuntimeStatus session) async {
    final controller = widget.runtimeSupervisor.lookup(sessionId);
    final package = session.runtimeState?.package;

    if (controller == null || package == null) {
      await widget.scheduler.scheduleForeground(sessionId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${name ?? 'app'}. Reopen it from Recent to view.')),
      );
      return;
    }

    // Capture the real, stable NavigatorState BEFORE popping this sheet —
    // this widget's own `context` becomes unusable once its route is
    // popped, but the NavigatorState itself (the same one HomeScreen's own
    // real navigation call sites use) remains valid.
    final navigator = Navigator.of(context);
    navigator.pop();
    await widget.activationManager.activate(
      navigator,
      sessionId,
      createRoute: () => MaterialPageRoute(
        builder: (_) => ExperienceHostScreen(
          package: package,
          experienceName: session.experienceName,
          experienceId: session.experienceId,
          workspaceManager: widget.workspaceManager,
          runtime: controller.runtime,
          runtimeController: controller,
          // Deliberately NOT `widget.runtimeSupervisor`: [controller] was
          // resolved via that SAME supervisor's own `lookup(sessionId)`,
          // meaning it is already registered — `ExperienceHostScreen
          // ._registerWithSupervisor()` (unmodified) always calls
          // `register()` unconditionally when a supervisor is supplied,
          // which would throw the real `StateError`
          // `WorkspaceRuntimeSupervisor.register()` (R40, unmodified)
          // raises on a duplicate sessionId. Omitting it here is the real,
          // minimal fix — no change to `ExperienceHostScreen` itself.
          scheduler: widget.scheduler,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final SessionRuntimeStatus? active = widget.scheduler.foregroundExperience();
    final List<SessionRuntimeStatus> background = widget.scheduler.backgroundExperiences();

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
                          title: Text(active.experienceName ?? active.sessionId),
                          subtitle: const Text('Active'),
                          trailing: const Chip(label: Text('Foreground')),
                        ),
                      for (final session in background)
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: Text(session.experienceName ?? session.sessionId),
                          subtitle: const Text('Background'),
                          onTap: () => _selectForeground(session.sessionId, session.experienceName, session),
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
