# What is Anything?

Most apps are a fixed set of screens somebody decided on in advance. Anything
inverts that. You describe an outcome in your own words and it designs,
generates, validates and runs a real application to do it.

The result is called an **Experience**.

## Why it exists

**Most software is never written, because it is not worth writing.** A tool
that helps exactly one person for six weeks cannot justify a development cycle,
a repository, a maintainer or a release. Anything moves that cost close to zero.

**AI that generates code hands you a maintenance problem.** A generated file is
yours forever: yours to debug, keep working, and eventually delete. Anything
generates a *package the runtime already understands* instead.

**Personal software should not need a cloud account.** Everything is local.

## What an Experience is — and why it is not code

```
ExperiencePackage
 ├─ manifest      identity, version, declared capabilities
 ├─ interface     screens and their node tree
 ├─ behaviour     a graph the interpreter walks
 ├─ state         what it remembers
 ├─ provenance    which engine version made it
 └─ integrity     content hash
```

It is **data**, not instructions. That single decision is what makes everything
else possible:

- it can be **validated** before it ever runs, structurally and exhaustively
- it can be **versioned and revised** without a merge
- it can be **removed** completely, leaving nothing behind
- it can be **protected**, because it is data rather than a program
- it **cannot execute arbitrary code**, because there is no code to execute

## What happens when you type an intent

```
your words
    │
    ▼
Kernel ── understanding → knowledge → architecture → features →
          multi-solution reasoning → engineering → design review → evolution
    │
    ▼
ExperiencePackage  ── validated, committed transactionally, stored
    │
    ▼
Orchestrator → Scheduler → Runtime → your app on screen
```

Nine reasoning engines, roughly 20,000 lines. Each stage is typed and
reviewable, and the design-review stage **fails closed** — if it cannot approve
a design, nothing is generated.

## What Anything is not

| Not | Why |
|---|---|
| A chatbot | The output is a running application, not a message |
| A code generator | It generates packages the runtime executes, not source you maintain |
| A low-code builder | No canvas, no drag-and-drop. You describe an outcome |
| A cloud platform | There is no server, and there is not going to be one |
| A marketplace | Explicitly out of scope in every specification to date |
| An autonomous agent | Nothing runs without a person asking |

## Next

- [Installation](/guide/installation)
- [Quick Start](/guide/quick-start)
- [The Experience model](/guide/experiences)
