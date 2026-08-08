---
layout: home

hero:
  name: Anything
  text: An operating system for software that does not exist yet
  tagline: Describe what you need. Anything builds it, runs it, and keeps it — on your device, with no account and no server.
  image:
    src: /logo.svg
    alt: Anything
  actions:
    - theme: brand
      text: Get Started
      link: /guide/what-is-anything
    - theme: alt
      text: View on GitHub
      link: https://github.com/PIYUSH-MISHRA-00/Anything
    - theme: alt
      text: Roadmap
      link: /guide/roadmap

features:
  - icon: 💬
    title: Describe, do not build
    details: Say “track my water intake” and get a real application — interface, behaviour, state and declared capabilities. Not a chat reply. Not a code file you now own.
    link: /guide/what-is-anything
    linkText: How it works

  - icon: 📦
    title: Experiences, not code
    details: An Experience is a validated, versioned package the runtime executes. It can be checked before it runs, revised, protected, exported and removed completely — leaving nothing behind.
    link: /guide/experiences
    linkText: The Experience model

  - icon: 🔒
    title: Local first, and only
    details: No account, no server, no sync. Your Experiences, knowledge and keys stay on your device. Protection is local and time-keyed through Kaalka.
    link: /guide/kaalka
    linkText: Protection

  - icon: 🧠
    title: Nine reasoning engines
    details: Knowledge acquisition, architecture planning, feature discovery, multi-solution reasoning, self-critiquing design review, evolution planning, runtime intelligence and a world model.
    link: /guide/ai
    linkText: The AI stack

  - icon: 🛡️
    title: Architecture you can verify
    details: 102 invariants run on every commit, each mutation-proven by deliberately breaking it. One owner per concern, enforced by a test rather than a convention.
    link: /architecture/certification
    linkText: How certification works

  - icon: 🌐
    title: Open source, Apache-2.0
    details: Explicit patent grant, DCO instead of a CLA, and no ambiguity about ownership — Experiences you create with Anything are yours.
    link: /community/contributing
    linkText: Contribute
---

<div style="max-width: 860px; margin: 4rem auto 0; padding: 0 1.5rem;">

## Project status: pre-release

**Anything is not shipped yet.** This page describes software that is real,
tested and running in development — not something you can install from a store
today.

What works right now:

| | |
|---|---|
| Describe an intent and get a working Experience | ✅ |
| Run it natively — interface, behaviour, state | ✅ |
| Several Experiences as a workspace, with scheduling | ✅ |
| Modify and evolve an existing Experience | ✅ |
| Protect one with time-keyed encryption | ✅ |
| **Export and import an Experience as a file** | ✅ *(new)* |
| Persistent knowledge acquisition from the web | ✅ |
| Published Android build | ⚠️ not yet — [roadmap](/guide/roadmap) |
| Accessibility and localisation | ⚠️ minimal — [help wanted](/community/contributing) |
| Marketplace, cloud sync, accounts | ❌ out of scope, permanently |

The [roadmap](/guide/roadmap) is specific about what does not work and why.
If you are deciding whether to contribute, start there.

## Try it in two minutes

```bash
git clone https://github.com/PIYUSH-MISHRA-00/Anything.git
cd Anything
flutter pub get
flutter run
```

Then verify the checkout is healthy — this is exactly what CI runs:

```bash
flutter test                                                          # 2,141 tests
flutter test test/r46_architectural_integrity_certification_test.dart  # 102 invariants
bash tool/analyze_gate.sh                                             # analyzer baseline
```

</div>
