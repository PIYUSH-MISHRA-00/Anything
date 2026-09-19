# 09 — Import / Export Report

## Export

| Field | Value |
| --- | --- |
| Destination | `Downloads/Anything/*.anything` |
| Device result | **PASS** |
| Evidence | `evidence/42_export_result.png`; hardening export screenshots |

## Import

| Field | Value |
| --- | --- |
| Device round-trip | **PASS** (export → delete → SAF import → reopen) |
| Evidence | `Desktop/Anything_FINAL/evidence_hardening/` (`04_picker_*`, `05_imported_*`, `06_opened_*`, `07_restart_*`) |

## Security

Import integrity via **reader checksum** validation on `.anything` packages (corrupt/tampered packages rejected by codec/reader path). Format coverage also covered in unit/integration tests.
