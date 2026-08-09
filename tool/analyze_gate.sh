#!/usr/bin/env bash
# IS-R58 Phase 3 — the canonical analyze gate.
#
# WHY THIS EXISTS. Before R58, CI ran bare `flutter analyze` under a step named
# "Analyze (0 new errors, 0 new warnings beyond the documented baseline)".
# `flutter analyze` exits non-zero if it finds ANY issue, and this repository
# has a documented, non-empty baseline — so that step could never pass, CI
# halted before `flutter test`, and all 89 certification invariants gated
# nothing. The step's name described a comparison it never performed.
#
# This script performs it.
#
# THE BASELINE IS EXPLICIT, and it is the REAL one. Every report from R47 to
# R57 described it as "71 issues, all pre-existing informational". That was
# wrong: 27 of them are WARNINGS. IS-R58 Phase 1 re-measured and this gate is
# built on the measured numbers, not the documented claim.
#
# THIS GATE NEVER WEAKENS ANALYSIS. It does not suppress a diagnostic, ignore a
# file, exclude a directory or lower a lint. It runs the analyzer at full
# strength and compares counts.
set -uo pipefail

# ── THE DOCUMENTED BASELINE ────────────────────────────────────────────────
# Measured 2026-08-08 at commit 964b47c, after IS-R58 Phase 2.
# Lower these numbers when issues are fixed. Raising one requires a commit
# message explaining why, and is exactly the review moment this gate exists to
# create.
BASELINE_ERRORS=0
BASELINE_WARNINGS=27
# Lowered 43 -> 41 by IS-P06: replacing the hand-rolled Groq adapter with the
# shared OpenAI-compatible one removed two style infos along with the code.
BASELINE_INFOS=41

FLUTTER="${FLUTTER:-flutter}"
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

"$FLUTTER" analyze > "$OUT" 2>&1 || true

# IS-P06 — PROVE THE ANALYZER ACTUALLY RAN.
#
# `|| true` above exists because `flutter analyze` exits non-zero whenever it
# finds any issue, and this repository has a non-empty baseline. But it also
# swallowed the case where the command never ran at all: with `flutter` absent
# from PATH the counts below all came back 0, which compares favourably against
# every baseline, and the gate printed "PASS". A validation gate that passes
# when the validation did not happen is worse than no gate.
#
# `flutter analyze` always ends with "No issues found!" or "N issues found.",
# so the presence of that line is proof of a real run.
if ! grep -qE 'issues? found|No issues found' "$OUT"; then
  echo "FAIL: the analyzer did not run. Output was:"
  cat "$OUT"
  echo
  echo "Set FLUTTER to the Flutter binary if it is not on PATH, e.g."
  echo "  FLUTTER=/path/to/flutter bash tool/analyze_gate.sh"
  exit 1
fi

errors=$(grep -c 'error - '   "$OUT" || true)
warnings=$(grep -c 'warning - ' "$OUT" || true)
infos=$(grep -c 'info - '     "$OUT" || true)

echo "analyzer: ${errors} error(s), ${warnings} warning(s), ${infos} info(s)"
echo "baseline: ${BASELINE_ERRORS} error(s), ${BASELINE_WARNINGS} warning(s), ${BASELINE_INFOS} info(s)"

fail=0

# Errors are absolute: the baseline is zero and must stay zero.
if [ "$errors" -gt "$BASELINE_ERRORS" ]; then
  echo "FAIL: ${errors} error(s); the baseline is ${BASELINE_ERRORS} and errors are never acceptable."
  fail=1
fi

if [ "$warnings" -gt "$BASELINE_WARNINGS" ]; then
  echo "FAIL: warnings rose ${BASELINE_WARNINGS} -> ${warnings}."
  fail=1
fi

if [ "$infos" -gt "$BASELINE_INFOS" ]; then
  echo "FAIL: infos rose ${BASELINE_INFOS} -> ${infos}."
  fail=1
fi

if [ "$fail" -eq 1 ]; then
  echo
  echo "New diagnostics are listed below. Fix them, or — if the increase is"
  echo "genuinely justified — raise the baseline in tool/analyze_gate.sh in a"
  echo "commit that explains why."
  echo
  grep -E '(error|warning|info) - ' "$OUT" || true
  exit 1
fi

# A DROP is reported but never fails: fixing issues must never break the build.
# It is surfaced so the baseline can be tightened deliberately.
if [ "$errors" -lt "$BASELINE_ERRORS" ] || [ "$warnings" -lt "$BASELINE_WARNINGS" ] || [ "$infos" -lt "$BASELINE_INFOS" ]; then
  echo
  echo "NOTE: the analyzer is now BELOW baseline. Please lower the numbers in"
  echo "tool/analyze_gate.sh so the gate keeps its full strength."
fi

echo "PASS: analyzer is at or below the documented baseline."
