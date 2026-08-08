# AI & Knowledge

## The nine engines

Roughly 20,000 lines, and most of it reachable from a running app.

| Engine | Role |
|---|---|
| Knowledge acquisition | Real semantic extraction from the web via WebWeaveX |
| Software architect | Typed, self-critiquing architecture planning |
| Application engineering | Entity state machines compiled into behaviour graphs |
| Feature discovery | Cross-cutting features and their dependencies |
| Solution reasoning | 2–4 real variants, scored across 15 tradeoff dimensions |
| Design review | 15 sub-reviewers, conservative auto-fix, **fails closed** |
| Evolution | Observe → Estimate → Review → Approve → Plan → Predict |
| Runtime intelligence | Observation, pattern detection, declarative automation |
| World model | One typed graph, structural entity identity |

Design review failing closed is worth dwelling on: if the reviewers cannot
approve a design, **nothing is generated**. Anything would rather produce
nothing than produce something it cannot vouch for.

## Providers

One `ModelProvider` contract; today one implementation (Groq), reading its key
from a purpose-scoped `CredentialVault` backed by the platform keystore.

**A second provider is one of the highest-value contributions available.** The
abstraction exists and has never been exercised by a second implementation,
which means its adequacy is genuinely untested.

## Honest degradation

No provider configured produces `ProviderRequired` — not a crash, not a
fabricated answer. A heuristic understanding path handles the cases that do not
need reasoning.

## Nothing acts without you

Autonomous execution is **declared in the vocabulary and explicitly refused** at
two independent layers. Evolution planning produces a reviewed, ranked roadmap
and never auto-executes it.

If that ever changes it will be a deliberate product decision, not drift.

## Known gaps

| Gap | Status |
|---|---|
| One provider, and you must bring a key | The biggest usability gap in the product |
| No streaming responses | Generation takes seconds with no token stream |
| No cost or token accounting | You cannot see what a generation cost |
| No defined offline behaviour | Beyond a failed request |
| No on-device inference | Would remove the key barrier entirely |

[Help is welcome](/community/contributing) on all of these.
