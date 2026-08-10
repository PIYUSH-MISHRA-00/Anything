# 04 — Intent Certification

## IntentContract

P21 `IntentContract` retained in the creation coordinator.

| Distinction | Enforced |
| --- | --- |
| Stopwatch ≠ calculator | Yes |
| Scientific ≠ basic calculator | Yes |

## Device evidence (moto g31)

| Prompt class | Result | Evidence |
| --- | --- | --- |
| Stopwatch (no AI) | PASS — Start/Pause/Resume/Reset | `evidence/02_stopwatch_*`, `03_*`, `04_*`, `05_*` |
| Scientific calculator | PASS — Mode: scientific | `evidence/07_scientific_*` |
| Weather / News / CRUD shells | PASS without AI provider | `evidence/08_*`–`21_*` |

Capability shells preserve purpose; cross-contamination not observed in sequential creates.
