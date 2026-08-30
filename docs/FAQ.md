# FAQ

## About the project

**What is Anything, in one sentence?**
An operating system that turns a description of what you need into a real,
running application on your device.

**Is it a chatbot?**
No. The output is a running application with its own interface, behaviour and
state — not a message.

**Does it generate code I have to maintain?**
No, and that is the point. It generates an **Experience**: a validated, versioned
package the runtime already knows how to execute. There is no source file that
becomes yours to keep working.

**Does it need an internet connection or an account?**
An account, no — there is no server and no sync. An AI provider key, currently
yes, and that needs network access. Everything else is local.

**Is it production ready?**
No. The architecture is mature and heavily certified; the product is not shipped.
There is no Play Store build yet. [ROADMAP.md](../ROADMAP.md) is specific about
what works and what does not.

## Using it

**Why do I see "ProviderRequired"?**
No AI provider key is configured. Settings → AI Provider. This is a deliberate
honest failure rather than a crash or a fabricated answer.

**Which AI providers work?**
Groq today. The `ModelProvider` abstraction exists and has never had a second
implementation — [adding one](../CONTRIBUTING.md) is one of the highest-value
contributions available.

**Can I share an Experience with someone?**
Not yet. The package format, writer, reader, installer and distribution
framework are all built and certified, but nothing in the UI calls them. This is
the next milestone.

**Where is my data?**
On your device. SQLite for Experiences and knowledge, `flutter_secure_storage`
for API keys, `SharedPreferences` for durable collections. Nothing is uploaded.

**Can an Experience do something malicious?**
It cannot execute arbitrary code — an Experience is *data*, a behaviour graph the
interpreter walks. Capabilities are enforced by `CapabilityPlatform`, and
declaring a capability does not grant it. See [SECURITY.md](../SECURITY.md) for
what is and is not protected.

## Contributing

**Where do I start?**
[CONTRIBUTING.md](../CONTRIBUTING.md), then the "where help is most useful"
section of [ROADMAP.md](../ROADMAP.md). The highest-value work right now is
product and release engineering, not architecture.

**Do I need to understand the whole system?**
No. 102 certified invariants and 2,350+ tests will tell you if you break an
architectural rule. That is the main reason this codebase is safe to contribute
to without holding it all in your head.

**A certification test failed and named my file. What now?**
It is usually right. You have probably created a second owner for something that
already has one. Check
[OWNERSHIP_MATRIX](audit/OWNERSHIP_MATRIX.md) and prefer extending the existing
owner. If a new owner is genuinely correct, open a Discussion.

**Why is the analyzer baseline non-zero?**
27 warnings and 43 infos are pre-existing. The gate fails on any *increase*,
which keeps the count honest without demanding a cleanup nobody asked for. If
you reduce it, lower the baseline in the same PR.

**Can I add a dependency?**
Prefer not to. This project consistently chooses stdlib and existing dependencies
— the package format is canonical JSON rather than a zip specifically because
`archive` is not a dependency. If you need one, argue for it in the PR.

**Why are there ~50 files that cannot run?**
A v1 application that predates the current architecture. It cannot execute
because nothing creates a `ProviderScope`. The files import each other, so none
is individually provably dead, which is why no milestone has deleted them. It is
a pending decision, not an oversight.

**Why does the test suite sometimes fail one test and pass on re-run?**
Known as **G-40** — test-database contention. Unresolved across four milestones,
and honestly the most consequential open defect, because it weakens every "all
tests pass" claim in the repository. Help welcome.

## Architecture

**Why "one owner per concern"?**
Because a second owner is how systems rot silently. Here it is not a convention —
if you add a second manifest, validator, scheduler or trust model, a test fails
and names the file.

**What is a mutation-proven invariant?**
One that has been made to fail on purpose. The thing it protects is deliberately
broken, the test is confirmed to fail *for the right reason*, then it is
restored. An invariant that has never failed is a claim, not a check.

**Why is the package format JSON rather than a zip?**
`archive` is not a dependency and adding one was not justified. The container
carries an explicit `formatVersion`, so a binary encoding can replace it later
without touching the manifest, the validator, or any caller.

**Why can a contract not decide anything?**
Because a contract travels *inside* a package, and a package is untrusted input.
A contract that could decide its own eligibility would be a governance engine
reachable by anyone who can write a manifest.

## Licensing

**What license?**
[Apache-2.0](../LICENSE) — permissive, with an explicit patent grant.

**Do I own what I create with it?**
Yes. The license covers this software, not the Experiences you generate.

**Can I use it commercially?**
Yes. Apache-2.0 permits commercial use, modification and distribution, with
attribution and notice of changes.

**CLA?**
No. DCO — sign off your commits with `git commit -s`. You keep ownership of your
work.
