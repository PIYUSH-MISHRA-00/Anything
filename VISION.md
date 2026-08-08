# Vision

## The premise

Most software that would help a person is never written, because writing it
costs more than the help is worth. A tool that serves one person for six weeks
cannot justify a development cycle, a repository, a maintainer or a release.

Anything exists to move that cost close to zero — not by generating code you
then own and maintain, but by generating **an Experience the runtime already
knows how to execute**.

## What an Experience is, and why it is not code

A generated source file is a liability the moment it exists: you own it, debug
it, and keep it working. An **Experience** is a structured package —
manifest, interface, behaviour graph, state schema, declared capabilities,
provenance, integrity hash — that an existing, tested runtime executes.

That difference is the whole design:

- it can be **validated** before it runs, structurally and exhaustively
- it can be **versioned and revised** without a merge
- it can be **removed** completely, leaving nothing behind
- it can be **protected**, because it is data rather than a program
- it cannot execute arbitrary code, because there is no code to execute

## Principles

**1. Local first, and local only.** No account, no server, no sync. Generation
state, knowledge and Experiences live on the device. This is a design
commitment, not a phase.

**2. One owner per concern, enforced by a machine.** Every capability in this
system has exactly one owner, and that is verified by a test rather than a
convention. 101 invariants, each mutation-proven.

**3. A package is untrusted input.** An Experience arrives as data. It never
earns authority by being well-formed: reading one does not install it,
installing one does not run it, and declaring a capability does not grant it.

**4. Degrade honestly.** No AI provider configured produces `ProviderRequired`,
not a crash and not a fabricated answer. Undeclared means undeclared, never
"unlimited".

**5. Nothing acts without a person.** Autonomous execution is declared in the
vocabulary and explicitly refused at two independent layers. If that ever
changes it will be a deliberate product decision, not a drift.

## What Anything is not

| Not | Why |
|---|---|
| A chatbot | The output is a running application, not a message. |
| A code generator | It generates packages the runtime executes, not source you maintain. |
| A low-code builder | There is no canvas and no drag-and-drop. You describe an outcome. |
| A cloud platform | There is no server. There is not going to be one. |
| An app marketplace | Explicitly out of scope in every specification to date. |
| An autonomous agent | Nothing runs without a person asking. |

## Where this goes

**Near term** — make what exists reachable: a shippable Android build, and
Experiences that can leave and enter a device as files. See
[ROADMAP.md](ROADMAP.md).

**Medium term** — more than one AI provider (including on-device inference, so
Anything works with no key at all), a real first-run experience, accessibility
and localisation.

**Long term** — Experiences that can be shared between people, and a knowledge
layer that makes generation better the longer you use it.

**Deliberately unscheduled** — marketplace, accounts, cloud sync, multi-device.
Each would compromise principle 1, and none has been asked for by a user.

## How you can tell whether this vision is being kept

Not by reading this file. By running:

```bash
flutter test test/r46_architectural_integrity_certification_test.dart
```

If a principle above stops being true, one of those 101 tests fails and names
the file.
