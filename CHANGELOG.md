# Changelog

Notable changes to Anything. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project uses
[Semantic Versioning](https://semver.org/).

Milestone-level detail lives in [`docs/audit/`](docs/audit/); this file is the
human-readable summary.

## [Unreleased]

### Added — IS-P01 (Productization, Open Source & Play Store Foundation)

- **Apache-2.0 `LICENSE`.** The repository previously had none, which made it
  legally "all rights reserved" and not open source at all.
- Complete OSS document set: `CONTRIBUTING`, `CODE_OF_CONDUCT`, `SECURITY`,
  `SUPPORT`, `CHANGELOG`, `ARCHITECTURE`, `VISION`, `ROADMAP`, and guides for
  releasing, maintaining, Experiences, WebWeaveX and Kaalka.
- GitHub issue and PR templates, `CODEOWNERS`, `FUNDING.yml`.
- Runnable examples under `examples/`.
- **Real Android release signing** via a gitignored `android/key.properties`,
  with debug-signing fallback so a fresh clone still builds.
- **R8/ProGuard** enabled for release, with rules covering the actual plugin set
  and line-number retention so release stack traces stay readable.
- **Application-wide error boundary** in `main.dart` — framework, platform and
  zone handlers. There was previously none.
- CI now **builds a release App Bundle**, so shippability is gated rather than
  assumed.

### Fixed — IS-P01

- **Release builds had no `INTERNET` permission.** It existed only in the debug
  and profile manifests, which are not merged into release builds, so every AI
  call, capability HTTP request and knowledge fetch would have failed silently
  in a shipped app. Also declared `POST_NOTIFICATIONS`, `RECORD_AUDIO` and
  `ACCESS_NETWORK_STATE`, each required by an existing dependency.
- **Release builds signed with the debug key**, which Google Play rejects
  outright.
- **`README.md` documented the wrong application.** Every directory it described
  (`lib/ui_engine/`, `lib/widgets/`, `lib/screens/`, `lib/memory/`) is in the
  unreachable v1 set. It described none of the 356 reachable files and none of
  the Experience system.
- `pubspec.yaml` description was still the Flutter template default.
- `.gitignore` did not protect keystores, `key.properties` or `.env`.

## Earlier

Milestones R1–R62 built the architecture: the Experience model, the runtime,
the entry pipeline, the capability platform, governance, trust, the commit and
installation frameworks, the package codec, the execution contract, the
orchestrator, and the 101-invariant certification layer.

Per-milestone reports: [`docs/audit/`](docs/audit/).
Decision records: [`docs/architecture/ADR_*.md`](docs/architecture/).
