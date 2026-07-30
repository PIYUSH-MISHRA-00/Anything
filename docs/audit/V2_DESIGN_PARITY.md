# Anything v2.0.0 — Design Parity Matrix

Scope note: the dedicated design research agent for this audit was terminated mid-task by an account-level rate limit before delivering a screen-by-screen comparison. What follows is a structural finding from direct inspection (which screens are live vs. dead, what the design corpus actually contains) plus a scoping observation — not a full visual parity review. A dedicated design-parity pass is deferred to the roadmap (M3).

## 1. Design corpus scope

`design/stitch/product_foundation/` contains **~85 Stitch screen exports** (code.html + screen.png pairs), per `design/README.md` explicitly "the visual reference, not the implementation." The vast majority describe a long-horizon enterprise/developer-tooling vision far beyond v2.0.0 scope: capability registry dev-mode, developer CLI pipeline, enterprise governance, ecosystem marketplace, execution replay debugger, specialist orchestration, sync/continuity engine, trace observability, etc. Only a small subset corresponds to what v2.0.0's actual live screens need:

| Live app screen | Likely design reference(s) | Status |
|---|---|---|
| Home (intent input) | `anything_home`, `anything_home_dark_mode`, `anything_home_with_text_input_theme_toggle`, `anything_universal_intent_surface` | Not visually diffed this pass |
| My Apps / Experiences | `anything_my_apps_library` | Not visually diffed this pass |
| Activity | `anything_activity_timeline`, `anything_activity_versions` | Not visually diffed this pass |
| Preferences / Settings | `anything_preferences`, `anything_capabilities_preference_populated` | Not visually diffed this pass |
| Provider configuration | (no obvious 1:1 match found in the list; closest is `anything_model_registry_provider_abstraction_dev_mode`, which reads as a developer-mode reference rather than the end-user provider picker) | Needs clarification of canonical reference |
| Experience creation/birth ("cinematic" sequence per vision doc) | `anything_live_composition`, `anything_kernel_completion_experience` (candidates, not confirmed) | Not visually diffed this pass |
| Experience host (running a generated app) | `anything_experience_sessions_dev_mode`, `anything_experience_handoff` (candidates, not confirmed) | Not visually diffed this pass |
| Ambient Intelligence base theme (light/dark, indigo accent, pill controls) | `ambient_intelligence_1`, `ambient_intelligence_2`, `ambient_intelligence_dark`, `ambient_intelligence_system` | Partially checked — see §2 |

**Recommendation for the roadmap:** before doing a screen-by-screen visual diff, first get an explicit, current mapping (ideally in `docs/design/STITCH_IMPLEMENTATION_MAP.md`, which exists but was not re-verified for currency this pass) of exactly which ~10-15 of the 85 Stitch screens are canonical for v2.0.0 scope vs. long-term vision, so review effort isn't spent comparing production code against features that aren't planned yet.

## 2. Theme system — partial check

`lib/design_system/theme/anything_theme.dart` uses `useMaterial3: true` for both light and dark themes (verified, lines 46 and 158) — consistent with a modern "Ambient Intelligence" direction, but token-level values (exact indigo accent hex, pill-radius shape values, ambient-shadow definitions) were not diffed against the Stitch references this pass. One concrete, verified interaction with the design system: the default Material 3 theme uses the built-in ink-sparkle splash with no `splashFactory` override, which is both a minor design-consistency question (does the Stitch reference call for a sparkle ripple, or the flatter Material ripple?) and the direct cause of the local test-environment shader failures described in the Current State Audit (§7) and Test Evidence Matrix — worth resolving together.

## 3. Dead v1 UI code — VERIFIED, real finding

The live v2 app shell (`lib/app/app_shell.dart`, imported by `lib/app/app.dart`, imported by `lib/main.dart`) wires exactly four screens: `features/home/home_screen.dart`, `features/experiences/experiences_screen.dart`, `features/activity/activity_screen.dart`, `features/preferences/preferences_screen.dart`.

A **separate, unreferenced** `lib/screens/` directory (`app_shell.dart`, `workspace_screen.dart`, `workspaces_screen.dart`, `templates_screen.dart`, `memory_dashboard_screen.dart`, `ai_settings_screen.dart`, `groq_settings_screen.dart`, `groq_webview_screen.dart`, `kaalka_security_screen.dart`, `onboarding_screen.dart`, `personal_context_screen.dart`, `skills_marketplace_screen.dart`, `splash_screen.dart`) is **not imported from `main.dart`, `app/app.dart`, or the live `app/app_shell.dart`** (verified by import-graph tracing) — it is dead v1 code, including two files hardcoding the Groq provider by name (`groq_settings_screen.dart`, `groq_webview_screen.dart`), which is exactly the kind of vendor-specific hardcoding the v2 vision's BYOK principle prohibits. It is not currently reachable at runtime, so it is not a live product/security defect, but it is a real source of confusion (it likely explains why the stale README still describes Groq-specific behavior) and should be removed in a cleanup milestone rather than left to accumulate.

## 4. Accessibility — UNKNOWN

Not independently re-verified this pass. Flagged for the same milestone as the visual parity pass.

## 5. Tablet / responsive layout — UNKNOWN

Not independently re-verified this pass.
