# 10 — Device Validation

| Field | Value |
| --- | --- |
| Device | moto g31 (`ZD2225JSBY`) |
| Android | 12 |
| Package | `com.anything.anything` 2.0.0+1 |

## This hardening pass

| Item | Result |
| --- | --- |
| Import full round-trip | **PASS** (`evidence_hardening/`) |
| Stopwatch Pause/Resume labels | **Fixed** in APK via `FittedBox` + `BoxFit.scaleDown` in `experience_renderer.dart` |
| Prior interactive matrix (stopwatch, scientific, weather, news, CRUD, Kaalka, export) | **Still valid** — see `Desktop/Anything_FINAL/evidence/` |

Installed release APK SHA-256 for this packaging: `6A3EDA75D404A19C08C22C8495D5565097275CE9FCA802D572F7D0970302F927`.
