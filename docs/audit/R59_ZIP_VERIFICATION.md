# IS-R59 Desktop Deliverable Verification

Performed 2026-08-08 after generating all seven archives.

## Integrity — every entry opened, not merely listed

| Archive | Entries | Openable | Integrity |
|---|---|---|---|
| `Anything_IS-R59_lib.zip` | 476 | 476 | **OK** |
| `Anything_IS-R59_test.zip` | 200 | 200 | **OK** |
| `Anything_IS-R59_docs.zip` | 161 | 161 | **OK** |
| `Anything_IS-R59_Verification.zip` | 9 | 9 | **OK** |
| `Anything_IS-R59_Graphs.zip` | 2 | 2 | **OK** |
| `Anything_IS-R59_Reports.zip` | 6 | 6 | **OK** |
| `Anything_IS-R59_Deliverables.zip` | 36 | 36 | **OK** |

Each entry was opened via `System.IO.Compression.ZipFile`, not just enumerated —
a corrupt entry would fail on `Open()`, which a listing would not detect.

## Content match against the repository

| Source | Repository files | Archive entries | Match |
|---|---|---|---|
| `lib/` | 476 | 476 | **exact** |
| `test/` | 200 | 200 | **exact** |
| `docs/` | 161 | 161 | **exact** |

## Deliverables folder

`Desktop\Anything_IS-R59_Deliverables\` — 36 files:

| Subfolder | Files |
|---|---|
| `ADRs/` | 1 |
| `Certification/` | 3 |
| `Documentation/` | 3 |
| `Graphs/` | 2 |
| `Matrices/` | 8 |
| `Reports/` | 6 |
| `Validation/` | 9 |
| root | `EXECUTIVE_SUMMARY.md`, `LESSONS_LEARNED.md`, `REMAINING_GAP_MATRIX.md`, `COMMIT_BY_COMMIT_SUMMARY.txt` |

## Validation evidence included

`analyzer_output.txt`, `analyze_gate_output.txt`, `certification_output.txt`,
`full_test_suite_output.txt`, `reachability_audit.txt`,
`reachability_report.json`, `ci_workflow.yml`, `git_status.txt` (empty — clean
tree), `commit_summary.txt`.

**Note on `full_test_suite_output.txt`:** it records the clean run
(2,068 passed). The contended run that produced 27 failures is analysed in
§10 of the milestone report rather than shipped as the headline evidence,
because it measures G-40 rather than the code.
