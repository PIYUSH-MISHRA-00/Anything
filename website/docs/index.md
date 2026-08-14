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

<div class="axn">
  <div class="axn-head">
    <h2>See it in action</h2>
    <p>Describe an app. Use the real, full-stack app Anything builds. Then change it by talking to it — all on your device.</p>
  </div>
  <div class="axn-hero">
    <div class="axn-phone axn-phone--lg">
      <img src="/screenshots/demo.gif" alt="Anything demo — open an AI-built app, browse the live web inside it, and change the app by describing the change" loading="lazy" />
    </div>
    <div class="axn-steps">
      <div class="axn-step"><span>1</span><div><strong>Describe</strong><p>Type an outcome in your own words — <em>“a grocery list”</em>, <em>“find nearby restaurants”</em>.</p></div></div>
      <div class="axn-step"><span>2</span><div><strong>Use</strong><p>A real full-stack app: add records, and browse <strong>live web data</strong> in the built-in Discover tab, powered by WebWeaveX.</p></div></div>
      <div class="axn-step"><span>3</span><div><strong>Change it</strong><p>Say <em>“add a favourite button”</em> — scoped to the screen you’re on, or the whole app if you ask.</p></div></div>
      <a class="axn-cta" href="https://buymeacoffee.com/piyushmishra00" target="_blank" rel="noopener">☕ Buy me a coffee</a>
    </div>
  </div>
  <div class="axn-grid">
    <figure><div class="axn-phone"><img src="/screenshots/01_home.png" alt="Home screen — 'What do you want?'" loading="lazy"/></div><figcaption>Describe an intent</figcaption></figure>
    <figure><div class="axn-phone"><img src="/screenshots/02_generated_app.png" alt="A generated full-stack grocery app" loading="lazy"/></div><figcaption>The app it builds</figcaption></figure>
    <figure><div class="axn-phone"><img src="/screenshots/03_webweavex_discover.png" alt="WebWeaveX Discover — a real Walmart.com product with a rendered image" loading="lazy"/></div><figcaption>Real web data, inside your app</figcaption></figure>
    <figure><div class="axn-phone"><img src="/screenshots/04_change_app.png" alt="Change this app — scoped to the current screen, with voice input" loading="lazy"/></div><figcaption>Change it by talking to it</figcaption></figure>
  </div>
</div>

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
