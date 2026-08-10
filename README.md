<div align="center">

<img src="assets/branding/logo.svg" alt="Anything" width="120" height="120">

# Anything

**An operating system for software that does not exist yet.**

Describe what you need. Anything builds it, runs it, and keeps it.

[![CI](https://github.com/PIYUSH-MISHRA-00/Anything/actions/workflows/ci.yml/badge.svg)](https://github.com/PIYUSH-MISHRA-00/Anything/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-P18%20CI%3A%202%2C317%20passing-success)](docs/audit/)
[![Invariants](https://img.shields.io/badge/certified%20invariants-102-blueviolet)](docs/audit/ARCHITECTURE_INVARIANT_MATRIX.md)
[![Version](https://img.shields.io/badge/version-2.0.0%2B1-informational)](pubspec.yaml)

[**Website**](https://piyush-mishra-00.github.io/Anything/) · [Quick Start](#quick-start) · [Architecture](ARCHITECTURE.md) · [Vision](VISION.md) · [Roadmap](ROADMAP.md) · [Contributing](CONTRIBUTING.md) · [FAQ](docs/FAQ.md)

</div>

---

> **Project status: pre-release — NOT production complete (P21).**
> Version `2.0.0+1`. Analyzer **0/0/0**. P21 adds typed `IntentContract`
> (stopwatch≠calculator, scientific≠basic), hardcoding probe, provider
> independence tests, and novel-domain astronomy generation. Device matrix,
> WebWeaveX/Kaalka/import device cert, and Play Store remain **OPEN** until
> signed — see `Desktop/Anything_P21_FINAL/` and [ROADMAP.md](ROADMAP.md).

## What is Anything?

Most apps are a fixed set of screens somebody decided on in advance. Anything
inverts that. You describe an outcome in your own words — *"track my water
intake"*, *"a calculator that does unit conversions"* — and Anything designs,
generates, validates and runs a real application to do it.

The generated thing is called an **Experience**. It is not a chat response and
not a script: it is a structured, versioned, validated package with its own
interface, behaviour, state schema and declared capabilities, which the
Anything runtime executes natively.

## Why does it exist?

Three problems, all of which show up as soon as you try to build software for
one person's specific need.

**1. Most software is never written because it is not worth writing.** A tool
that helps exactly one person for six weeks cannot justify a development cycle.
Anything moves that cost close to zero.

**2. AI that generates code hands you a maintenance problem.** A generated file
is yours to run, debug and keep working forever. Anything generates a
*package the runtime understands* — versioned, validated, revisable, and
removable — rather than source you now own.

**3. Personal software should not require a cloud account.** Everything —
generation state, knowledge, Experiences — is local. Protection is local and
time-keyed. There is no server, no account, and no sync.

## What Anything actually does today

| Capability | Status |
|---|---|
| Describe an intent and get a working Experience | ✅ works |
| Run it natively (interface + behaviour + state) | ✅ works |
| Multiple Experiences running as a workspace | ✅ works |
| Foreground/background scheduling and lifecycle | ✅ works |
| Modify and evolve an existing Experience | ✅ works |
| Protect an Experience with time-keyed encryption | ⚠️ implemented; device protect/recover OPEN |
| Persistent knowledge acquisition from the web | ⚠️ adapter exists; device WebWeaveX journey OPEN |
| **Import / export an Experience as a file** | ⚠️ implemented + unit-tested; device security matrix OPEN |
| **Android release build** | ⚠️ APK PASS; CI AAB PASS; debug/local signing ≠ Play publishable |
| **Verified on a physical device** | ⚠️ PARTIAL — unknown-domain generate/create/persist proven; full journeys OPEN |
| Marketplace, cloud sync, accounts | ❌ explicitly out of scope |

## Architecture at a glance

```
        you type an intent
                │
                ▼
        ┌───────────────┐   understanding, planning, architecture selection,
        │ AnythingKernel│   feature discovery, engineering, design review,
        └───────┬───────┘   evolution planning  (9 engines, ~20k LOC)
                │
                ▼
        ExperiencePackage      manifest · interface · behaviour · state ·
                │              capabilities · provenance · integrity
                ▼
        ┌───────────────────────────────────────────┐
        │ commit → store → open → orchestrate →     │
        │ schedule → execute → render               │
        └───────────────────────────────────────────┘
                │
                ▼
        a running Experience
```

Every box has exactly one owner, and that singularity is **mechanically
certified** — 102 invariants run on every commit, each one mutation-proven by
deliberately breaking it and confirming the check fails.

Full map: **[ARCHITECTURE.md](ARCHITECTURE.md)**.

### The two libraries Anything is built on

| Library | Role | Boundary |
|---|---|---|
| **[Kaalka](https://pub.dev/packages/kaalka)** | Time-key protection for Experiences | one adapter, certified (I-21a/c) — see [KAALKA_GUIDE](docs/KAALKA_GUIDE.md) |
| **[WebWeaveX](https://pub.dev/packages/webweavex)** | Semantic web extraction + deterministic canonicalisation | one adapter, certified (I-21b/d) — see [WEBWEAVEX_GUIDE](docs/WEBWEAVEX_GUIDE.md) |

Neither is reachable from anywhere else in the codebase. That is not a
convention — a test fails if it stops being true.

## Quick Start

### Prerequisites

- **Flutter 3.44+** ([install](https://docs.flutter.dev/get-started/install))
- An **AI provider key** — currently [Groq](https://console.groq.com/keys)
  (free tier available). Without one, Anything runs and reports
  `ProviderRequired` rather than failing.

### Run it

```bash
git clone https://github.com/PIYUSH-MISHRA-00/Anything.git
cd Anything
flutter pub get
flutter run
```

Then: **Settings → AI Provider** to add your key, and type an intent on the
home screen.

### Verify your checkout

```bash
flutter test                                                  # P17 baseline: 2325; P18 may add more
flutter test test/r46_architectural_integrity_certification_test.dart   # 102 invariants
bash tool/analyze_gate.sh                                     # analyzer regression gate
```

A green run of those three is what CI enforces. Prefer the latest certification
artifacts over badges if they disagree.

## Examples

Runnable examples live in [`examples/`](examples/), each with its own README:

| Example | Shows |
|---|---|
| [`minimal_experience`](examples/minimal_experience) | the smallest valid Experience package |
| [`package_codec`](examples/package_codec) | writing and reading a `.anything` package |
| [`execution_contract`](examples/execution_contract) | declaring execution mode, and every fault refused |
| [`orchestration`](examples/orchestration) | request → decision → priority |

`dart run examples/minimal_experience/main.dart` — see
[`examples/README.md`](examples/README.md) for why two of them use
`flutter test` instead.

## Repository structure

```
lib/
  app/            composition root, entry pipeline, orchestrator, frameworks
  kernel/         intent → understanding → plan → Experience
  creation/       Experience package model, validator, codec
  runtime/        AnythingRuntime, renderer, behaviour interpreter
  capabilities/   capability platform + adapters (http, ai, files, …)
  storage/        SQLite repositories, durable collection store
  knowledge/      WebWeaveX-backed acquisition and cache
  security/       Kaalka protection, credential vault
  features/       the reachable UI
  design_system/  themes and components
  software_architect/ application_engineering/ feature_discovery/
  solution_reasoning/ design_review/ evolution/
  runtime_intelligence/ world_model/         the nine intelligence engines

test/             2325+ tests (P17 baseline), 0 skipped
docs/             architecture, audits, ADRs, guides
tool/             analyze gate, reachability analysis
examples/         runnable examples
```

Detail per directory: [ARCHITECTURE.md](ARCHITECTURE.md).

## Documentation

| If you want to… | Read |
|---|---|
| understand the system | [ARCHITECTURE.md](ARCHITECTURE.md) |
| know where this is going | [VISION.md](VISION.md) · [ROADMAP.md](ROADMAP.md) |
| contribute code | [CONTRIBUTING.md](CONTRIBUTING.md) · [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) |
| build an Experience | [docs/EXPERIENCE_GUIDE.md](docs/EXPERIENCE_GUIDE.md) |
| cut a release | [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md) |
| maintain the project | [docs/MAINTAINER_GUIDE.md](docs/MAINTAINER_GUIDE.md) |
| report a vulnerability | [SECURITY.md](SECURITY.md) |
| get help | [SUPPORT.md](SUPPORT.md) · [docs/FAQ.md](docs/FAQ.md) |
| see what changed | [CHANGELOG.md](CHANGELOG.md) |
| browse it as a website | [piyush-mishra-00.github.io/Anything](https://piyush-mishra-00.github.io/Anything/) |

## Contributing

Contributions are genuinely welcome, and the project is unusually easy to
contribute to safely: **102 certified invariants and 2325+ tests will tell you
immediately if a change breaks an architectural rule**, so you do not need to
hold the whole system in your head.

Good first areas are labelled in [ROADMAP.md](ROADMAP.md) — the highest-value
work right now is product and release engineering, not architecture.

Start with [CONTRIBUTING.md](CONTRIBUTING.md). By participating you agree to the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Community & support

- **Bugs and features** — [GitHub Issues](https://github.com/PIYUSH-MISHRA-00/Anything/issues)
- **Questions and ideas** — [GitHub Discussions](https://github.com/PIYUSH-MISHRA-00/Anything/discussions)
- **Security** — see [SECURITY.md](SECURITY.md); please do not open a public issue
- **Support the work** — [GitHub Sponsors / Buy Me a Coffee](.github/FUNDING.yml)

## License

[Apache License 2.0](LICENSE) — permissive, with an explicit patent grant.

Experiences you create with Anything are **yours**. The license covers this
software, not the applications you generate with it. Third-party notices:
[docs/oss/THIRD_PARTY_NOTICES.md](docs/oss/THIRD_PARTY_NOTICES.md).
