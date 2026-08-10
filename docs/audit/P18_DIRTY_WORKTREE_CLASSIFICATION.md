# P18 — dirty worktree classification (pre-final-commit)

Working tree at P18 start contained many files unrelated to P17 tip
`f997ea0`. Classification for the P18 release commit:

## Include in P18 commit

- Analyzer cleanliness fixes (test/tool/lib style)
- `tool/analyze_gate.sh` baseline → 0/0/0
- `pubspec.yaml` version `2.0.0+1` (was dirty relative to archive)
- `android/app/build.gradle.kts` NDK 28.2.13676358
- README.md / ROADMAP.md truth updates
- `docs/architecture/P18_OPEN_WORLD_SEMANTIC_ARCHITECTURE.md`
- `docs/audit/P18_*` inventories
- `test/dynamic/p18_*.dart`
- `.github/workflows/ci.yml` P18 suites

## Exclude (pre-existing / unrelated — leave dirty or separate)

- `.p08_audit/` `.p09_audit/` audit dumps
- Unrelated edits under `lib/app/experience_*`, `home_screen`,
  `developer_screen`, stage10/11 test churn unless already required by analyzer
  fixes (analyzer fixes in those tests ARE included)
- `website/docs/community/sponsors.md` / FUNDING unless docs audit requires

Exact staging list is decided at commit time via `git add` of intentional paths.
