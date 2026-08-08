# Feature Reachability Matrix — IS-R59 Phase 5

`lib/features/` is the canonical feature surface: every file below is
REACHABLE from `main()` through `AnythingApp`.

| File | Class | test refs | lib importers |
|---|---|---|---|
| `lib/features/activity/activity_screen.dart` | REACHABLE | 0 | 1 |
| `lib/features/experiences/experiences_screen.dart` | REACHABLE | 2 | 1 |
| `lib/features/home/home_screen.dart` | REACHABLE | 10 | 1 |
| `lib/features/home/intent_composer.dart` | REACHABLE | 4 | 1 |
| `lib/features/preferences/preferences_screen.dart` | REACHABLE | 0 | 1 |
| `lib/features/preferences/provider_preferences_screen.dart` | REACHABLE | 0 | 1 |
| `lib/features/workspace/workspace_switcher.dart` | REACHABLE | 2 | 1 |

**Result: no dormant, experimental or dead feature exists.** The feature layer
is fully canonical — a clean result, recorded as such.
