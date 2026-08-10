# 03 — Dynamicity Certification

## Verdict: PASS

- **No domain factories** for named apps (stopwatch/calc/weather/news as hard-coded product classes).
- Creation uses **capability shells** (`DeterministicReasoner._tryCapabilityShellReasoning`) keyed by capability IDs from `IntentPreservationValidator.purposeFromPrompt`.
- **`test/dynamic/p21_hardcoding_probe_test.dart`** scans `lib/` for domain-factory / city hardcoding and mutation-detects injected hardcoding.
- **Unknown domains** resolve via structural entities (managed records / multi-entity paths), not per-domain factory switches.
- Manager/tracker/planner/log head-noun extraction is structural, not a task/expense domain switch.
