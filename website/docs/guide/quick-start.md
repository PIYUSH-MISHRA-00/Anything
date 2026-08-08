# Quick Start

## 1. Describe something

On the home screen, type what you want in your own words:

> *track how much water I drink each day*

Anything runs it through the reasoning pipeline and generates an Experience.
This takes several seconds — the design-review stage genuinely reviews the
design and fails closed rather than shipping something it cannot approve.

## 2. Use it

Your Experience opens as a real, native screen. It has its own state and its
own behaviour, and it persists between sessions.

## 3. Come back to it

Open it from **Recent** on the home screen, or from **My Apps**. Several
Experiences can run at once; the workspace switcher moves between them, and the
scheduler moves the ones you are not looking at into the background.

## 4. Protect it

**My Apps → long-press → Protect** encrypts it with a time-keyed seed through
[Kaalka](/guide/kaalka). Reopening asks for the seed.

## 5. Share it

**My Apps → long-press → Export** writes a `.anything` file — a deterministic,
checksummed package.

**My Apps → Import** reads one back. A tampered file is refused: the checksum is
verified against the rebuilt package, so an edit that leaves valid JSON behind
is still caught.

::: tip Why this matters
Export and import were the last missing step in the pipeline. Every layer —
format, writer, reader, validator, installer — had been built and certified for
several milestones, and nothing called them. An Experience was trapped on the
device that made it.
:::

## 6. Evolve it

Ask for a change and the modification pipeline revises the Experience in place,
transactionally. Nothing is left half-written if it fails.

## What you cannot do yet

- Install from an app store
- Sync between devices (permanently out of scope)
- Use it without an AI provider key
- Rely on it with a screen reader — [help wanted](/community/contributing)

## Next

- [The Experience model](/guide/experiences)
- [Examples you can run](/guide/examples)
