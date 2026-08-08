# Screen Reachability Matrix — IS-R59 Phase 4

Every file declaring a screen, classified by transitive import closure from the
single canonical entry point `lib/main.dart`.

**Canonical navigation root:** `lib/main.dart` -> `AnythingApp`
(`lib/app/app.dart`, the only `MaterialApp`) -> feature screens under
`lib/features/`.

**`lib/screens/` is a PARALLEL v1 set.** Every file in it is a Riverpod
`ConsumerWidget`/`ConsumerStatefulWidget`, and no `ProviderScope` exists
anywhere, so none of it can render. It is reached only from
`lib/screens/app_shell.dart`, which nothing outside that directory imports.

| File | Class | test refs | lib importers |
|---|---|---|---|
| `lib/features/activity/activity_screen.dart` | REACHABLE | 0 | 1 |
| `lib/features/experiences/experiences_screen.dart` | REACHABLE | 2 | 1 |
| `lib/features/home/home_screen.dart` | REACHABLE | 10 | 1 |
| `lib/features/preferences/preferences_screen.dart` | REACHABLE | 0 | 1 |
| `lib/features/preferences/provider_preferences_screen.dart` | REACHABLE | 0 | 1 |
| `lib/runtime/experience_host_screen.dart` | REACHABLE | 17 | 1 |
| `lib/screens/ai_settings_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/app_shell.dart` | EXPERIMENTAL | 0 | 2 |
| `lib/screens/groq_settings_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/groq_webview_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/kaalka_security_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/memory_dashboard_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/personal_context_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/skills_marketplace_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/templates_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/screens/workspace_screen.dart` | EXPERIMENTAL | 0 | 3 |
| `lib/screens/workspaces_screen.dart` | EXPERIMENTAL | 0 | 1 |
| `lib/widgets/ai_loading_screen.dart` | EXPERIMENTAL | 0 | 1 |

## Classification rule

| Class | Meaning |
|---|---|
| REACHABLE | an import chain from `main()` reaches it |
| DORMANT | unreachable from `main()`, but a test imports it |
| EXPERIMENTAL | unreachable and untested, but another `lib/` file imports it |
| DEAD | unreachable, untested, imported by nothing |
