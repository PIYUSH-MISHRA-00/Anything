# 13 — Analyzer Report

## Gate

CI step **Analyze against the documented baseline** runs:

```bash
bash tool/analyze_gate.sh
```

(`\.github/workflows/ci.yml` → `analyze-and-test` job)

## Policy

Compares against the explicit baseline in `tool/analyze_gate.sh`. Fails on any **new** error/warning/info. Does not require a zero-issue tree; does not suppress or exclude lints ad hoc.

Baseline status for release: **BASELINE** (gated in CI; not re-zeroed as a claim in this packaging run).
