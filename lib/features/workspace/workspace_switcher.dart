/// Workspace Experience Switcher — Implementation Specification IS-R43.
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
/// re-registration. There is no `RouteSettings`/route-tagging convention
/// anywhere in this codebase to search the stack for an existing route
/// safely, and building one (a `NavigatorObserver`, real new app-shell
/// surface area) is beyond this milestone's honest, provable scope.
///
/// SCOPE DECISION: this Switcher invokes the real
/// `WorkspaceSchedulingEngine.scheduleForeground()` — the real runtime
/// effect (target resumes, siblings pause via the Inactive Runtime policy)
/// happens for real — but does NOT attempt to navigate to/reveal that
/// session's actual screen. Real, honest UI feedback (closes the sheet,
/// shows a snackbar) confirms the switch without a fabricated navigation.
/// Real navigation-based switching (bringing the target screen visually
/// into view) is deferred to R44 — see
/// `docs/architecture/WORKSPACE_EXPERIENCE_SWITCHER.md`.
library;

import 'package:flutter/material.dart';

import '../../app/autonomous_workspace_runtime.dart';
import '../../app/workspace_scheduling_engine.dart';

/// Opens the Workspace Experience Switcher as a modal bottom sheet — the
/// same `showModalBottomSheet` pattern `ExperienceHostScreen` already uses
/// for its own "Change this app"/"Evolution history" sheets.
Future<void> showWorkspaceSwitcher(
  BuildContext context,
  WorkspaceSchedulingEngine scheduler,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => WorkspaceSwitcherSheet(scheduler: scheduler),
  );
}

/// The real Switcher UI — a real, independently-pumpable widget (never
/// hidden inside a builder closure only) so it can be tested directly.
class WorkspaceSwitcherSheet extends StatefulWidget {
  final WorkspaceSchedulingEngine scheduler;

  const WorkspaceSwitcherSheet({super.key, required this.scheduler});

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

  Future<void> _selectForeground(String sessionId, String? name) async {
    await widget.scheduler.scheduleForeground(sessionId);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${name ?? 'app'}. Reopen it from Recent to view.')),
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
                          onTap: () => _selectForeground(session.sessionId, session.experienceName),
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
