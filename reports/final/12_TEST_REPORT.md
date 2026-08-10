# 12 — Test Report

| Scope | Result | Notes |
| --- | --- | --- |
| Targeted (shells, Kaalka, stage contracts, renderer-related) | **+24** PASS | This hardening / release commit focus |
| Full suite (prior) | **+2352** at `5dd9ff4` | Recorded before this commit |
| This commit | Adds **renderer** (`FittedBox` scaleDown) + **CI APK** + final reports | Does not re-claim a fresh full-suite zero |

Full suite was previously green at baseline `5dd9ff4`. Analyzer/format remain CI-gated; this packaging does not invent a new full-suite number.
