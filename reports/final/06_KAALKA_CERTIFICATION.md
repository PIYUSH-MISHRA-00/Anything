# 06 — Kaalka Certification

## Canonical path

```
ExperienceProtectionService
  → KaalkaProtectionProvider (lib/legacy/kaalka_adapter.dart)
    → KaalkaService
      → package:kaalka
```

WebWeaveX is not on this path.

## Minute seed

Current-time protect uses **minute** precision (seconds=0) with previous-minute unlock fallback so device unlock survives second rollover.

## Evidence

| Check | Result |
| --- | --- |
| Device protect / recover | **PASS** (`evidence/36_*`–`38_*` notes; expense protect/recover) |
| Unit wrong-time reject | **PASS** (`test/stage94/protection_test.dart`) |
| Unit current-time protect / recreate survive | **PASS** |
