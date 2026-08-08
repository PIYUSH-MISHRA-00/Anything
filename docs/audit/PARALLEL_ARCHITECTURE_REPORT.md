# Parallel Architecture Report — IS-R59 Phase 7

**Nothing in this report was deleted.** Phase 7 requires documentation; Phase 8
permits deletion only on proof, and this subsystem cannot be proven dead — it is
internally coherent and internally referenced.

## The finding

The repository contains **two application graphs**.

| | Canonical (v2) | Parallel (v1) |
|---|---|---|
| Entry | `lib/main.dart` → `AnythingApp` | `lib/screens/app_shell.dart` |
| App widget | `MaterialApp` in `lib/app/app.dart` | none — never mounted |
| Composition | `AppComposition.production()` | Riverpod providers |
| State | constructor injection | `Provider` / `ref.watch` |
| UI | `lib/features/**` (100% reachable) | `lib/screens/**` (0% reachable) |
| Reachable from `main()` | **yes** | **no** |

## Why the parallel graph cannot run

A Riverpod provider is resolved only inside a `ProviderScope`.
**No `ProviderScope` exists anywhere in `lib/` or `test/`** — `main.dart` calls
`runApp(const AnythingApp())` directly. Certified by **I-85**.

So all 17 Riverpod providers are unresolvable, and every screen depending on
them would throw if mounted.

## Extent

| Subsystem | Files | Class |
|---|---|---|
| `lib/screens/` | 11 | EXPERIMENTAL (2 were DEAD and deleted) |
| `lib/agents/` | 5 | EXPERIMENTAL |
| `lib/tools/` | 6 | EXPERIMENTAL |
| `lib/ui_engine/` | 4 | EXPERIMENTAL |
| `lib/memory/` | 2 | EXPERIMENTAL |
| `lib/core/` (context/intent/reasoning engines, error handler) | 4 | EXPERIMENTAL |
| `lib/services/` (groq, web search, file context) | 3 | EXPERIMENTAL |
| `lib/workflow/` | 2 | EXPERIMENTAL (1 was DEAD and deleted) |
| `lib/models/auil_schema_model.dart` | 1 | EXPERIMENTAL |
| `lib/security/encryption_manager.dart` | 1 | EXPERIMENTAL |
| `lib/core/contracts/` (capability, experience, kernel) | 3 | EXPERIMENTAL |

**~50 files.** They import each other, so none is individually orphaned — which
is exactly why none can be deleted under Phase 8's proof standard.

## Other parallel implementations — checked, none found

| Axis | Result |
|---|---|
| Runtime | one `AnythingRuntime`, one construction site |
| Navigation | one `MaterialApp`; no `GoRouter`, `RouterConfig` or `ShellRoute` anywhere |
| Composition | one `AppComposition` |
| Experience host | one `ExperienceHostScreen` |
| State management | Riverpod (unreachable) + plain `ChangeNotifier` (3 holders); no Bloc, Cubit or `InheritedWidget` |
| Capability / knowledge / workspace UI | single implementations |

## What R59 did NOT do, and why

It did not delete, revive, or migrate this subsystem. Deleting ~50 mutually
referencing files is not a proof-driven deletion, and the ABSOLUTE RULES forbid
migrating to or away from Riverpod. Adding a `ProviderScope` would revive all
of it at once — a deliberate architectural act, not a side effect, and I-85
now makes it impossible to do silently.

**Recorded as gap G-48. Recommended as the subject of IS-R60.**
